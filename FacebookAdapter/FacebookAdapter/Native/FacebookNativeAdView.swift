

import Foundation
import FBAudienceNetwork

open class FacebookNativeAdView: UIView {
    
    public var titleLabel: UILabel?
    public var bodyLabel: UILabel?
    public var advertiserLabel: UILabel?
    public var callToActionButton: UIButton?
    
    public let fbMediaView: FBMediaView = {
        let view = FBMediaView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    public let fbAdOptionsView: FBAdOptionsView = {
        let view = FBAdOptionsView(frame: .zero)
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    open func bindView(nativeAd: FBNativeAd) {
        titleLabel = UILabel()
        bodyLabel = UILabel()
        advertiserLabel = UILabel()
        callToActionButton = UIButton(type: .custom)
    }
    
    open func setUpView(nativeAd: FBNativeAd) {
        titleLabel?.text = nativeAd.headline
        bodyLabel?.text = nativeAd.bodyText
        advertiserLabel?.text = nativeAd.advertiserName
        callToActionButton?.setTitle(nativeAd.callToAction, for: .normal)
        
        nativeAd.unregisterView()

        let clickableViews = [
            self.fbMediaView,
            self.advertiserLabel,
            self.bodyLabel,
            self.callToActionButton,
            self.titleLabel,
        ]
        nativeAd.registerView(forInteraction: self,
                              mediaView: self.fbMediaView,
                              iconImageView: nil,
                              viewController: nil,
                              clickableViews: clickableViews.compactMap { $0 })
        self.fbAdOptionsView.nativeAd = nativeAd
    }
}
