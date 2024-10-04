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

@preconcurrency import AVFoundation
import SwiftUI

/// Scans machine readable information like QR codes and barcodes.
struct CodeScannerView: UIViewControllerRepresentable {
    @Binding var scannerIsPresented: Bool
    
    @Binding var scanOutput: String
    
    class Coordinator: NSObject, ScannerViewControllerDelegate {
        @Binding var scanOutput: String
        @Binding var scannerIsPresented: Bool
        
        init(scannedCode: Binding<String>, isShowingScanner: Binding<Bool>) {
            _scanOutput = scannedCode
            _scannerIsPresented = isShowingScanner
        }
        
        func didScanCode(_ code: String) {
            scanOutput = code
            scannerIsPresented = false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(scannedCode: $scanOutput, isShowingScanner: $scannerIsPresented)
    }
    
    func makeUIViewController(context: Context) -> ScannerViewController {
        let scannerViewController = ScannerViewController()
        scannerViewController.delegate = context.coordinator
        return scannerViewController
    }
    
    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

protocol ScannerViewControllerDelegate: AnyObject {
    func didScanCode(_ code: String)
}

class ScannerViewController: UIViewController, @preconcurrency AVCaptureMetadataOutputObjectsDelegate {
    
    // MARK: Constants
    
    private let autoScanDelay = 1.0
    
    private let captureSession = AVCaptureSession()
    
    private let feedbackGenerator = UISelectionFeedbackGenerator()
    
    private let metadataObjectsOverlayLayersDrawingSemaphore = DispatchSemaphore(value: 1)
    
    private let sessionQueue = DispatchQueue(label: "ScannerViewController")
    
    // MARK: Variables
    
    private var autoScanTimer: Timer?
    
    private var metadataObjectOverlayLayers = [MetadataObjectLayer]()
    
    private var previewLayer: AVCaptureVideoPreviewLayer!
    
    private var removeMetadataObjectOverlayLayersTimer: Timer?
    
    weak var delegate: ScannerViewControllerDelegate?
    
    private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        UITapGestureRecognizer(target: self, action: #selector(userDidTap(with:)))
    }()
    
    private class MetadataObjectLayer: CAShapeLayer {
        var metadataObject: AVMetadataObject?
    }
    
    // MARK: UIViewController methods
    
    override func viewDidLayoutSubviews() {
        previewLayer.frame = view.bounds
        let deviceOrientation = UIDevice.current.orientation
        switch deviceOrientation {
        case .landscapeLeft:
            previewLayer.connection!.videoOrientation = .landscapeRight
        case .landscapeRight:
            previewLayer.connection!.videoOrientation = .landscapeLeft
        case .portraitUpsideDown:
            previewLayer.connection!.videoOrientation = .portraitUpsideDown
        default:
            previewLayer.connection!.videoOrientation = .portrait
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [
                // Barcodes
                .codabar,
                .code39,
                .code39Mod43,
                .code93,
                .code128,
                .ean8,
                .ean13,
                .gs1DataBar,
                .gs1DataBarExpanded,
                .gs1DataBarLimited,
                .interleaved2of5,
                .itf14,
                .upce,
                
                // 2D Codes
                .aztec,
                .dataMatrix,
                .microPDF417,
                .microQR,
                .pdf417,
                .qr,
            ]
        } else {
            return
        }
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.addGestureRecognizer(tapGestureRecognizer)
        view.layer.addSublayer(previewLayer)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async { [captureSession] in
            captureSession.startRunning()
        }
    }
    
    // MARK: AVCaptureMetadataOutputObjectsDelegate methods
    
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        if metadataObjectsOverlayLayersDrawingSemaphore.wait(timeout: .now()) == .success {
            DispatchQueue.main.async {
                self.removeMetadataObjectOverlayLayers()
                var metadataObjectOverlayLayers = [MetadataObjectLayer]()
                for metadataObject in metadataObjects {
                    let metadataObjectOverlayLayer = self.createMetadataObjectOverlayWithMetadataObject(metadataObject)
                    metadataObjectOverlayLayers.append(metadataObjectOverlayLayer)
                }
                self.addMetadataObjectOverlayLayersToVideoPreviewView(metadataObjectOverlayLayers)
                self.metadataObjectsOverlayLayersDrawingSemaphore.signal()
            }
            evaluateOutputForAutoScan(metadataObjects)
        }
    }
    
    // MARK: Scan handling methods
    
    private func addMetadataObjectOverlayLayersToVideoPreviewView(_ metadataObjectOverlayLayers: [MetadataObjectLayer]) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for metadataObjectOverlayLayer in metadataObjectOverlayLayers {
            previewLayer.addSublayer(metadataObjectOverlayLayer)
        }
        CATransaction.commit()
        self.metadataObjectOverlayLayers = metadataObjectOverlayLayers
        removeMetadataObjectOverlayLayersTimer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(removeMetadataObjectOverlayLayers),
            userInfo: nil,
            repeats: false
        )
    }
    
    private func barcodeOverlayPathWithCorners(_ corners: [CGPoint]) -> CGMutablePath {
        let path = CGMutablePath()
        if let corner = corners.first {
            path.move(to: corner, transform: .identity)
            for corner in corners[1..<corners.count] {
                path.addLine(to: corner)
            }
            path.closeSubpath()
        }
        return path
    }
    
    private func createMetadataObjectOverlayWithMetadataObject(_ metadataObject: AVMetadataObject) -> MetadataObjectLayer {
        let transformedMetadataObject = previewLayer.transformedMetadataObject(for: metadataObject)
        let metadataObjectOverlayLayer = MetadataObjectLayer()
        metadataObjectOverlayLayer.metadataObject = transformedMetadataObject
        metadataObjectOverlayLayer.lineJoin = .round
        metadataObjectOverlayLayer.strokeColor = view.tintColor.withAlphaComponent(0.7).cgColor
        metadataObjectOverlayLayer.lineWidth = 2.5
        metadataObjectOverlayLayer.fillColor = view.tintColor.withAlphaComponent(0.25).cgColor
        metadataObjectOverlayLayer.strokeColor = view.tintColor.withAlphaComponent(1).cgColor
        guard let barcodeMetadataObject = transformedMetadataObject as? AVMetadataMachineReadableCodeObject else {
            return metadataObjectOverlayLayer
        }
        let barcodeOverlayPath = barcodeOverlayPathWithCorners(barcodeMetadataObject.corners)
        metadataObjectOverlayLayer.path = barcodeOverlayPath
        let fontSize = 12.0
        if let stringValue = barcodeMetadataObject.stringValue, !stringValue.isEmpty {
            let barcodeOverlayBoundingBox = barcodeOverlayPath.boundingBox
            let minimumTextLayerHeight: CGFloat = fontSize + 4
            let textLayerHeight: CGFloat
            if barcodeOverlayBoundingBox.size.height < minimumTextLayerHeight {
                textLayerHeight = minimumTextLayerHeight
            } else {
                textLayerHeight = barcodeOverlayBoundingBox.size.height
            }
            let textLayer = CATextLayer()
            textLayer.alignmentMode = .center
            textLayer.bounds = CGRect(x: .zero, y: .zero, width: barcodeOverlayBoundingBox.size.width, height: textLayerHeight)
            textLayer.contentsScale = UIScreen.main.scale
            textLayer.font = UIFont.boldSystemFont(ofSize: 19).fontName as CFString
            textLayer.position = CGPoint(x: barcodeOverlayBoundingBox.midX, y: barcodeOverlayBoundingBox.midY)
            textLayer.string = NSAttributedString(
                string: stringValue,
                attributes: [
                    .font: UIFont.boldSystemFont(ofSize: fontSize),
                    .foregroundColor: UIColor.white.cgColor,
                    .strokeWidth: -5.0,
                    .strokeColor: UIColor.black.cgColor
                ]
            )
            textLayer.isWrapped = true
            textLayer.transform = previewLayer.transform
            metadataObjectOverlayLayer.addSublayer(textLayer)
        }
        return metadataObjectOverlayLayer
    }
    
    /// <#Description#>
    /// - Parameter output: The sect of scanned codes.
    private func evaluateOutputForAutoScan(_ output: [AVMetadataObject]) {
        if !output.isEmpty {
            if output.count > 1 {
                self.autoScanTimer?.invalidate()
            } else {
                if !(self.autoScanTimer?.isValid ?? false), let metadataObject = output.first {
                    self.autoScanTimer = Timer.scheduledTimer(withTimeInterval: autoScanDelay, repeats: false) { _ in
                        Task { @MainActor in
                            self.scan(metadataObject)
                        }
                    }
                }
            }
        }
    }
    
    @objc
    private func removeMetadataObjectOverlayLayers() {
        for sublayer in metadataObjectOverlayLayers {
            sublayer.removeFromSuperlayer()
        }
        metadataObjectOverlayLayers = []
        removeMetadataObjectOverlayLayersTimer?.invalidate()
        removeMetadataObjectOverlayLayersTimer = nil
    }
    
    /// Triggers the delegated scan method.
    /// - Parameter metadataObject: The machine readable code.
    private func scan(_ metadataObject: AVMetadataObject) {
        if let machineReadableCodeObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = machineReadableCodeObject.stringValue {
            delegate?.didScanCode(stringValue)
            if #available(iOS 17.5, *) {
                self.feedbackGenerator.selectionChanged(
                    at: CGPoint(
                        x: metadataObject.bounds.midX,
                        y: metadataObject.bounds.midY
                    )
                )
            }
        }
    }
    
    @objc
    private func userDidTap(with tapGestureRecognizer: UITapGestureRecognizer) {
        let point = tapGestureRecognizer.location(in: view)
        metadataObjectOverlayLayers.forEach { metadataObjectLayer in
            if metadataObjectLayer.path?.contains(point) ?? false,
               let metadataObject = metadataObjectLayer.metadataObject {
                scan(metadataObject)
            }
        }
    }
}

private extension String {
    static var tapToScan: Self {
        .init(
            localized: "Tap to scan",
            bundle: .toolkitModule,
            comment: "A label for a button to select a code identified with the barcode scanner."
        )
    }
}
