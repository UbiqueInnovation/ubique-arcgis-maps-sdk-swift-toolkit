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

import Foundation
import ArcGIS
import ARKit

extension SceneViewProxy {
    /// Updates the scene view's camera for a given augmented reality frame.
    /// - Parameters:
    ///   - frame: The current AR frame.
    ///   - cameraController: The current camera controller assigned to the scene view.
    ///   - orientation: The device orientation.
    func updateCamera(
        frame: ARFrame,
        cameraController: TransformationMatrixCameraController,
        orientation: UIDeviceOrientation,
        initialTransformation: TransformationMatrix? = nil
    ) {
        let transform = frame.camera.transform(for: orientation)
        let quaternion = simd_quatf(transform)
        let transformationMatrix = TransformationMatrix.normalized(
            quaternionX: Double(quaternion.vector.x),
            quaternionY: Double(quaternion.vector.y),
            quaternionZ: Double(quaternion.vector.z),
            quaternionW: Double(quaternion.vector.w),
            translationX: Double(transform.columns.3.x),
            translationY: Double(transform.columns.3.y),
            translationZ: Double(transform.columns.3.z)
        )
        
        // Set the matrix on the camera controller.
        if let initialTransformation {
            cameraController.transformationMatrix = initialTransformation.adding(transformationMatrix)
        } else {
            cameraController.transformationMatrix = transformationMatrix
        }
    }
}

private extension ARCamera {
    /// The transform rotated for a particular device orientation.
    /// - Parameter orientation: The device orientation that the transform is appropriate for.
    /// - Precondition: 'orientation.isValidInterfaceOrientation'
    func transform(for orientation: UIDeviceOrientation) -> simd_float4x4 {
        precondition(orientation.isValidInterfaceOrientation)
        switch orientation {
        case .portrait:
            // Rotate camera transform 90 degrees clockwise in the XY plane.
            return simd_float4x4(
                transform.columns.1,
                -transform.columns.0,
                transform.columns.2,
                transform.columns.3
            )
        case .landscapeLeft:
            // No rotation necessary.
            return transform
        case .landscapeRight:
            // Rotate 180.
            return simd_float4x4(
                -transform.columns.0,
                -transform.columns.1,
                transform.columns.2,
                transform.columns.3
            )
        case .portraitUpsideDown:
            // Rotate 90 counter clockwise.
            return simd_float4x4(
                -transform.columns.1,
                transform.columns.0,
                transform.columns.2,
                transform.columns.3
            )
        default:
            preconditionFailure()
        }
    }
}
