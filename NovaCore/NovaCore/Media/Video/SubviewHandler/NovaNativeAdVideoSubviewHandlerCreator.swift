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
        case .playButtonOnCenter(let progressBarStyle):
            return NovaNativeAdVideoPlayButtonOnCenterSubviewHandler(
                delegate: delegate,
                progressBarStyle: progressBarStyle
            )
        case .landingPage:
            return NovaNativeAdVideoLandingPageSubviewHandler(delegate: delegate)
        }
    }
}
