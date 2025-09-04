import Foundation
import UIKit

public protocol NovaNativeAdDelegate: AnyObject {
    func nativeAdDidLogImpression(_ nativeAd: NovaNativeAdItem)
    func nativeAdDidLogClick(_ nativeAd: NovaNativeAdItem, clickAreaName: String)
    func nativeAdDidFinishRender(_ nativeAd: NovaNativeAdItem)
    
    func nativeAdRootViewController() -> UIViewController?
}
