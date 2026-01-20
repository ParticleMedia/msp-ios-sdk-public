//
//  AnyMultipleItemsView.swift
//  NBNovaAdMedia
//
//  Created by Shanyu Li on 2025/3/6.
//

import Foundation
import UIKit

protocol AnyMultipleItemsView: UIView {
    func config(
        with model: NovaAdMultipleItemsMediaModel,
        actionContext: NovaAdMediaActionContext?,
        completion: @escaping () -> Void
    )
}
