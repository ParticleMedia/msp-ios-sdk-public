//
//  NovaAdPlayableMediaModel.swift
//  Pods
//
//  Created by Shanyu Li on 2025/8/7.
//

struct NovaAdPlayableMediaModel {
    let playableActionModel: PlayableModel
    let layout: NovaAdPlayableInfo.Layout

    init(playableActionModel: PlayableModel, layout: NovaAdPlayableInfo.Layout?) {
        self.playableActionModel = playableActionModel
        self.layout = layout ?? .showMedia
    }
}
