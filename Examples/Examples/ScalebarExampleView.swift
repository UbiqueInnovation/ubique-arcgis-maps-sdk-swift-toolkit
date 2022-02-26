// Copyright 2022 Esri.

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

struct ScalebarExampleView: View {
    /// The map displayed in the map view.
    private let map = Map(basemapStyle: .arcGISImagery)

    @State
    /// Allows for communication between the Scalebar and MapView or SceneView.
    private var scale: Double?

    /// Allows for communication between the Scalebar and MapView or SceneView.
    @State
    private var viewpoint: Viewpoint? = Viewpoint(
        center: Point(x: -117.19494, y: 34.05723, spatialReference: .wgs84),
        scale: 10_000
    )

    /// Allows for communication between the Scalebar and MapView or SceneView.
    @State
    private var visibleArea: Polygon?

    var body: some View {
        MapView(map: map, viewpoint: viewpoint)
            .onViewpointChanged(kind: .centerAndScale) { viewpoint = $0 }
            .onVisibleAreaChanged { visibleArea = $0 }
            .onScaleChanged { scale = $0 }
            .overlay(alignment: .bottomLeading) {
                Scalebar(scale, viewpoint, visibleArea)
                    .border(.red, width: 2)
                    .padding([.leading], 10)
                    .border(.green, width: 2)
                    .padding([.bottom], 30)
                    .border(.blue, width: 2)
            }
    }
}
