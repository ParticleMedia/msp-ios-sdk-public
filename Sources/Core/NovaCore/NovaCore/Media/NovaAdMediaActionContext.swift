//
//  NovaAdMediaActionContext.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/8/12.
//

import Foundation
import UIKit

struct NovaAdMediaActionContext {
    let adActionTracingInfo: AdActionTracingInfo
    let adActionExtraInfo: AdActionExtraInfo
    let viewController: Weak<UIViewController>?
}
