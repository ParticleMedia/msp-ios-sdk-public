import Foundation

struct ActionModel {
    let actionKey: String

    /// actionDataModel should be an immutable struct
    let actionDataModel: Any

    init(actionKey: String, actionDataModel: Any = EmptyActionDataModel()) {
        self.actionKey = actionKey
        self.actionDataModel = actionDataModel
    }
}

extension ActionModel: Equatable {
    static func == (lhs: ActionModel, rhs: ActionModel) -> Bool {
        lhs.actionKey == rhs.actionKey
    }
}
