import Foundation
import UIKit

struct NovaClickAdActionDataModel {
    // MARK: Lifecycle

    init(
        ctrType: AdCtrType,
        tracingInfo: AdActionTracingInfo,
        extraInfo: AdActionExtraInfo,
        clickTime: Double,
        clickView: UIView?
    ) {
        self.ctrType = ctrType
        self.tracingInfo = tracingInfo
        self.clickTime = clickTime
        self.extraInfo = extraInfo
        self.clickPart = (area: clickView?.adClickArea, inWindowFrame: clickView?.frameInWindow)
    }

    // MARK: Internal

    // this is needed for the click area ctrType may not be the same as `ad.adCtryType` like carousel ad
    let ctrType: AdCtrType
    let tracingInfo: AdActionTracingInfo
    let extraInfo: AdActionExtraInfo
    let clickTime: Double
    let clickPart: (area: ClickableAdArea?, inWindowFrame: CGRect?)
}
