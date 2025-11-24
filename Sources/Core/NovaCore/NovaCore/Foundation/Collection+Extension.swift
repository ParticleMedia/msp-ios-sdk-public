//
//  Collection+Extension.swift
//  Pods
//
//  Created by Shanyu Li on 2025/8/13.
//

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
