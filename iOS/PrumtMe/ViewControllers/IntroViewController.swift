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
    
    @IBOutlet weak var descriptionTextField: UITextView!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var bottomStartConstraint: NSLayoutConstraint!
    @IBAction func startCamera(_ sender: Any) {
        askPermission()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        descriptionTextField.alpha = 0
        bottomStartConstraint.constant = (view.frame.height - startButton.frame.width) / 2
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.7) { 
            self.descriptionTextField.alpha = 1
            self.bottomStartConstraint.constant = bottomConstantPrumtButton
            self.view.layoutIfNeeded()
        }
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
    
    // This method you can use somewhere you need to know camera permission   state
    private func askPermission() {
        print("here")
        let cameraPermissionStatus =  AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        
        switch cameraPermissionStatus {
        case .authorized:
            startCamera()
        case .denied:
            let alert = UIAlertController(title: "Sorry :(" , message: "But  could you please grant permission for camera within device settings",  preferredStyle: .alert)
            let action = UIAlertAction(title: "Ok", style: .cancel,  handler: nil)
            alert.addAction(action)
            present(alert, animated: true, completion: nil)
            
        case .restricted:
            print("restricted")
        default:
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: {
                [weak self]
                (granted :Bool) -> Void in
                
                if granted == true {
                    DispatchQueue.main.async(){
                        self?.startCamera()
                    }
                }
                else {
                    DispatchQueue.main.async(){
                        let alert = UIAlertController(title: "WHY?" , message:  "Camera it is the main feature of our application", preferredStyle: .alert)
                        let action = UIAlertAction(title: "Ok", style: .cancel, handler: nil)
                        alert.addAction(action)
                        self?.present(alert, animated: true, completion: nil)  
                    } 
                }
            });
        }
    }
    
}
