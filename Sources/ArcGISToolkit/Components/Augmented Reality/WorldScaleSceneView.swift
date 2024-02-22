// Copyright 2024 Esri
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ARKit
import SwiftUI
import ArcGIS

/// A scene view that provides an augmented reality world scale experience.
public struct WorldScaleSceneView: View {
    /// The clipping distance of the scene view.
    private let clippingDistance: Double?
    /// The tracking mode for world scale AR.
    private let trackingMode: TrackingMode
    /// The closure that builds the scene view.
    private let sceneViewBuilder: (SceneViewProxy) -> SceneView
    /// Determines the alignment of the calibration button.
    private var calibrationButtonAlignment: Alignment = .bottom
    /// A Boolean value that indicates whether the calibration view is hidden.
    private var calibrationViewIsHidden = false
    /// The proxy for the ARSwiftUIView.
    @State private var arViewProxy = ARSwiftUIViewProxy()
    /// The camera controller that will be set on the scene view.
    @State private var cameraController: TransformationMatrixCameraController
    /// The view model for the calibration view.
    @StateObject private var calibrationViewModel = WorldScaleCalibrationViewModel()
    /// A Boolean value that indicates whether the geo-tracking configuration is available.
    @State private var geoTrackingIsAvailable = true
    /// A Boolean value that indicates whether the initial camera is set for the scene view.
    @State private var initialCameraIsSet = false
    /// A Boolean value that indicates if the user is calibrating.
    @State private var isCalibrating = false
    /// The location datasource that is used to access the device location.
    @State private var locationDataSource = SystemLocationDataSource()
    /// The error from the view.
    @State private var error: Error?
    
    /// Creates a world scale scene view.
    /// - Parameters:
    ///   - clippingDistance: Determines the clipping distance in meters around the camera. A value
    ///   of `nil` means that no data will be clipped.
    ///   - trackingMode: The type of tracking configuration used by the AR view.
    ///   - sceneViewBuilder: A closure that builds the scene view to be overlayed on top of the
    ///   augmented reality video feed.
    /// - Remark: The provided scene view will have certain properties overridden in order to
    /// be effectively viewed in augmented reality. Properties such as the camera controller,
    /// and view drawing mode.
    public init(
        clippingDistance: Double? = nil,
        trackingMode: TrackingMode,
        sceneViewBuilder: @escaping (SceneViewProxy) -> SceneView
    ) {
        self.clippingDistance = clippingDistance
        self.trackingMode = trackingMode
        self.sceneViewBuilder = sceneViewBuilder
        
        let cameraController = TransformationMatrixCameraController()
        cameraController.translationFactor = 1
        cameraController.clippingDistance = clippingDistance
        _cameraController = .init(initialValue: cameraController)
    }
    
    public var body: some View {
        Group {
            switch trackingMode {
            case .automatic:
                // By default we try the geo-tracking configuration. If it is not available at
                // the current location, fall back to world-tracking.
                if geoTrackingIsAvailable {
                    GeoTrackingSceneView(
                        arViewProxy: arViewProxy,
                        cameraController: cameraController,
                        calibrationViewModel: calibrationViewModel,
                        clippingDistance: clippingDistance,
                        initialCameraIsSet: $initialCameraIsSet,
                        calibrationViewIsPresented: isCalibrating,
                        locationDataSource: locationDataSource,
                        sceneView: sceneViewBuilder
                    )
                } else {
                    WorldTrackingSceneView(
                        arViewProxy: arViewProxy,
                        cameraController: cameraController,
                        calibrationViewModel: calibrationViewModel,
                        clippingDistance: clippingDistance,
                        initialCameraIsSet: $initialCameraIsSet,
                        calibrationViewIsPresented: isCalibrating,
                        locationDataSource: locationDataSource,
                        sceneView: sceneViewBuilder
                    )
                }
            case .geoTracking:
                GeoTrackingSceneView(
                    arViewProxy: arViewProxy,
                    cameraController: cameraController,
                    calibrationViewModel: calibrationViewModel,
                    clippingDistance: clippingDistance,
                    initialCameraIsSet: $initialCameraIsSet,
                    calibrationViewIsPresented: isCalibrating,
                    locationDataSource: locationDataSource,
                    sceneView: sceneViewBuilder
                )
            case .worldTracking:
                WorldTrackingSceneView(
                    arViewProxy: arViewProxy,
                    cameraController: cameraController,
                    calibrationViewModel: calibrationViewModel,
                    clippingDistance: clippingDistance,
                    initialCameraIsSet: $initialCameraIsSet,
                    calibrationViewIsPresented: isCalibrating,
                    locationDataSource: locationDataSource,
                    sceneView: sceneViewBuilder
                )
            }
        }
        .onDisappear {
            Task { await locationDataSource.stop() }
        }
        .task {
            // Start the location data source when the view appears.
            
            // Request when-in-use location authorization.
            // The view utilizes a location datasource and it will not start until authorized.
            let locationManager = CLLocationManager()
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            }
            if !checkTrackingCapabilities(locationManager) {
                print("Device doesn't support full accuracy location.")
            }
            do {
                try await locationDataSource.start()
            } catch {
                self.error = error
            }
        }
        .task {
            do {
                geoTrackingIsAvailable = try await checkGeoTrackingAvailability()
            } catch {
                self.error = error
            }
        }
        .overlay(alignment: calibrationButtonAlignment) {
            if !calibrationViewIsHidden && !isCalibrating {
                Button {
                    withAnimation {
                        isCalibrating = true
                    }
                } label: {
                    Text(calibrateLabel)
                        .padding()
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(!initialCameraIsSet)
                .padding()
                .padding(.vertical)
            }
        }
        .overlay(alignment: .bottom) {
            if isCalibrating {
                CalibrationView(viewModel: calibrationViewModel, isPresented: $isCalibrating)
                    .padding(.bottom)
            }
        }
    }
    
    /// Sets the visibility of the calibration view for the AR experience.
    /// - Parameter hidden: A Boolean value that indicates whether to hide the
    ///  calibration view.
    public func calibrationViewHidden(_ hidden: Bool) -> Self {
        var view = self
        view.calibrationViewIsHidden = hidden
        return view
    }
    
    /// Sets the alignment of the calibration button.
    /// - Parameter alignment: The alignment for the calibration button.
    public func calibrationButtonAlignment(_ alignment: Alignment) -> Self {
        var view = self
        view.calibrationButtonAlignment = alignment
        return view
    }
    
    /// Checks if GPS is providing the most accurate location and heading.
    /// - Parameter locationManager: The location manager to determine the accuracy authorization.
    /// - Returns: A Boolean value that indicates whether tracking is accurate.
    private func checkTrackingCapabilities(_ locationManager: CLLocationManager) -> Bool {
        let headingAvailable = CLLocationManager.headingAvailable()
        let fullAccuracy: Bool
        switch locationManager.accuracyAuthorization {
        case .fullAccuracy:
            // World scale AR experience must use full accuracy of device location.
            fullAccuracy = true
        default:
            fullAccuracy = false
        }
        return headingAvailable && fullAccuracy
    }
    
    /// Checks if the hardware and the current location supports geo-tracking.
    /// - Returns: A Boolean value that indicates whether geo-tracking is available.
    private func checkGeoTrackingAvailability() async throws -> Bool {
        if !ARGeoTrackingConfiguration.isSupported {
            // Return false if the device doesn't satisfy the hardware requirements.
            return false
        }
        return try await ARGeoTrackingConfiguration.checkAvailability()
    }
}

public extension WorldScaleSceneView {
    /// The type of tracking configuration used by the view.
    enum TrackingMode {
        /// If geo-tracking is unavailable, fall back to world-tracking.
        case automatic
        /// Geo-tracking.
        case geoTracking
        /// World-tracking.
        case worldTracking
    }
}

private extension ARGeoTrackingConfiguration {
    /// Determines the availability of geo tracking at the current location.
    /// - Returns: A Boolean that indicates whether geo-tracking is available at the current
    /// location or not. If not, an error will be thrown that indicates why geo tracking is
    /// not available at the current location.
    static func checkAvailability() async throws -> Bool {
        return try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Bool, Error>) in
            self.checkAvailability { isAvailable, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: isAvailable)
                }
            }
        }
    }
}

private extension WorldScaleSceneView {
    var calibrateLabel: String {
        String(
            localized: "Calibrate",
            bundle: .toolkitModule,
            comment: """
                 A label for a button to show the calibration view.
                 """
        )
    }
}

public extension WorldScaleSceneView {
    /// Determines the scene point for the given screen point.
    /// - Parameter screenPoint: The point in screen's coordinate space.
    /// - Returns: The scene point corresponding to screen point.
    private func arScreenToLocation(screenPoint: CGPoint) -> Point? {
        // Use the `raycast` method to get the matrix of `screenPoint`.
        guard let localOffsetMatrix = arViewProxy.raycast(from: screenPoint) else { return nil }
        let originTransformationMatrix = cameraController.originCamera.transformationMatrix
        let scenePointMatrix = originTransformationMatrix.adding(localOffsetMatrix)
        // Create a camera from transformationMatrix and return its location.
        return Camera(transformationMatrix: scenePointMatrix).location
    }
    
    /// Sets a closure to perform when a single tap occurs on the view.
    func onSingleTapGesture(
        perform action: @escaping (_ screenPoint: CGPoint, _ scenePoint: Point?) -> Void
    ) -> some View {
        self
            .onSingleTapGesture { tapPoint in
                let scenePoint = arScreenToLocation(screenPoint: tapPoint)
                action(tapPoint, scenePoint)
            }
    }
}

extension SceneView {
    /// A modifier to combine various modifiers that apply to both world and geo tracking scene view.
    func worldScaleSetup(cameraController: TransformationMatrixCameraController) -> SceneView {
        self
            .cameraController(cameraController)
            .attributionBarHidden(true)
            .spaceEffect(.transparent)
            .atmosphereEffect(.off)
            .interactiveNavigationDisabled(true)
    }
}
