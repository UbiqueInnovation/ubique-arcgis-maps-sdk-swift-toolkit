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

struct AttachmentPreview: View {
    var attachmentModels: [AttachmentModel]
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(attachmentModels) { attachmentModel in
                    AttachmentCell(attachmentModel: attachmentModel)
                }
            }
        }
    }
    
    struct AttachmentCell: View  {
        @ObservedObject var attachmentModel: AttachmentModel
        @State var url: URL?
        
        var body: some View {
            VStack(alignment: .center) {
                ZStack {
                    if attachmentModel.loadStatus != .loading {
                        ThumbnailView(
                            attachmentModel: attachmentModel,
                            size: attachmentModel.usingDefaultImage ?
                            CGSize(width: 36, height: 36) :
                                CGSize(width: 120, height: 120)
                        )
                    } else {
                        ProgressView()
                            .padding(8)
                            .background(Color.white.opacity(0.75))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                if attachmentModel.usingDefaultImage {
                    Text(attachmentModel.attachment.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding([.leading, .trailing], 4)
                    Text("\(attachmentModel.attachment.size.formatted(.byteCount(style: .file)))")
                        .foregroundColor(.secondary)
                        .padding([.leading, .trailing], 4)
                }
            }
            .font(.caption)
            .frame(width: 120, height: 120)
            .background(Color.gray.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture {
                if attachmentModel.attachment.loadStatus == .loaded {
                    url = attachmentModel.attachment.fileURL
                }
                else if attachmentModel.attachment.loadStatus == .notLoaded {
                    attachmentModel.load(thumbnailSize: CGSize(width: 120, height: 120))
                }
            }
            .quickLookPreview($url)
        }
    }
}
