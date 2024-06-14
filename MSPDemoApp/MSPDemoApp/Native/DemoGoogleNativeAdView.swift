//
//  DemoGoogleNativeAdView.swift
//  MSPDemoApp
//
//  Created by Huanzhi Zhang on 6/13/24.
//

import Foundation
import shared
import GoogleAdapter
import GoogleMobileAds

public class DemoGoogleNativeAdView: GoogleNativeAdView {
    private enum Constants {
        static let paddingSmall: Double = 12.0
        static let ctaButtonHeight: Double = 26.0
        static let adWidth: Double = UIScreen.main.bounds.width - 32.0
    }
    
    public enum AdsMediaConstants {
        public static let iPadAspectRatio: Double = 0.56
        public static let defaultAspectRatio: Double = 1200.0 / 627.0
        public static let verticalVideoDefaultAspectRatio: Double = 9.0 / 16.0
    }
    
    public override func setUpView() {
        super.setUpView()
        
        titleLabel = UILabel()
        titleLabel?.translatesAutoresizingMaskIntoConstraints = false
        titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel?.textColor = UIColor(light: UIColor(hex: "000000")!.withAlphaComponent(0.9), dark: UIColor(hex: "FFFFFF")!.withAlphaComponent(0.85))
        
        bodyLabel = UILabel()
        bodyLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        bodyLabel?.textColor = UIColor(hex:"9B9B9B")
        bodyLabel?.numberOfLines = 2
        bodyLabel?.textAlignment = .natural
        bodyLabel?.translatesAutoresizingMaskIntoConstraints = false
        
        advertiserLabel = UILabel()
        advertiserLabel?.translatesAutoresizingMaskIntoConstraints = false
        advertiserLabel?.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        advertiserLabel?.numberOfLines = 1
        advertiserLabel?.textColor = UIColor(light: UIColor(hex: "000000")!.withAlphaComponent(0.3), dark: UIColor(hex: "FFFFFF")!.withAlphaComponent(0.6))
        
        callToActionButton = UIButton(type: .custom)
        callToActionButton?.translatesAutoresizingMaskIntoConstraints = false
        callToActionButton?.semanticContentAttribute = .forceRightToLeft
        callToActionButton?.contentHorizontalAlignment = .right
        callToActionButton?.titleEdgeInsets = UIEdgeInsets(top: 0, left: -10, bottom: 0, right: 10)
        callToActionButton?.contentEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
        callToActionButton?.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        callToActionButton?.setTitleColor(UIColor(hex: "3498FA"), for: .normal)
        callToActionButton?.setImage(UIImage(named: "article_ad_cta"), for: .normal)
        callToActionButton?.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        
        self.gadMediaView.translatesAutoresizingMaskIntoConstraints = false
        //self.mediaView = mediaView
        //self.parentView = parentView
            
        let gadSubViews = [gadMediaView, titleLabel, bodyLabel, advertiserLabel, callToActionButton]
        for view in gadSubViews {
            if let view = view {
                self.nativeAdView.addSubview(view)
            }
        }
        
        self.titleLabel?.setContentCompressionResistancePriority(.required, for: .vertical)
        
        let titleLabelTrailingConstraint: NSLayoutConstraint
        let bodyLabelTrailingConstraint: NSLayoutConstraint
        
        guard let titleLabel = titleLabel,
              let bodyLabel = bodyLabel,
              let advertiserLabel = advertiserLabel,
              let callToActionButton = callToActionButton else {
            return
        }
        
        titleLabelTrailingConstraint = titleLabel.trailingAnchor.constraint(
                equalTo: nativeAdView.trailingAnchor,
                constant: -Constants.paddingSmall)
        bodyLabelTrailingConstraint = bodyLabel.trailingAnchor.constraint(
                equalTo: nativeAdView.trailingAnchor,
                constant: -Constants.paddingSmall)
        

        NSLayoutConstraint.activate([
            gadMediaView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
            gadMediaView.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
            gadMediaView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
            gadMediaView.heightAnchor.constraint(
                equalTo: gadMediaView.widthAnchor,
                multiplier: Double(1.0 / AdsMediaConstants.defaultAspectRatio))
        ])
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(
                equalTo: nativeAdView.leadingAnchor,
                constant: Constants.paddingSmall),
            titleLabel.topAnchor.constraint(equalTo: gadMediaView.bottomAnchor, constant: Constants.paddingSmall),
            titleLabelTrailingConstraint,
            
            bodyLabel.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: Constants.paddingSmall),
            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            bodyLabelTrailingConstraint,
            
            advertiserLabel.leadingAnchor.constraint(
                equalTo: nativeAdView.leadingAnchor,
                constant: Constants.paddingSmall),
            advertiserLabel.centerYAnchor.constraint(equalTo: callToActionButton.centerYAnchor),
            advertiserLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: callToActionButton.leadingAnchor,
                constant: -16),
            
            callToActionButton.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 4),
            callToActionButton.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor, constant: -8),
            callToActionButton.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -18),
            callToActionButton.heightAnchor.constraint(equalToConstant: Constants.ctaButtonHeight),
        ])
    }
}
