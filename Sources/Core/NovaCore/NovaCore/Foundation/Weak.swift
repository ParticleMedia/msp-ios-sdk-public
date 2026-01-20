//
//  Weak.swift
//  Pods
//
//  Created by Shanyu Li on 2025/8/12.
//

import UIKit

final class Weak<T: AnyObject> {
    weak var value: T?

    init(_ value: T?) {
        self.value = value
    }
}
