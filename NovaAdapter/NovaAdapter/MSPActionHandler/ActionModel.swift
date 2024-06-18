import Foundation

public struct ActionModel {
    public let actionKey: String

    /// actionDataModel should be an immutable struct
    public let actionDataModel: Any

    public init(actionKey: String, actionDataModel: Any = EmptyActionDataModel()) {
        self.actionKey = actionKey
        self.actionDataModel = actionDataModel
    }
}

extension ActionModel: Equatable {
    public static func == (lhs: ActionModel, rhs: ActionModel) -> Bool {
        return lhs.actionKey == rhs.actionKey
    }
}
