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
import Foundation

/// Indicates how to display the attachments. If `list` is specified, attachments show as links. If `preview` is specified, attachments expand to the width of the view. Setting the value to `auto` allows applications to choose the most suitable default experience for their application.
public enum AttachmentsFeatureElementDisplayType {
    /// Show attachments as links.
    case list
    /// Attachments expand to the width of the view.
    case preview
    /// Allows applications to choose the most suitable default experience.
    case auto
}

/// Common properties for elements which display feature attachments.
public protocol AttachmentsFeatureElement {
    /// Indicates how to display the attachments.
    /// If `list` is specified, attachments show as links. If `preview` is specified, attachments expand to the width of the view. Setting the value to `auto` allows applications to choose the most suitable default experience.
    var attachmentDisplayType: AttachmentsFeatureElementDisplayType { get }
    
    /// A string value describing the element in detail. Can be an empty string.
    var description: String { get }
    
    /// The list of attachments.
    ///
    /// The feature attachments associated with this element. This property will be empty if the element has not yet been evaluated.
    var featureAttachments: [FeatureAttachment] { get async throws }
    
    /// A descriptive label that appears with the element. Can be an empty string.
    var title: String { get }
}

extension AttachmentsFeatureElementDisplayType {
    /// Creates a display type from an attachment popup element's display type.
    /// - Parameter kind: The display type of the popup element.
    init(kind: AttachmentsPopupElement.DisplayType) {
        switch kind {
        case .list:
            self = .list
        case .preview:
            self = .preview
        case .auto:
            self = .auto
        }
    }
}
