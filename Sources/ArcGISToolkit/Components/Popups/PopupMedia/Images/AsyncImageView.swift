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

import SwiftUI
import ArcGIS

/// A view displaying an async image, with error display and progress view.
struct AsyncImageView: View {
    /// The `ContentMode` defining how the image fills the available space.
    let contentMode: ContentMode
    
    /// The size of the media's frame.
    private let mediaSize: CGSize?
    
    /// The data model for an `AsyncImageView`.
    @StateObject var viewModel: AsyncImageViewModel
    
    /// Creates an `AsyncImageView`.
    /// - Parameters:
    ///   - url: The `URL` of the image.
    ///   - contentMode: The `ContentMode` defining how the image fills the available space.
    ///   - refreshInterval: The refresh interval, in seconds. A `nil` interval means never refresh.
    ///   - mediaSize: The size of the media's frame.
    init(
        url: URL,
        contentMode: ContentMode = .fit,
        refreshInterval: TimeInterval? = nil,
        mediaSize: CGSize? = nil
    ) {
        self.contentMode = contentMode
        self.mediaSize = mediaSize
        
        _viewModel = StateObject(
            wrappedValue: AsyncImageViewModel(
                imageURL: url,
                refreshInterval: refreshInterval
            )
        )
    }
    
    var body: some View {
        ZStack {
            switch viewModel.result {
            case .success(let image):
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } else {
                    ProgressView()
                }
            case .failure(let error):
                HStack(alignment: .center) {
                    Image(systemName: "exclamationmark.circle")
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.red)
                    Text("An error occurred loading the image: \(error.localizedDescription).")
                }
                .padding([.top, .bottom])
            }
            if #available(iOS 16.0, *),
               let progressInterval = viewModel.progressInterval {
                VStack {
                    ProgressView(
                        timerInterval: progressInterval,
                        countsDown: false
                    )
                    .tint(.white)
                    .opacity(0.5)
                    .padding([.top], 4)
                    .frame(width: mediaSize?.width)
                    Spacer()
                }
            }
        }
    }
}
