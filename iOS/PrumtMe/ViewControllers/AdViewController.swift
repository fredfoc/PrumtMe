//
//  AdViewController.swift
//  PrumtMe
//
//  Created by fauquette fred on 28/02/17.
//  Copyright © 2017 fauquette fred. All rights reserved.
//

import UIKit
import GoogleMobileAds

protocol AdViewControllerDelegate: class {
    func adViewDidReceiveAd()
}


class AdViewController: UIViewController {
    
    weak var adViewControllerDelegate: AdViewControllerDelegate?
    
    lazy var adBannerView: GADBannerView = {
        let adBannerView = GADBannerView(adSize: kGADAdSizeBanner)
        adBannerView.adUnitID = "ca-app-pub-6909125969763193/4462113060"
        adBannerView.delegate = self
        adBannerView.rootViewController = self
        
        return adBannerView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        adBannerView.load(GADRequest())
    }
}

extension AdViewController: GADBannerViewDelegate {
    
    func adViewDidReceiveAd(_ bannerView: GADBannerView) {
        self.view.addSubview(bannerView)
        adViewControllerDelegate?.adViewDidReceiveAd()
    }
    
    func adView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: GADRequestError) {
        print(error)
    }
}
