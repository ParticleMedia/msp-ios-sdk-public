import Foundation
import UIKit

public class NativeAdView: UIView {
    public weak var nativeAd: NativeAd?
    public weak var rootViewController: UIViewController?
    public var nativeAdViewBinder: NativeAdViewBinder?
    public var nativeAdContainer: MSPNativeAdContainer?
    
    private var titleLabel: UILabel?
    private var bodyLabel: UILabel?
    private var advertiserLabel: UILabel?
    private var callToActionButton: UIButton?
    private var optionView: UIView?
    private var mediaView: UIView?
    private var icon: UIImageView?
    
    public var mediaController: MediaController?
    
    public init(nativeAd: NativeAd, nativeAdViewBinder: NativeAdViewBinder) {
        self.nativeAd = nativeAd
        self.nativeAdViewBinder = nativeAdViewBinder
        
        self.titleLabel = nativeAdViewBinder.titleLabel
        self.bodyLabel = nativeAdViewBinder.bodyLabel
        self.advertiserLabel = nativeAdViewBinder.advertiserLabel
        self.callToActionButton = nativeAdViewBinder.callToActionButton
        
        self.titleLabel?.text = nativeAd.title
        self.bodyLabel?.text = nativeAd.body
        self.advertiserLabel?.text = nativeAd.advertiser
        self.callToActionButton?.setTitle(nativeAd.callToAction, for: .normal)
        
        self.mediaView = nativeAdViewBinder.mediaView
        self.mediaController = nativeAd.mediaController
        
        super.init(frame: .zero)
        
        nativeAd.adNetworkAdapter?.prepareViewForInteraction(nativeAd: nativeAd, nativeAdView: self)
    }
    
    public init(nativeAd: NativeAd, nativeAdContainer: MSPNativeAdContainer) {
        self.nativeAd = nativeAd
        self.nativeAdContainer = nativeAdContainer
        
        self.titleLabel = nativeAdContainer.getTitle()
        self.bodyLabel = nativeAdContainer.getbody()
        self.advertiserLabel = nativeAdContainer.getAdvertiser()
        self.callToActionButton = nativeAdContainer.getCallToAction()
        self.icon = nativeAdContainer.getIcon()
        
        self.titleLabel?.text = nativeAd.title
        self.bodyLabel?.text = nativeAd.body
        self.advertiserLabel?.text = nativeAd.advertiser
        self.callToActionButton?.setTitle(nativeAd.callToAction, for: .normal)
        
        self.mediaView = nativeAdContainer.getMedia()
        self.mediaController = nativeAd.mediaController
        
        super.init(frame: .zero)
        
        nativeAd.adNetworkAdapter?.prepareViewForInteraction(nativeAd: nativeAd, nativeAdView: self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

open class NativeAdViewBinder {
    
    public var titleLabel: UILabel?
    public var bodyLabel: UILabel?
    public var advertiserLabel: UILabel?
    public var callToActionButton: UIButton?
    public var optionView: UIView?
    public var mediaView: UIView?
    
    public init(nativeAd: NativeAd) {
        titleLabel = UILabel()
        bodyLabel = UILabel()
        advertiserLabel = UILabel()
        callToActionButton = UIButton(type: .custom)
        mediaView = (nativeAd.mediaView as? UIView)
    }
    
    open func setUpViews(parentView: UIView) {
        
    }
}
