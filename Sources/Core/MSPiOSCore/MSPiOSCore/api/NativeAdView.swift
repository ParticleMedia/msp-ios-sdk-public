import Foundation
import UIKit

public class NativeAdView: UIView {
    public weak var nativeAd: NativeAd?
    public weak var rootViewController: UIViewController?
    public var nativeAdContainer: MSPNativeAdContainer?

    private var titleLabel: UILabel?
    private var bodyLabel: UILabel?
    private var advertiserLabel: UILabel?
    private var callToActionButton: UIButton?
    private var optionView: UIView?
    private var customClickableViews: [UIView]?
    private var displayContext: [MSPNativeElement: MSPNativeDisplayContext]?
    private var mediaViewContainerView: UIView?
    private var icon: UIImageView?

    public init(nativeAd: NativeAd, nativeAdContainer: MSPNativeAdContainer) {
        self.nativeAd = nativeAd
        self.nativeAdContainer = nativeAdContainer

        super.init(frame: .zero)

        // TODO: lsy, 最好把所有的渲染逻辑都放进各个 adapter 里面去，这里的 nativeview 也不需要去持有 titleLabel 这些
        self.titleLabel = nativeAdContainer.getTitle()
        self.bodyLabel = nativeAdContainer.getbody()
        self.advertiserLabel = nativeAdContainer.getAdvertiser()
        self.callToActionButton = nativeAdContainer.getCallToAction()
        self.icon = nativeAdContainer.getIcon()
        self.customClickableViews = nativeAdContainer.getCustomClickableViews()
        self.displayContext = nativeAdContainer.getDisplayContext()
        self.mediaViewContainerView = nativeAdContainer.getMedia()

        setupElements(nativeAd: nativeAd)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupElements(nativeAd: NativeAd) {
        if let displayContext,
            let titleDisplayContext = displayContext[.title] as? MSPNativeLabelDisplayContext
        {
            let attributedString = NSAttributedString(
                string: nativeAd.title, attributes: titleDisplayContext.attributes)
            titleLabel?.attributedText = attributedString
        } else {
            titleLabel?.text = nativeAd.title
        }

        if let displayContext,
            let bodyDisplayContext = displayContext[.body] as? MSPNativeLabelDisplayContext
        {
            let attributedString = NSAttributedString(string: nativeAd.body, attributes: bodyDisplayContext.attributes)
            bodyLabel?.attributedText = attributedString
        } else {
            bodyLabel?.text = nativeAd.body
        }

        if let displayContext,
            let advertiserDisplayContext = displayContext[.advertiser] as? MSPNativeLabelDisplayContext
        {
            let attributedString = NSAttributedString(
                string: nativeAd.advertiser, attributes: advertiserDisplayContext.attributes)
            advertiserLabel?.attributedText = attributedString
        } else {
            advertiserLabel?.text = nativeAd.advertiser
        }

        callToActionButton?.setTitle(nativeAd.callToAction, for: .normal)
        nativeAd.adNetworkAdapter?.prepareViewForInteraction(nativeAd: nativeAd, nativeAdView: self)
    }
}
