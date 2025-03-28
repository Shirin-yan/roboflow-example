//
//  ContentView.swift
//  roboflow
//
//  Created by  Shirin-Yan on 19.03.2025.
//

import SwiftUI
import AVKit
import Roboflow

struct ContentView: View {
    var body: some View {
        CameraView()
    }
}

struct CameraView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var captureSession = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer!
    let overlayView = UIView()
    var date: Double = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupOverlayView()
    }

    func setupCamera() {
        captureSession.sessionPreset = .high
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        captureSession.addInput(input)

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(previewLayer)

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(videoOutput)
        
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }

    func setupOverlayView() {
        overlayView.frame = view.bounds
        overlayView.backgroundColor = UIColor.clear
        view.addSubview(overlayView)
    }

    func getVideoPreviewBounds(imgSize: CGSize) -> CGRect? {
        guard let previewLayer = previewLayer else { return nil }

        let previewBounds = previewLayer.bounds
        let videoSize = imgSize

        let scaleX = previewBounds.width / videoSize.width
        let scaleY = previewBounds.height / videoSize.height
        let scale = min(scaleX, scaleY)

        let videoWidth = videoSize.width * scale
        let videoHeight = videoSize.height * scale

        let offsetX = (previewBounds.width - videoWidth) / 2
        let offsetY = (previewBounds.height - videoHeight) / 2

        return CGRect(x: offsetX, y: offsetY, width: videoWidth, height: videoHeight)
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let uiImage = UIImage(ciImage: ciImage)
        let img = UIImage(ciImage: ciImage, scale: uiImage.scale, orientation: .right)
        sendImageToRoboflow(image: img)
    }
    
    func drawBoundingBoxes(_ objects: [DetectedObject]) {
        overlayView.subviews.forEach { $0.removeFromSuperview() }
        guard let imgSize = objects.first?.imgSize else { return }
        guard let videoBounds = getVideoPreviewBounds(imgSize: CGSize(width: imgSize.width, height: imgSize.height)) else { return }
        objects.forEach { obj in
            let rect = scaleToFit(prediction: obj.detectedRect, originalSize: CGSize(width: obj.imgSize?.width ?? 0, height: obj.imgSize?.height ?? 0), displayFrame: videoBounds)
            let boundingBox = UIView(frame: rect)
            boundingBox.layer.borderColor = UIColor.red.cgColor
            boundingBox.layer.borderWidth = 2
            overlayView.addSubview(boundingBox)
            
            print(videoBounds)
            print(rect)
        }
    }

    func scaleToFit(prediction: CGRect, originalSize: CGSize, displayFrame: CGRect) -> CGRect {
        let scaleX = displayFrame.width / originalSize.width
        let scaleY = displayFrame.height / originalSize.height
        let scale = min(scaleX, scaleY) // Maintain aspect ratio

        // Calculate new size while maintaining aspect ratio
        let scaledWidth = originalSize.width * scale
        let scaledHeight = originalSize.height * scale

        // Find the offset for correct centering
        let offsetX = displayFrame.origin.x + (displayFrame.width - scaledWidth) / 2
        let offsetY = displayFrame.origin.y + (displayFrame.height - scaledHeight) / 2

        // Map prediction box to display space
        let newX = offsetX + prediction.origin.x * scale
        let newY = offsetY + prediction.origin.y * scale
        let newWidth = prediction.width * scale
        let newHeight = prediction.height * scale

        return CGRect(x: newX, y: newY, width: newWidth, height: newHeight)
    }

    func sendImageToRoboflow(image: UIImage) {
        if date+1 >= Date().timeIntervalSince1970 { return }
        date = Date().timeIntervalSince1970
        let imageData = image.jpegData(compressionQuality: 1)
        let fileContent = imageData?.base64EncodedString()
        let postData = fileContent!.data(using: .utf8)
        
        // Initialize Inference Server Request with API KEY, Model, and Model Version
        var request = URLRequest(url: URL(string: "https://detect.roboflow.com/two-arytenoids-samples/4?api_key=E7Q1AyuEh1RmcCCMEgGW&name=YOUR_IMAGE.jpg")!,timeoutInterval: Double.infinity)
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = postData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if data == nil { return }
            print(String(data: data!, encoding: .utf8) as Any)
            do {
                let response = try JSONDecoder().decode(RoboflowResponse.self, from: data!)
                
                if let imageData,
                   let directory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) as NSURL {
                    do {
                        try imageData.write(to: directory.appendingPathComponent("\(response.inference_id ?? "1").jpeg")!)
                    } catch {
                        print(error.localizedDescription)
                    }
                }
                
                let detectedObjects = response.predictions.compactMap { prediction in
                    prediction.confidence < 0.7 ? nil : DetectedObject(
                            imgSize: response.image,
                            detectedRect: CGRect(x: prediction.x-prediction.width/2, y: prediction.y-prediction.height/2, width: prediction.width, height: prediction.height)
                        )
                    }
                    
                    DispatchQueue.main.async {
                        self.drawBoundingBoxes(detectedObjects)
                    }
            } catch {
                debugPrint(error)
            }
        }.resume()
    }
}
