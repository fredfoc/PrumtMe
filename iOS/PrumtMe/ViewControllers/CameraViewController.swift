//
//  CameraViewController.swift
//  PrumtMe
//
//  Created by fauquette fred on 28/02/17.
//  Copyright © 2017 fauquette fred. All rights reserved.
//

import UIKit
import AVFoundation
import MBProgressHUD

let prumtMeErrorTitle = "PrumtMe OOPS..."
let prumtNodeName = "prumt"
let bottomConstantButton: CGFloat = 16
let outConstantButton: CGFloat = -100
let bottomConstantPrumtButton: CGFloat = 60


class CameraViewController: UIViewController {
    
    fileprivate var session: AVCaptureSession?
    fileprivate var stillImageOutput: AVCapturePhotoOutput?
    fileprivate var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    fileprivate var videoDataOutput: AVCaptureVideoDataOutput?
    fileprivate var videoDataOutputQueue: DispatchQueue?
    fileprivate var isFrozen = false
    fileprivate var isUsingBackCamera = true
    
    fileprivate var prumtResults = [Int]()
    
    fileprivate var prumtResult: Int {
        return prumtResults.isEmpty ? 0 : prumtResults.reduce(0, +) / prumtResults.count
    }
    
    @IBOutlet fileprivate weak var previewView: UIView!
    @IBOutlet fileprivate weak var previewImage: UIImageView!
    @IBOutlet fileprivate weak var prumtValueLabel: UILabel!
    @IBOutlet fileprivate weak var screenedView: UIView!
    
    
    
    @IBOutlet weak var bottomInfoConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate weak var adViewTopConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate weak var bottomSwitchCameraConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate weak var bottomShareConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomPrumtMeView: NSLayoutConstraint!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setAVSession()
        adViewTopConstraint.constant = outConstantButton
        bottomSwitchCameraConstraint.constant = bottomConstantButton
        bottomInfoConstraint.constant = bottomConstantButton
        bottomShareConstraint.constant = outConstantButton
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "adView", let adViewController = segue.destination as? AdViewController {
            adViewController.adViewControllerDelegate = self
        }
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
                DispatchQueue.main.async(){
                    let alert = UIAlertController(title: prumtMeErrorTitle , message:  "We encountered a problem with the camera. Sorry, please relaunch the app completely...", preferredStyle: .alert)
                    let action = UIAlertAction(title: "Ok", style: .cancel, handler: nil)
                    alert.addAction(action)
                    self.present(alert, animated: true, completion: nil)
                }
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
    
    @IBAction fileprivate func shareResult(_ sender: Any) {
        MBProgressHUD.showAdded(to: view, animated: false)
        makeScreenShot {[weak self] (image) in
            if let image = image {
                let shareText = String(format: "Oops, %d%% in common with him... #PrumtMe : a sort of Machine Learning experiment... http://prumt.me", self?.prumtResult ?? 0)
                let title = "PrumtMe : Machine Learning experiment..."
                let vc = UIActivityViewController(activityItems: [shareText, image], applicationActivities: [])
                vc.setValue(title, forKeyPath: "Subject")
                DispatchQueue.main.async(){
                    if let view = self?.view {
                        MBProgressHUD.hide(for: view, animated: true)
                    }
                    self?.present(vc, animated: true)
                }
            }
        }
        
    }
    
    private func makeScreenShot(completion:@escaping (UIImage?)->()) {
        DispatchQueue.global(qos: .default).async {[unowned self] (_) in
            UIGraphicsBeginImageContext(self.screenedView.frame.size)
            self.screenedView.layer.render(in: UIGraphicsGetCurrentContext()!)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            completion(image)
        }
    }
    

    @IBAction fileprivate func toggleVideo() {
        if !isFrozen {
            previewImage.isHidden = false
            previewImage.image = nil
            MBProgressHUD.showAdded(to: view, animated: false)
            nbrAttemptForPhoto = 0
            capturePhoto()
        } else {
            previewImage.isHidden = true
            if let session = session, session.canAddOutput(videoDataOutput) {
                session.addOutput(videoDataOutput)
            }
            session?.startRunning()
        }
        isFrozen = !isFrozen
        switchButtons()
    }
    
    fileprivate func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        let previewFormat = [
            kCVPixelBufferPixelFormatTypeKey as String: kCMPixelFormat_32BGRA
        ]
        settings.previewPhotoFormat = previewFormat
        stillImageOutput?.capturePhoto(with: settings, delegate: self)
    }
    
    fileprivate func switchButtons() {
        let deadlineTime = DispatchTime.now() + .milliseconds(400)
        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
            UIView.animate(withDuration: 0.6,
                           delay: 0,
                           options: .curveEaseOut,
                           animations: {
                            self.bottomShareConstraint.constant = self.isFrozen ? bottomConstantButton : outConstantButton
                            self.bottomSwitchCameraConstraint.constant = self.isFrozen ? outConstantButton : bottomConstantButton
                            self.bottomInfoConstraint.constant = self.isFrozen ? outConstantButton : bottomConstantButton
                            self.bottomPrumtMeView.constant = self.isFrozen ? 55 : 36
                            self.view.layoutIfNeeded()
            })
        }
        
    }
    
    fileprivate func updateResultLabel() {
        prumtValueLabel.text = String(format: "%d%%", prumtResult)
    }
    
    

    @IBAction fileprivate func switchCamera(_ sender: Any) {
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
                DispatchQueue.main.async(){
                    MBProgressHUD.hide(for: self.view, animated: true)
                    let alert = UIAlertController(title: prumtMeErrorTitle , message:  "We encountered a problem when switching camera. Sorry, please retry...", preferredStyle: .alert)
                    let action = UIAlertAction(title: "Ok", style: .cancel, handler: nil)
                    alert.addAction(action)
                    self.present(alert, animated: true, completion: nil)
                }
            } else {
                session.addInput(newVideoInput)
                isUsingBackCamera = !isUsingBackCamera
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


fileprivate var nbrAttemptForPhoto = 0
extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func capture(_ captureOutput: AVCapturePhotoOutput,
                 didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?,
                 previewPhotoSampleBuffer: CMSampleBuffer?,
                 resolvedSettings: AVCaptureResolvedPhotoSettings,
                 bracketSettings: AVCaptureBracketedStillImageSettings?,
                 error: Error?) {
        var isInError = false
        if error != nil {
            isInError = true
        }
        
        if  let sampleBuffer = photoSampleBuffer,
            let previewBuffer = previewPhotoSampleBuffer,
            let dataImage =  AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer:  sampleBuffer, previewPhotoSampleBuffer: previewBuffer),
            !isInError
            {
            print(UIImage(data: dataImage)?.size as Any)
            
            let dataProvider = CGDataProvider(data: dataImage as CFData)
            let cgImageRef: CGImage! = CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
                let image = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: isUsingBackCamera ? .right : .leftMirrored)
                DispatchQueue.main.async(){
                    self.previewImage.image = image
                    MBProgressHUD.hide(for: self.view, animated: true)
                    self.session?.stopRunning()
                }
            
            
        } else {
            isInError = true
        }
        
        if isInError {
            nbrAttemptForPhoto += 1
            if nbrAttemptForPhoto < 5 {
                capturePhoto()
            } else {
                DispatchQueue.main.async(){
                    MBProgressHUD.hide(for: self.view, animated: true)
                    let alert = UIAlertController(title: prumtMeErrorTitle , message:  "We encountered a problem during the screenshot. Sorry, please retry...", preferredStyle: .alert)
                    let action = UIAlertAction(title: "Ok", style: .cancel, handler: nil)
                    alert.addAction(action)
                    self.present(alert, animated: true, completion: nil)
                    self.toggleVideo()
                }
            }
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
            tensorFlowManager.runCNN(onFrame: pixelBuffer, completion: {[weak self] (results, error) in
                if let isFrozen = self?.isFrozen, !isFrozen {
                    if let tmpResult = results?[prumtNodeName] as? Float {
                        self?.addToPrumtResult(newResult: Int(tmpResult * 100))
                    } else {
                        self?.addToPrumtResult(newResult: 0)
                    }
                }
            })
        }
    }
    
    private func addToPrumtResult(newResult: Int) {
        if prumtResults.count > 9 {
            prumtResults.removeFirst()
        }
        prumtResults.append(newResult)
        DispatchQueue.main.async {
            self.updateResultLabel()
        }
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!,
                       didDrop sampleBuffer: CMSampleBuffer!,
                       from connection: AVCaptureConnection!) {
    }
}

extension CameraViewController: AdViewControllerDelegate {
    func adViewDidReceiveAd() {
        displayAd()
    }
    
    fileprivate func displayAd(delay: Int = 6) {
        UIView.animate(withDuration: 0.6,
                       delay: 0,
                       options: .curveEaseOut,
                       animations: {
                        self.adViewTopConstraint.constant = 60
                        self.view.layoutIfNeeded()
        }) {[weak self] (completed) in
            let deadlineTime = DispatchTime.now() + .seconds(delay)
            if let session = self?.session, session.canAddOutput(self?.videoDataOutput) {
                session.addOutput(self?.videoDataOutput)
                session.startRunning()
            }
            
            DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
                UIView.animate(withDuration: 0.4,
                               animations: {
                                self?.adViewTopConstraint.constant = -200
                                self?.view.layoutIfNeeded()
                })
            }
        }
    }
}
