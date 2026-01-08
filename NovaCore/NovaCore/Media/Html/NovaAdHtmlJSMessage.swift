//
//  NovaAdHtmlJSMessage.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 11/12/25.
//
import WebKit

enum NovaAdHtmlJSMessage: String, CaseIterable {
    case adClick = "adClick"
    case adReport = "adReport"
    case adClose = "adClose"
    case getAdContext = "getAdContext"
    
    case novaNativeBridge = "novaNativeBridge"
}


public protocol NovaAdHtmlActionDelegate: AnyObject {
    
    func didTapAdCtr(customUrl: URL?)
    
    func didTapAdReport()
    
    func didTapAdClose()
    
    func didFailToLoadPage()
    
}
