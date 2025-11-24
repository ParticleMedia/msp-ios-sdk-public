//
//  NovaActionHelper.swift
//  Pods
//
//  Created by Shanyu Li on 2025/8/11.
//

import CoreFoundation
import Foundation
import UIKit

enum NovaActionContext {
    case adInView(model: AdActionModel)
    /// * support close action
    case adInViewController(model: AdActionModel, viewController: Weak<UIViewController>)
    case adMultipleItems(model: AdMultipleItemsActionModel)

    // MARK: Internal

    var tracingInfo: AdActionTracingInfo {
        switch self {
        case .adInView(let model), .adInViewController(let model, _):
            return model.tracingInfo
        case .adMultipleItems(let model):
            return model.tracingInfo
        }
    }

    var onAdViewClick: ((UIView?) -> Void)? {
        switch self {
        case .adInView(let model), .adInViewController(let model, _):
            return model.extraInfo.onAdViewClick
        case .adMultipleItems(let model):
            return model.extraInfo.onAdViewClick
        }
    }
}

// MARK: - NovaActionState

enum NovaActionState {
    struct Init {}
    struct NovaEventSent {}
}

// MARK: - NovaActionHelper

struct NovaActionHelper<T> {
    private let context: NovaActionContext
    private let actionHandler: any ActionHandling
}

extension NovaActionHelper where T == Any {
    static func build(with context: NovaActionContext) -> NovaActionHelper<NovaActionState.Init> {
        return NovaActionHelper<NovaActionState.Init>(with: context)
    }
}

// MARK: - Log Sending

extension NovaActionHelper where T == NovaActionState.Init {
    func logNovaPlayableAdTapToTryEvent(
        reason: NovaAdMetricReporter.PlayableTapReason,
        with duration: CFTimeInterval? = nil,
        in area: ClickableAdArea? = nil
    ) -> NovaActionHelper<NovaActionState.NovaEventSent> {
        let durationInMs = duration.flatMap { ($0 * 1000).safeToInt() }
        NovaAdMetricReporter
            .logPlayableTapToTry(
                encryptedAdToken: context.tracingInfo.encryptedAdToken,
                reason: reason,
                durationInMs: durationInMs,
                clickArea: area
            )
        return NovaActionHelper<NovaActionState.NovaEventSent>(from: self)
    }

    func logNovaClickEvent(
        with duration: CFTimeInterval? = nil, in area: ClickableAdArea? = nil
    ) -> NovaActionHelper<NovaActionState.NovaEventSent> {
        let durationInMs = duration.flatMap { ($0 * 1000).safeToInt() }
        NovaAdMetricReporter
            .logAdClick(
                thirdPartyClickTrackingUrls: context.tracingInfo.thirdPartyClickTrackingUrls,
                encryptedAdToken: context.tracingInfo.encryptedAdToken,
                adUnitId: context.tracingInfo.adUnitId,
                durationInMs: durationInMs,
                clickArea: area
            )
        return NovaActionHelper<NovaActionState.NovaEventSent>(from: self)
    }

    func logNovaSkipEvent(with reason: NovaAdSkipReason, duration: CFTimeInterval) -> NovaActionHelper<NovaActionState.NovaEventSent> {
        NovaAdMetricReporter
            .logAdSkip(
                reason: reason,
                encryptedAdToken: context.tracingInfo.encryptedAdToken,
                durationInMs: duration.msString()
            )
        return NovaActionHelper<NovaActionState.NovaEventSent>(from: self)
    }
    
    func logNovaReportEvent() -> NovaActionHelper<NovaActionState.NovaEventSent> {
        // TODO: - GPY not implemented
        return NovaActionHelper<NovaActionState.NovaEventSent>(from: self)
    }
}

// MARK: - Tap Handling

extension NovaActionHelper where T == NovaActionState.NovaEventSent {
    /// NovaActionHelper should be kept alive until the action is performed
    func handleAdTap(in tapView: UIView?) -> NovaActionHelper<NovaActionState.Init> {
        handleTapAction(in: tapView)
        context.onAdViewClick?(tapView)
        return NovaActionHelper<NovaActionState.Init>(from: self)
    }

    /// NovaActionHelper should be kept alive until the action is performed
    func handleCloseTap() -> NovaActionHelper<NovaActionState.Init> {
        guard case .adInViewController(_, let weakVC) = context, let vc = weakVC.value else {
            assertionFailure("To close an ad, that ad must be in a view controller")
            return NovaActionHelper<NovaActionState.Init>(from: self)
        }

        vc.dismiss(animated: true)
        return NovaActionHelper<NovaActionState.Init>(from: self)
    }
    
    func handleReportTap() -> NovaActionHelper<NovaActionState.Init> {
        // TODO: - GPY not implemented
        return NovaActionHelper<NovaActionState.Init>(from: self)
    }
}

// MARK: - Common Private Method

private extension NovaActionHelper {
    init(with context: NovaActionContext) {
        self.context = context
        self.actionHandler = ActionHandlerMaster(actionHandlers: [NovaClickAdActionHandler()])
    }

    init<U>(from actionHelper: NovaActionHelper<U>) {
        self.context = actionHelper.context
        self.actionHandler = actionHelper.actionHandler
    }

    static func tapActionKey(from ctrType: AdCtrType) -> NovaClickAdActionKey {
        switch ctrType {
        case .openWeb(model: let model):
            if model.openBrowser {
                return .launchBrowser
            } else {
                return .launchWebView
            }
        case .appInstall:
            return .launchStore
        case .playable:
            return .launchPlayable
        }
    }
}

// MARK: - Private method after log sent

private extension NovaActionHelper where T == NovaActionState.NovaEventSent {
    func handleTapAction(in tapView: UIView?) {
        let actionModels = Self.generateCtrActionDateModels(from: context, in: tapView)
        for actionModel in actionModels {
            actionHandler.performAction(actionModel: actionModel)
        }
    }

    static func generateCtrActionDateModels(from context: NovaActionContext, in tapView: UIView?) -> [ActionModel] {
        switch context {
        case .adInViewController(model: let model, _):
            let tapActionModel = ActionModel(
                actionKey: tapActionKey(from: model.ctrType).rawValue,
                actionDataModel: NovaClickAdActionDataModel(
                    ctrType: model.ctrType,
                    tracingInfo: model.tracingInfo,
                    extraInfo: model.extraInfo,
                    clickTime: CACurrentMediaTime(),
                    clickView: tapView
                )
            )
            return [tapActionModel]
        case .adInView(model: let model):
            let tapActionModel = ActionModel(
                actionKey: tapActionKey(from: model.ctrType).rawValue,
                actionDataModel: NovaClickAdActionDataModel(
                    ctrType: model.ctrType,
                    tracingInfo: model.tracingInfo,
                    extraInfo: model.extraInfo,
                    clickTime: CACurrentMediaTime(),
                    clickView: tapView
                )
            )
            return [tapActionModel]
        case .adMultipleItems(let model):
            let tapActionModel = ActionModel(
                actionKey: tapActionKey(from: model.innerCtrType ?? model.outerCtrType).rawValue,
                actionDataModel: NovaClickAdActionDataModel(
                    ctrType: model.innerCtrType ?? model.outerCtrType,
                    tracingInfo: model.tracingInfo,
                    extraInfo: model.extraInfo,
                    clickTime: CACurrentMediaTime(),
                    clickView: tapView
                )
            )
            return [tapActionModel]
        }
    }
}
