//
//  MraidJsToNativeBridge.swift
//  NovaCore
//
//  Created by Shanyu Li on 2026/2/2.
//

import WebKit

final class MraidJsToNativeBridge: NSObject, WKScriptMessageHandler {
    private let commandHandler: MraidCommandHandler

    init(commandHandler: MraidCommandHandler) {
        self.commandHandler = commandHandler
        super.init()
    }

    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == MraidController.scriptMessageName else { return }
        commandHandler.handleMraidMessageBody(message.body)
    }
}
