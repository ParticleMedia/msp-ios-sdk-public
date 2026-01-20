import Foundation

protocol ActionHandling: AnyObject {
    func supportedActions() -> [String: Any.Type]

    func performAction(actionModel: ActionModel, customUrl: URL?)
}
