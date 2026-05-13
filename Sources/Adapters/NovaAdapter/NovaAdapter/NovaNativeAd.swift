// import shared
import Foundation
import MSPiOSCore
import NovaCore
import StoreKit
import UIKit

public class NovaNativeAd: NativeAd, NativeAdSKOverlayControllable {
    // MARK: Public

    override public var mediaContainer: (any AdMediaContainer)? {
        mediaContainerAdapter
    }

    public var isSKOverlayShowing: Bool {
        skOverlayController?.isShowing == true
    }

    public var canAutoShowSKOverlayOnVideoPlayback: Bool {
        nativeAdItem?.layoutStyle == .skOverlay && nativeAdItem?.mediaContent.mediaType == .video
    }

    public private(set) var priceInDollar: Double?

    var nativeAdItem: NovaNativeAdItem? {
        didSet {
            if let mediaContent = nativeAdItem?.mediaContent {
                mediaContainerAdapter = NovaAdMediaContainerAdapter(mediaContent: mediaContent)
            }

            adInfo[MSPConstants.AD_INFO_NOVA_AD_ID] = nativeAdItem?.novaAdReportContext.adId
            adInfo[MSPConstants.AD_INFO_NOVA_AD_SET_ID] = nativeAdItem?.novaAdReportContext.adSetId
            adInfo[MSPConstants.AD_INFO_NOVA_AD_REQUEST_ID] = nativeAdItem?.novaAdReportContext.adRequestId
            adInfo[MSPConstants.AD_INFO_NOVA_AD_ENCRYPTED_TOKEN] = nativeAdItem?.novaAdReportContext.encryptedToken
            adInfo[MSPConstants.AD_INFO_NOVA_HIGH_VALUE] = nativeAdItem?.highValue
            skOverlayController = nil
        }
    }

    override public func isValid() -> Bool {
        nativeAdItem != nil
    }

    func setPriceInDollar(_ priceInDollar: Double?) {
        self.priceInDollar = priceInDollar
    }

    public func showSKOverlayIfPossible(
        scene: UIWindowScene? = nil,
        position: SKOverlay.Position = .bottomRaised,
        userDismissible: Bool,
        overlayDelegate: (any SKOverlayDelegate)? = nil
    ) {
        guard let appStoreId = nativeAdItem?.skOverlayAppStoreId else {
            return
        }

        let controller = makeOrGetSKOverlayController()
        controller.setOverlayDelegate(overlayDelegate)
        controller.show(
            appStoreId: appStoreId,
            scene: scene,
            position: position,
            userDismissible: userDismissible
        )
    }

    public func dismissSKOverlay() {
        skOverlayController?.dismiss()
    }

    // MARK: Private

    private var mediaContainerAdapter: NovaAdMediaContainerAdapter?
    private var skOverlayController: NovaSKOverlayController?

    private func makeOrGetSKOverlayController() -> NovaSKOverlayController {
        if let skOverlayController {
            return skOverlayController
        }
        let encryptedToken = nativeAdItem?.novaAdReportContext.encryptedToken ?? ""
        let controller = NovaSKOverlayController(
            encryptedAdToken: encryptedToken,
            thirdPartyTrackingURL: nativeAdItem?.skOverlayTrackingURL,
            monitorAppStoreLifecycle: true
        )
        skOverlayController = controller
        return controller
    }
}
