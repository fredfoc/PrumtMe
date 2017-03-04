//
//  InfoViewController.swift
//  PrumtMe
//
//  Created by fauquette fred on 3/03/17.
//  Copyright © 2017 fauquette fred. All rights reserved.
//

import UIKit

class InfoViewController: UIViewController {
    @IBAction func prumtMeWebsite(_ sender: Any) {
        if let url = URL(string: "http://www.prumt.me"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    @IBAction func sharePrumtMe(_ sender: Any) {
        let shareText = "#PrumtMe : a (not really) smart Machine Learning experiment... http://prumt.me"
        let title = "PrumtMe : Machine Learning experiment..."
        var activityItems: [Any] = [shareText]
        if let image = UIImage(named: "iTunesArtwork") {
            activityItems.append(image)
        }
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: [])
        vc.setValue(title, forKeyPath: "Subject")
        present(vc, animated: true)
    }
}
