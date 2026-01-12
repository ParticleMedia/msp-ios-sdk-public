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
    
    func didTapAdCtr(customUrl: URL?, clickArea: String?)
    
    func didTapAdReport()
    
    func didTapAdClose()
    
    func didFailToLoadPage()
    
}
