import Foundation

public final class ActionHandlerMaster: NSObject {
    private var actionMapping: [String: (actionModelDataType: Any.Type, actionHandler: ActionHandling)] = [:]

    @objc override public init() {
        super.init()
    }

    public init(actionHandlers: [ActionHandling]) {
        super.init()
        self.generateActionMapping(actionHandlers: actionHandlers)
    }

    public func addActionHandlers(actionHandlers: [ActionHandling]) {
        self.generateActionMapping(actionHandlers: actionHandlers)
    }

    private func generateActionMapping(actionHandlers: [ActionHandling]) {
        for actionHandler in actionHandlers {
            let supportedActions = actionHandler.supportedActions
            for (actionKey, actionModelDataType) in supportedActions() {
                if let _  = actionMapping[actionKey] {
                    assertionFailure("2 action hanlders registerd to the same action key = \(actionKey)")
                } else {
                    actionMapping[actionKey] = (actionModelDataType: actionModelDataType, actionHandler: actionHandler)
                }
            }
        }
    }

    private func canCast(_ object: Any, _ objectType: Any.Type) -> Bool {
        return sequence(
            first: Mirror(reflecting: object), next: { $0.superclassMirror }
        )
        .contains { $0.subjectType == objectType }
    }
}

extension ActionHandlerMaster: ActionHandling {
    public func supportedActions() -> [String: Any.Type] {
        var result: [String: Any.Type] = [:]

        for (actionKey, tupleValue) in actionMapping {
            result[actionKey] = tupleValue.actionModelDataType
        }

        return result
    }

    public func performAction(actionModel: ActionModel) {
        let actionKey = actionModel.actionKey
        let actionDataModel = actionModel.actionDataModel

        assert(Mirror(reflecting: actionDataModel).displayStyle == .struct, "actionDataModel should be immutable struct. actionKey = \(actionKey), actionDataModel=\(actionDataModel)")

        if let (actionModelDataType, actionHandler) = actionMapping[actionKey] {
            if canCast(actionDataModel, actionModelDataType) {
                actionHandler.performAction(actionModel: actionModel)
            } else {
                assertionFailure("Unmatched actionDataModel type. Expecting \(actionModelDataType) for actionKey = \(actionKey), actionDataModel=\(actionDataModel)")
            }
        } else {
            assertionFailure("No action hanlder is registed for actionKey = \(actionKey)")
        }
    }
}
