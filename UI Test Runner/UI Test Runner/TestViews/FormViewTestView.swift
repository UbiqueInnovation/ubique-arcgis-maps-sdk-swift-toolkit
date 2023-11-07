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

struct FormViewTestView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    /// The `Map` displayed in the `MapView`.
    @State private var map: Map?
    
    /// A Boolean value indicating whether or not the form is displayed.
    @State private var isPresented = false
    
    /// The form view model provides a channel of communication between the form view and its host.
    @StateObject private var formViewModel = FormViewModel()
    
    /// The form being edited in the form view.
    @State private var featureForm: FeatureForm?
    
    /// The current test case.
    @State private var testCase: TestCase?
    
    var body: some View {
        Group {
            if let map, let testCase {
                makeMapView(map, testCase)
            } else {
                testCaseSelector
            }
        }
        .task {
            ArcGISEnvironment.authenticationManager.arcGISCredentialStore.add(
                try! await TokenCredential.credential(
                    for: URL(string: "https://\(String.formViewTestDataDomain!)")!,
                    username: String.formViewTestDataUsername!,
                    password: String.formViewTestDataPassword!
                )
            )
        }
    }
}

private extension FormViewTestView {
    /// Make the main test UI.
    /// - Parameters:
    ///   - map: The map under test.
    ///   - testCase: The test definition.
    func makeMapView(_ map: Map, _ testCase: TestCase) -> some View {
        MapView(map: map)
            .task {
                try? await map.load()
                let featureLayer = map.operationalLayers.first as? FeatureLayer
                let parameters = QueryParameters()
                parameters.addObjectID(testCase.objectID)
                let result = try? await featureLayer?.featureTable?.queryFeatures(using: parameters)
                guard let feature = result?.features().makeIterator().next() as? ArcGISFeature else { return }
                try? await feature.load()
                guard let formDefinition = (feature.table?.layer as? FeatureLayer)?.featureFormDefinition else { return }
                featureForm = FeatureForm(feature: feature, definition: formDefinition)
                formViewModel.startEditing(feature, featureForm: featureForm!)
                isPresented = true
            }
            .ignoresSafeArea(.keyboard)
        
            .floatingPanel(
                selectedDetent: .constant(.full),
                horizontalAlignment: .leading,
                isPresented: $isPresented
            ) {
                FormView(featureForm: featureForm)
                    .padding()
            }
        
            .environmentObject(formViewModel)
            .navigationBarBackButtonHidden(isPresented)
            .toolbar {
                // Once iOS 16.0 is the minimum supported, the two conditionals to show the
                // buttons can be merged and hoisted up as the root content of the toolbar.
                
                ToolbarItem(placement: .navigationBarLeading) {
                    if isPresented && !useControlsInForm {
                        Button("Cancel", role: .cancel) {
                            formViewModel.undoEdits()
                            isPresented = false
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isPresented && !useControlsInForm {
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
    
    /// Test case selection UI.
    var testCaseSelector: some View {
        ScrollView {
            ForEach(cases) { testCase in
                Button(testCase.id) {
                    self.testCase = testCase
                    map = Map(url: testCase.url)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    /// A Boolean value indicating whether the form controls should be shown directly in the form's
    ///  presenting container.
    var useControlsInForm: Bool {
        verticalSizeClass == .compact ||
        UIDevice.current.userInterfaceIdiom == .mac ||
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    /// Test conditions for a Form View.
    struct TestCase: Identifiable {
        /// The name of the test case.
        let id: String
        /// The object ID of the feature being tested.
        let objectID: Int
        /// The test data location.
        let url: URL
        
        /// Creates a FormView test case.
        /// - Parameters:
        ///   - name: The name of the test case.
        ///   - objectID: The object ID of the feature being tested.
        ///   - portalID: The portal ID of the test data.
        init(_ name: String, objectID: Int, portalID: String) {
            self.id = name
            self.objectID = objectID
            self.url = .init(
                string: String("https://arcgis.com/home/item.html?id=\(portalID)")
            )!
        }
    }
    
    /// The set of all Form View UI test cases.
    var cases: [TestCase] {[
        .init("testCase_1_1", objectID: 1, portalID: String.formViewTestDataCase_1_x!),
        .init("testCase_1_2", objectID: 1, portalID: String.formViewTestDataCase_1_x!),
        .init("testCase_1_3", objectID: 1, portalID: String.formViewTestDataCase_1_x!),
        .init("testCase_1_4", objectID: 1, portalID: String.formViewTestDataCase_1_4!),
        .init("testCase_2_1", objectID: 1, portalID: String.formViewTestDataCase_2_x!),
        .init("testCase_2_2", objectID: 1, portalID: String.formViewTestDataCase_2_x!),
        .init("testCase_2_3", objectID: 1, portalID: String.formViewTestDataCase_2_x!),
        .init("testCase_2_4", objectID: 1, portalID: String.formViewTestDataCase_2_x!),
        .init("testCase_2_5", objectID: 1, portalID: String.formViewTestDataCase_2_x!),
        .init("testCase_2_6", objectID: 1, portalID: String.formViewTestDataCase_2_x!),
        .init("testCase_3_1", objectID: 2, portalID: String.formViewTestDataCase_3_x!),
        .init("testCase_3_2", objectID: 2, portalID: String.formViewTestDataCase_3_x!),
        .init("testCase_3_3", objectID: 2, portalID: String.formViewTestDataCase_3_x!),
        .init("testCase_3_4", objectID: 2, portalID: String.formViewTestDataCase_3_x!),
        .init("testCase_3_5", objectID: 2, portalID: String.formViewTestDataCase_3_x!),
        .init("testCase_3_6", objectID: 2, portalID: String.formViewTestDataCase_3_x!),
        .init("testCase_4_1", objectID: 1, portalID: String.formViewTestDataCase_4_x!),
        .init("testCase_5_1", objectID: 1, portalID: String.formViewTestDataCase_5_x!),
        .init("testCase_5_2", objectID: 1, portalID: String.formViewTestDataCase_5_x!),
        .init("testCase_5_3", objectID: 1, portalID: String.formViewTestDataCase_5_x!),
    ]}
}
