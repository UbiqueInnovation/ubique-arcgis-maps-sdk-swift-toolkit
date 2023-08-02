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

import ArcGIS
import ArcGISToolkit
import SwiftUI

struct FormExampleView: View {
    /// The `Map` displayed in the `MapView`.
    @State private var map = Map(url: .sampleData)!
    
    /// The point on the screen the user tapped on to identify a feature.
    @State private var identifyScreenPoint: CGPoint?
    
    /// A Boolean value indicating whether or not the form is displayed.
    @State private var isPresented = false
    
    /// The form view model provides a channel of communication between the form view and its host.
    @StateObject private var formViewModel = FormViewModel()
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: map)
                .onSingleTapGesture { screenPoint, _ in
                    identifyScreenPoint = screenPoint
                }
                .task(id: identifyScreenPoint) {
                    if let feature = await identifyFeature(with: mapViewProxy) {
                        formViewModel.startEditing(feature)
                        isPresented = true
                    }
                }
                .ignoresSafeArea(.keyboard)
                
                // Present a FormView in a native SwiftUI sheet
                .sheet(isPresented: $isPresented) {
                    Group {
                        if #available(iOS 16.4, *) {
                            FormView()
                                .padding()
                                .presentationBackground(.thinMaterial)
                                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                                .presentationDetents([.medium])
                        } else {
                            FormView()
                                .padding()
                        }
                        #if targetEnvironment(macCatalyst)
                        Button("Dismiss") {
                            isPresented = false
                        }
                        .padding()
                        #endif
                    }
                    .environmentObject(formViewModel)
                }
                
                // Or present a FormView in a Floating Panel (provided via the Toolkit)
//                .floatingPanel(
//                    selectedDetent: .constant(.half),
//                    horizontalAlignment: .leading,
//                    isPresented: $isPresented
//                ) {
//                    Group {
//                        if isPresented {
//                            FormView()
//                                .padding()
//                                .environmentObject(formViewModel)
//                        }
//                    }
//                }
                
                .toolbar {
                    // Once iOS 16.0 is the minimum supported, the two conditionals to show the
                    // buttons can be merged and hoisted up as the root content of the toolbar.
                    
                    ToolbarItem(placement: .navigationBarLeading) {
                        if isPresented {
                            Button("Cancel", role: .cancel) {
                                formViewModel.undoEdits()
                                isPresented = false
                            }
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if isPresented {
                            Button("Submit") {
                                Task {
                                    await formViewModel.submitChanges()
                                    isPresented = false
                                }
                            }
                        }
                    }
                }
        }
    }
}

extension FormExampleView {
    /// Identifies features, if any, at the current screen point.
    /// - Parameter proxy: The proxy to use for identification.
    /// - Returns: The first identified feature.
    func identifyFeature(with proxy: MapViewProxy) async -> ArcGISFeature? {
        if let screenPoint = identifyScreenPoint,
           let feature = try? await Result(awaiting: {
               try await proxy.identify(
                on: map.operationalLayers.first!,
                screenPoint: screenPoint,
                tolerance: 10
               )
           })
            .cancellationToNil()?
            .get()
            .geoElements
            .first as? ArcGISFeature {
            return feature
        }
        return nil
    }
}

private extension URL {
    static var sampleData: Self {
        .init(string: <#URL#>)!
    }
}
