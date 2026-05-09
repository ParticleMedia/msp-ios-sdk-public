//
//  NovaAdHtmlJSMessage.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 11/12/25.
//
import WebKit

enum NovaAdHtmlJSMessage: String, CaseIterable {
    case adReport = "adReport"
    case adClose = "adClose"
    case getAdContext = "getAdContext"

    case novaNativeBridge = "novaNativeBridge"
    case mraidBridge = "mraidBridge"
    case consoleLog = "consoleLog"
}


protocol NovaAdHtmlActionDelegate: AnyObject {
    func didTapAdCtr(_ payload: NovaAdClickPayload)

    func didTapAdReport()

    func didTapAdClose()

    /// Show App Store overlay (e.g. when HTML sends OPEN_IOS_STORE_OVERLAY). Implementer owns overlay and dismisses on lifecycle (willDisappear, page change).
    func showSKOverlay(appStoreId: Int?)

    func didFailToLoadPage(errorType: String, errorDetail: String)

}
