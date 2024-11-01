//
//  DemoNativeAdContainer.swift
//  MSPDemoApp
//
//  Created by Huanzhi Zhang on 11/1/24.
//

import Foundation
import MSPiOSCore
import UIKit


public class DemoNativeAdContainer: UIView, MSPNativeAdContainer {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = UIColor(light: UIColor(hex: "000000")!.withAlphaComponent(0.9), dark: UIColor(hex: "FFFFFF")!.withAlphaComponent(0.85))
        
        return label
    }()
    
    let bodyLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor(hex:"9B9B9B")
        label.numberOfLines = 2
        label.textAlignment = .natural
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()
    
    let advertiserLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.numberOfLines = 1
        label.textColor = UIColor(light: UIColor(hex: "000000")!.withAlphaComponent(0.3), dark: UIColor(hex: "FFFFFF")!.withAlphaComponent(0.6))
        
        return label
    }()
    
    lazy var ctaButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.semanticContentAttribute = .forceRightToLeft
        button.contentHorizontalAlignment = .right
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: -10, bottom: 0, right: 10)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.setTitleColor(UIColor(hex: "3498FA"), for: .normal)
        button.setImage(UIImage(named: "article_ad_cta"), for: .normal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        return button
    }()
    
    
    
    private let mediaView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }()
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setUpViews() {
        let subViews = [titleLabel, bodyLabel, advertiserLabel, ctaButton, mediaView]
        for view in subViews {
            self.addSubview(view)
        }
        self.titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        
        let titleLabelTrailingConstraint: NSLayoutConstraint
        let bodyLabelTrailingConstraint: NSLayoutConstraint
        
        
        titleLabelTrailingConstraint = titleLabel.trailingAnchor.constraint(
                equalTo: self.trailingAnchor,
                constant: -Constants.paddingSmall)
        bodyLabelTrailingConstraint = bodyLabel.trailingAnchor.constraint(
                equalTo: self.trailingAnchor,
                constant: -Constants.paddingSmall)

        
        mediaView.contentMode = .scaleAspectFill
        mediaView.clipsToBounds = true
        //if let mediaContent = nativeAdView.nativeAd?.mediaContent {
        //    setupMediaViewConstraints(with: mediaContent)
        //}
        NSLayoutConstraint.activate([
            mediaView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            mediaView.topAnchor.constraint(equalTo: self.topAnchor),
            mediaView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            mediaView.widthAnchor.constraint(equalTo: self.widthAnchor),
            mediaView.heightAnchor.constraint(
                equalTo: mediaView.widthAnchor,
                multiplier: Double(1.0 / AdsMediaConstants.defaultAspectRatio))
        ])
        mediaView.isHidden = false
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(
                equalTo: self.leadingAnchor,
                constant: Constants.paddingSmall),
            titleLabel.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: Constants.paddingSmall),
            titleLabelTrailingConstraint,
            
            bodyLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: Constants.paddingSmall),
            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            bodyLabelTrailingConstraint,
            
            advertiserLabel.leadingAnchor.constraint(
                equalTo: self.leadingAnchor,
                constant: Constants.paddingSmall),
            advertiserLabel.centerYAnchor.constraint(equalTo: ctaButton.centerYAnchor),
            advertiserLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: ctaButton.leadingAnchor,
                constant: -16),
            
            ctaButton.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 4),
            ctaButton.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -8),
            ctaButton.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -18),
            ctaButton.heightAnchor.constraint(equalToConstant: Constants.ctaButtonHeight),
        ])
    }
    
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
    
    
    
    public func getTitle() -> UILabel? {
        return titleLabel
    }
    
    public func getbody() -> UILabel? {
        return bodyLabel
    }
    
    public func getAdvertiser() -> UILabel? {
        return advertiserLabel
    }
    
    public func getCallToAction() -> UIButton? {
        return ctaButton
    }
    
    public func getMedia() -> UIView? {
        return mediaView
    }
    
    
}
