// Copyright 2021 Esri.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI
import ArcGIS

/// The `BasemapGallery` tool displays a collection of basemaps from either
/// ArcGIS Online, a user-defined portal, or an array of `BasemapGalleryItem`s.
/// When a new basemap is selected from the `BasemapGallery` and the optional
/// `BasemapGalleryViewModel.geoModel` property is set, then the basemap of the
/// `geoModel` is replaced with the basemap in the gallery.
public struct BasemapGallery: View {
    /// The view style of the gallery.
    public enum Style {
        /// The `BasemapGallery` will display as a grid when there is appropriate
        /// width available for the gallery to do so. Otherwise the gallery will display as a list.
        case automatic
        /// The `BasemapGallery` will display as a grid.
        case grid
        /// The `BasemapGallery` will display as a list.
        case list
    }
    
    /// Creates a `BasemapGallery`.
    /// - Parameter viewModel: The view model used by the `BasemapGallery`.
    public init(viewModel: BasemapGalleryViewModel? = nil) {
        self.viewModel = viewModel ?? BasemapGalleryViewModel()
    }
    
    /// The view model used by the view. The `BasemapGalleryViewModel` manages the state
    /// of the `BasemapGallery`. The view observes `BasemapGalleryViewModel` for changes
    /// in state. The view updates the state of the `BasemapGalleryViewModel` in response to
    /// user action.
    @ObservedObject
    public var viewModel: BasemapGalleryViewModel
    
    /// The style of the basemap gallery. The gallery can be displayed as a list, grid, or automatically
    /// switch between the two based on screen real estate. Defaults to `automatic`.
    /// Set using the `style` modifier.
    private var style: Style = .automatic
    
    /// The size class used to determine if the basemap items should dispaly in a list or grid.
    /// If the size class is `.regular`, they display in a grid. If it is `.compact`, they display in a list.
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    /// `true` if the horizontal size class is `.regular`, `false` if it's not.
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    /// The width of the gallery, taking into account the horizontal size class of the device.
    private var galleryWidth: CGFloat? {
        isRegularWidth ? 300 : 150
    }

    /// A Boolean value indicating whether to show an error alert.
    @State
    private var showErrorAlert = false
    
    /// The current alert item to display.
    @State
    private var alertItem: AlertItem?
    
    public var body: some View {
        makeGalleryView()
            .frame(width: galleryWidth)
            .alert(
                alertItem?.title ?? "",
                isPresented: $showErrorAlert,
                presenting: alertItem) { item in
                    Text(item.message)
                }
    }
}

private extension BasemapGallery {
    /// The gallery view, displayed in the specified columns.
    /// - Parameter columns: The columns used to display the basemap items.
    /// - Returns: A view representing the basemap gallery with the specified columns.
    func makeGalleryView() -> some View {
        ScrollView {
            switch style {
            case .automatic:
                if isRegularWidth {
                    makeGridView()
                }
                else {
                    makeListView()
                }
            case .grid:
                makeGridView()
            case .list:
                makeListView()
            }
        }
    }
    
    /// The gallery view, displayed as a grid.
    /// - Returns: A view representing the basemap gallery grid.
    func makeGridView() -> some View {
        internalMakeGalleryView(
            Array(
                repeating: GridItem(
                    .flexible(),
                    alignment: .top
                ),
                count: 3
            )
        )
    }
    
    /// The gallery view, displayed as a list.
    /// - Returns: A view representing the basemap gallery list.
    func makeListView() -> some View {
        internalMakeGalleryView(
            [
                .init(
                    .flexible(),
                    alignment: .top
                )
            ]
        )
    }
    
    func internalMakeGalleryView(_ columns: [GridItem]) -> some View {
        LazyVGrid(columns: columns) {
            ForEach(viewModel.items) { item in
                BasemapGalleryCell(
                    item: item,
                    isSelected: item == viewModel.currentItem
                ) {
                    if let loadError = item.loadBasemapError {
                        alertItem = AlertItem(loadBasemapError: loadError)
                        showErrorAlert = true
                    } else {
                        viewModel.currentItem = item
                    }
                }
            }
        }
    }
}

// MARK: Modifiers

public extension BasemapGallery {
    /// The style of the basemap gallery. Defaults to `.automatic`.
    /// - Parameter style: The `Style` to use.
    /// - Returns: The `BasemapGallery`.
    func style(
        _ newStyle: Style
    ) -> BasemapGallery {
        var copy = self
        copy.style = newStyle
        return copy
    }
}

// MARK: AlertItem

/// An item used to populate a displayed alert.
struct AlertItem {
    var title: String = ""
    var message: String = ""
}

extension AlertItem {
    /// Creates an alert item based on an error generated loading a basemap.
    /// - Parameter loadBasemapError: The load basemap error.
    init(loadBasemapError: Error) {
        self.init(
            title: "Error loading basemap.",
            message: "\((loadBasemapError as? RuntimeError)?.failureReason ?? "The basemap failed to load for an unknown reason.")"
        )
    }
}
