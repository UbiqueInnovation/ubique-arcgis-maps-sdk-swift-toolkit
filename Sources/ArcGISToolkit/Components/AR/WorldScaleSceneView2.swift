// Copyright 2023 Esri.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ARKit
import SwiftUI
import ArcGIS

/// A scene view that provides an augmented reality world scale experience.
public struct WorldScaleSceneView2: View {
    /// The proxy for the ARSwiftUIView.
    @State private var arViewProxy = ARSwiftUIViewProxy()
    /// The proxy for the scene view.
    @State private var sceneViewProxy: SceneViewProxy?
    /// The camera controller that will be set on the scene view.
    @State private var cameraController: TransformationMatrixCameraController
    /// The current interface orientation.
    @State private var interfaceOrientation: InterfaceOrientation?
    /// The closure that builds the scene view.
    private let sceneViewBuilder: (SceneViewProxy) -> SceneView
    /// The configuration for the AR session.
    private let configuration: ARConfiguration
    
    @State private var statusText: String = ""
    @State private var locationDatasSource = SystemLocationDataSource()
    @State private var currentHeading: Double?
    @State private var currentLocation: Location?
    @State private var locationDataSourceError: Error?
    @State private var lastResetLocation: Point?
    @State private var initialCameraIsSet = false
    @State private var currentCamera: Camera?
    
    /// Creates a world scale scene view.
    /// - Parameters:
    ///   - sceneView: A closure that builds the scene view to be overlayed on top of the
    ///   augmented reality video feed.
    /// - Remark: The provided scene view will have certain properties overridden in order to
    /// be effectively viewed in augmented reality. Properties such as the camera controller,
    /// and view drawing mode.
    public init(
        @ViewBuilder sceneView: @escaping (SceneViewProxy) -> SceneView
    ) {
        self.sceneViewBuilder = sceneView
        
        let cameraController = TransformationMatrixCameraController()
        cameraController.translationFactor = 1
        _cameraController = .init(initialValue: cameraController)
        
        configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
    }
    
    public var body: some View {
        ZStack {
            ARSwiftUIView(proxy: arViewProxy)
                .onDidUpdateFrame { _, frame in
                    guard let sceneViewProxy, let interfaceOrientation, initialCameraIsSet else { return }
                    
                    sceneViewProxy.updateCamera(
                        frame: frame,
                        cameraController: cameraController,
                        orientation: interfaceOrientation,
                        initialTransformation: .identity
                    )
                    sceneViewProxy.setFieldOfView(
                        for: frame,
                        orientation: interfaceOrientation
                    )
                    
                    sceneViewProxy.draw()
                }
            
            if initialCameraIsSet {
                SceneViewReader { proxy in
                    sceneViewBuilder(proxy)
                        .cameraController(cameraController)
                        .attributionBarHidden(true)
                        .spaceEffect(.transparent)
                        .atmosphereEffect(.off)
                        .viewDrawingMode(.manual)
                        .onCameraChanged { camera in
                            self.currentCamera = camera
                        }
                        .onAppear {
                            // Capture scene view proxy as a workaround for a bug where
                            // preferences set for `ARSwiftUIView` are not honored. The
                            // issue has been logged with a bug report with ID FB13188508.
                            self.sceneViewProxy = proxy
                        }
                }
            }
        }
        .overlay(alignment: .top) {
            if !statusText.isEmpty {
                statusView(for: statusText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
            }
        }
        .observingInterfaceOrientation($interfaceOrientation)
        .onAppear {
            arViewProxy.session.run(configuration, options: [.resetTracking])
        }
        .task {
            do {
                try await locationDatasSource.start()
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for await heading in locationDatasSource.headings {
                            self.currentHeading = heading
                            //await updateSceneView()
                        }
                    }
                    group.addTask {
                        for await location in locationDatasSource.locations {
                            self.currentLocation = location
                            await updateSceneView()
                        }
                    }
                }
            } catch {
                locationDataSourceError = error
                withAnimation {
                    statusText = "Failed to access current location."
                }
            }
        }
    }
    
    @MainActor
    func updateSceneView() {
        guard let currentHeading, let currentLocation else { return }
        
        if !initialCameraIsSet {
            cameraController.originCamera = Camera(
                latitude: currentLocation.position.y,
                longitude: currentLocation.position.x,
                altitude: 5,
                heading: currentHeading,
                pitch: 90,
                roll: 0
            )
            initialCameraIsSet = true
        } else if shouldUpdateCamera() {
            statusText += " |"
            cameraController.originCamera = Camera(
                latitude: currentLocation.position.y,
                longitude: currentLocation.position.x,
                altitude: 5,
                heading: currentHeading,
                pitch: 90,
                roll: 0
            )
            cameraController.transformationMatrix = .identity
            arViewProxy.session.run(configuration, options: [.resetTracking])
        }
    }
    
    func shouldUpdateCamera() -> Bool {
        guard let currentLocation, let currentCamera else { return false }
        
//        guard let currentHeading else { return false }
//        if fabs(Self.delta(currentCamera.heading, currentHeading)) > 20 {
//            print("-- heading: \(currentCamera.heading) to \(currentHeading)")
//            return true
//        }
        
        guard let sr = currentCamera.location.spatialReference else { return false }
        guard let currentLocationPosition = GeometryEngine.project(currentLocation.position, into: sr) else { return false }
        
        if currentLocation.horizontalAccuracy > 5 {
            return false
        }
        
        if let result = GeometryEngine.geodeticDistance(
            from: currentCamera.location,
            to: currentLocationPosition,
            distanceUnit: .meters,
            azimuthUnit: nil,
            curveType: .geodesic
        ), result.distance.value > 2 {
            print("-- distance: \(result.distance.value)")
            return true
        }
        
        return false
    }
    
    @ViewBuilder func statusView(for status: String) -> some View {
        Text(status)
            .multilineTextAlignment(.center)
    }
    
    private static func delta(_ angle1: Double, _ angle2: Double) -> Double {
        var delta = angle2 - angle1
        while (delta < -180) { delta += 360 }
        while (delta > 180) { delta -= 360 }
        return delta
    }
}

