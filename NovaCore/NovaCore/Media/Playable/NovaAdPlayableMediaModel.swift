//
//  NovaAdPlayableMediaModel.swift
//  Pods
//
//  Created by Shanyu Li on 2025/8/7.
//

struct NovaAdPlayableMediaModel {
    let playableActionModel: PlayableModel
    let layout: NovaAdPlayableInfo.Layout
    let actionBarFormat: NovaAdPlayableInfo.ActionBarFormat
    let tapToTryFormat: NovaAdPlayableInfo.TapToTryFormat
    let appInfo: AsyncValue<NovaAdAppInfo>?

    init(
        playableActionModel: PlayableModel,
        layout: NovaAdPlayableInfo.Layout?,
        actionBarFormat: NovaAdPlayableInfo.ActionBarFormat,
        tapToTryFormat: NovaAdPlayableInfo.TapToTryFormat,
        appInfo: AsyncValue<NovaAdAppInfo>?
    ) {
        self.playableActionModel = playableActionModel
        self.layout = layout ?? .showMedia
        self.actionBarFormat = actionBarFormat
        self.tapToTryFormat = tapToTryFormat
        self.appInfo = appInfo
    }
}
