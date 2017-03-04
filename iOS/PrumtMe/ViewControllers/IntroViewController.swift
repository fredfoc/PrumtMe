//
//  IntroViewController.swift
//  PrumtMe
//
//  Created by fauquette fred on 1/03/17.
//  Copyright © 2017 fauquette fred. All rights reserved.
//

import UIKit
import MBProgressHUD
import AVFoundation

class IntroViewController: UIViewController {
    
    @IBOutlet weak var descriptionView: UIView!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var bottomStartConstraint: NSLayoutConstraint!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        descriptionView.alpha = 0
        bottomStartConstraint.constant = (view.frame.height - startButton.frame.width) / 2
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.6,
                       delay: 0,
                       options: .curveEaseInOut,
                       animations: {
            self.bottomStartConstraint.constant = bottomConstantPrumtButton
            self.view.layoutIfNeeded()
        })
        
        let deadlineTime = DispatchTime.now() + .milliseconds(700)
        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
            UIView.animate(withDuration: 0.3) {
                self.descriptionView.alpha = 1
                self.view.layoutIfNeeded()
            }
        }
    }
    
    @IBAction func startCamera(_ sender: Any) {
        askPermission()
    }
    
    private func startCamera() {
        MBProgressHUD.showAdded(to: view, animated: true)
        TensorFlowManager.shared()?.initializeCNN(completion: { (error) in
            guard error == nil else {
                if let error = error {
                    print(error)
                }
                return
            }
            DispatchQueue.main.async {
                MBProgressHUD.hide(for: self.view, animated: true)
                self.performSegue(withIdentifier: "startCamera", sender: nil)
            }
            
        })
    }
    private func displayAlertForCameraPermission() {
        let alert = UIAlertController(title: "Oops...:-)" , message:  "Camera is the main feature of this application. This app is not really smart but without camera permission it's completely useless... Do you want to go to settings to change permission ?", preferredStyle: .alert)
        let goToSettingsAction = UIAlertAction(title: "Yes", style: .default, handler: { (_) in
            guard let settingsUrl = URL(string: UIApplicationOpenSettingsURLString) else {
                return
            }
            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl)
            }
        })
        alert.addAction(goToSettingsAction)
        let action = UIAlertAction(title: "Noop", style: .cancel, handler: nil)
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }
    
    private func askPermission() {
        print("here")
        let cameraPermissionStatus =  AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        
        switch cameraPermissionStatus {
        case .authorized:
            startCamera()
        case .denied:
            displayAlertForCameraPermission()
        case .restricted:
            displayAlertForCameraPermission()
        default:
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: {[weak self] (granted :Bool) -> Void in
                if granted == true {
                    DispatchQueue.main.async(){
                        self?.startCamera()
                    }
                } else {
                    DispatchQueue.main.async(){
                        self?.displayAlertForCameraPermission()
                    } 
                }
            });
        }
    }
    
}
