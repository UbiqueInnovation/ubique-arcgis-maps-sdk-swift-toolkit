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

import ArcGIS

extension AttachmentFormElement : AttachmentsFeatureElement {
    /// Indicates how to display the attachments.
    /// If `list` is specified, attachments show as links.
    /// If `preview` is specified, attachments expand to the width of the view.
    /// Setting the value to `auto` allows applications to choose the most suitable default experience.
    public var attachmentDisplayType: AttachmentsFeatureElementDisplayType {
        // Currently, Attachment Form Elements only support `Preview`.
        AttachmentsFeatureElementDisplayType.preview
    }
    
    /// The list of attachments.
    ///
    /// The feature attachments associated with this element.
    /// This property will be empty if the element has not yet been evaluated.
    public var featureAttachments: [FeatureAttachment] {
        get async throws {
            try await fetchAttachments()
            return attachments.map { $0 as FeatureAttachment }
        }
    }
    
    /// A descriptive label that appears with the element. Can be an empty string.
    public var title: String {
        get {
            label
        }
    }
}
