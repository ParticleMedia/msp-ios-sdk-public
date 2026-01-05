//
//  NovaAdHtmlMediaModel.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/29/25.
//

public struct NovaAdHtmlMediaModel {
    var pages: [NovaAdHtmlPageModel]
    init(pages: [NovaAdHtmlPageModel]) {
        self.pages = pages
    }
}

public struct NovaAdHtmlPageModel {
    var resource: NovaAdHtmlResource
    var closeCountDownSeconds: Int?
    var closeDelaySeconds: Int?
    var useClickUrl: Bool
    var useCustomClose: Bool
    
    init(resource: NovaAdHtmlResource, closeCountDownSeconds: Int?, closeDelaySeconds: Int?, useClickUrl: Bool, useCustomClose: Bool) {
        self.resource = resource
        self.closeCountDownSeconds = closeCountDownSeconds
        self.closeDelaySeconds = closeDelaySeconds
        self.useClickUrl = useClickUrl
        self.useCustomClose = useCustomClose
    }
}
