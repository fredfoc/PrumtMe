//
//  CameraViewController.swift
//  PrumtMe
//
//  Created by fauquette fred on 28/02/17.
//  Copyright © 2017 fauquette fred. All rights reserved.
//

import UIKit
import AVFoundation


class CameraViewController: UIViewController {
    
    fileprivate var session: AVCaptureSession?
    fileprivate var stillImageOutput: AVCapturePhotoOutput?
    fileprivate var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    fileprivate var videoDataOutput: AVCaptureVideoDataOutput?
    fileprivate var videoDataOutputQueue: DispatchQueue?
    
    @IBOutlet fileprivate weak var freezeButton: UIButton!
    @IBOutlet fileprivate weak var infoButton: UIButton!
    @IBOutlet fileprivate weak var switchCameraButton: UIButton!
    @IBOutlet fileprivate weak var previewView: UIView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setAVSession()
    }
    
    private func setAVSession() {
        session = AVCaptureSession()
        if let session = session {
            session.sessionPreset = AVCaptureSessionPreset640x480
            let backCamera = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
            var error: NSError?
            var input: AVCaptureDeviceInput!
            do {
                input = try AVCaptureDeviceInput(device: backCamera)
            } catch let error1 as NSError {
                error = error1
                input = nil
                print(error!.localizedDescription)
            }
            if error == nil && session.canAddInput(input) {
                session.addInput(input)
                
                stillImageOutput = AVCapturePhotoOutput()
                if (session.canAddOutput(stillImageOutput)) {
                    session.addOutput(stillImageOutput)
                    
                }
                
                videoDataOutput = AVCaptureVideoDataOutput()
                let rgbOutputSettings = [String(kCVPixelBufferPixelFormatTypeKey) : kCMPixelFormat_32BGRA]
                videoDataOutput?.videoSettings = rgbOutputSettings
                videoDataOutput?.alwaysDiscardsLateVideoFrames = true
                videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
                videoDataOutput?.setSampleBufferDelegate(self, queue: videoDataOutputQueue!)
                if session.canAddOutput(videoDataOutput) {
                    session.addOutput(videoDataOutput)
                    videoDataOutput?.connection(withMediaType: AVMediaTypeVideo).isEnabled = true
                    videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
                    videoPreviewLayer!.videoGravity = AVLayerVideoGravityResizeAspectFill
                    videoPreviewLayer!.connection?.videoOrientation = .portrait
                    videoPreviewLayer!.frame = previewView.bounds
                    previewView.layer.addSublayer(videoPreviewLayer!)
                    session.startRunning()
                }
                
                
            }
        }
    }
    
    
    
    
    
    
    
    @IBAction fileprivate func freezeImage(_ sender: Any) {
        let settings = AVCapturePhotoSettings()
        let previewFormat = [
            kCVPixelBufferPixelFormatTypeKey as String: kCMPixelFormat_32BGRA
        ]
        settings.previewPhotoFormat = previewFormat
        stillImageOutput?.capturePhoto(with: settings, delegate: self)
    }

    @IBAction func switchCamera(_ sender: Any) {
        if let session = session {
            //Indicate that some changes will be made to the session
            session.beginConfiguration()
            
            //Remove existing input
            guard let currentCameraInput: AVCaptureInput = session.inputs.first as? AVCaptureInput else {
                return
            }
            
            session.removeInput(currentCameraInput)
            
            //Get new input
            var newCamera: AVCaptureDevice! = nil
            if let input = currentCameraInput as? AVCaptureDeviceInput {
                if (input.device.position == .back) {
                    newCamera = cameraWithPosition(position: .front)
                } else {
                    newCamera = cameraWithPosition(position: .back)
                }
            }
            
            //Add input to session
            var err: NSError?
            var newVideoInput: AVCaptureDeviceInput!
            do {
                newVideoInput = try AVCaptureDeviceInput(device: newCamera)
            } catch let err1 as NSError {
                err = err1
                newVideoInput = nil
            }
            
            if newVideoInput == nil || err != nil {
                print("Error creating capture device input: \(err?.localizedDescription)")
            } else {
                session.addInput(newVideoInput)
            }
            
            //Commit all the configuration changes at once
            session.commitConfiguration()
        }
    }
    
    // Find a camera with the specified AVCaptureDevicePosition, returning nil if one is not found
    private func cameraWithPosition(position: AVCaptureDevicePosition) -> AVCaptureDevice? {
        if let discoverySession = AVCaptureDeviceDiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaTypeVideo, position: .unspecified) {
            for device in discoverySession.devices {
                if device.position == position {
                    return device
                }
            }
        }
        
        return nil
    }
    
    @IBAction fileprivate func backToCamera(segue:UIStoryboardSegue) {}
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func capture(_ captureOutput: AVCapturePhotoOutput,
                 didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?,
                 previewPhotoSampleBuffer: CMSampleBuffer?,
                 resolvedSettings: AVCaptureResolvedPhotoSettings,
                 bracketSettings: AVCaptureBracketedStillImageSettings?,
                 error: Error?) {
        
        if let error = error {
            print("error occure : \(error.localizedDescription)")
        }
        
        if  let sampleBuffer = photoSampleBuffer,
            let previewBuffer = previewPhotoSampleBuffer,
            let dataImage =  AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer:  sampleBuffer, previewPhotoSampleBuffer: previewBuffer) {
            print(UIImage(data: dataImage)?.size as Any)
            
            let dataProvider = CGDataProvider(data: dataImage as CFData)
            let cgImageRef: CGImage! = CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
            let image = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: UIImageOrientation.right)
            
            
            
        } else {
            print("some error here")
        }
    }
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ captureOutput: AVCaptureOutput!,
                       didOutputSampleBuffer sampleBuffer: CMSampleBuffer!,
                       from connection: AVCaptureConnection!) {
        
        if let tensorFlowManager = TensorFlowManager.shared(),
            tensorFlowManager.modelIsLoaded,
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        {
            tensorFlowManager.runCNN(onFrame: pixelBuffer, completion: { (results, error) in
                print(results ?? "oups")
            })
        }
    }
}
