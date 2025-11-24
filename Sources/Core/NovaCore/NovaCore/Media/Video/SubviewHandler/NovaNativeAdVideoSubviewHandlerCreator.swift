//
//  NovaNativeAdVideoSubviewHandler.swift
//  Pods
//
//  Created by Shanyu Li on 2025/1/24.
//

import CoreMedia

enum NovaNativeAdVideoSubviewHandlerCreator {
    static func create(
        with style: NovaAdVideoView.Style,
        delegate: any NovaAdVideoSubviewBehaviorDelegate
    ) -> any NovaNativeAdVideoSubviewHandler {
        switch style {
        case .clear:
            return NovaNativeAdVideoClearSubviewHandler()
        case .playButtonOnLeftBottom:
            return NovaNativeAdVideoPlayButtonOnLeftBottomSubviewHandler(delegate: delegate)
        case .playButtonOnCenter(let progressBarStyle, let popupCTAStyle):
            return NovaNativeAdVideoPlayButtonOnCenterSubviewHandler(
                delegate: delegate,
                progressBarStyle: progressBarStyle,
                popupCTAStyle: popupCTAStyle
            )
        case .landingPage:
            return NovaNativeAdVideoLandingPageSubviewHandler(delegate: delegate)
        }
    }
}
