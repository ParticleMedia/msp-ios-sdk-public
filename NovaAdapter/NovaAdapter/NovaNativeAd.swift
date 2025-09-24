import Foundation

// import shared
import MSPiOSCore
import NovaCore

public class NovaNativeAd: NativeAd {
    // MARK: Public

    override public var mediaContainer: (any AdMediaContainer)? {
        return mediaContainerAdapter
    }

    public var priceInDollar: Double?

    public var nativeAdItem: NovaNativeAdItem? {
        didSet {
            if let mediaContent = nativeAdItem?.mediaContent {
                mediaContainerAdapter = NovaAdMediaContainerAdapter(mediaContent: mediaContent)
            }
        }
    }

    override public func isValid() -> Bool {
        return nativeAdItem != nil
    }

    // MARK: Private

    private var mediaContainerAdapter: NovaAdMediaContainerAdapter?
}
