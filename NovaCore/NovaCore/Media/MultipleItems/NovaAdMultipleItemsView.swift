//
//  NovaAdMultipleItemsView.swift
//  NBNovaAdMedia
//
//  Created by Shanyu Li on 2025/3/6.
//

import SnapKit

// MARK: - NovaAdMultipleItemsViewProvider

enum NovaAdMultipleItemsViewProvider {
    static func getMultipleItemsView(
        with mediaModel: NovaAdMultipleItemsMediaModel
    ) -> any AnyMultipleItemsView {
        return {
            switch mediaModel.info.style {
            case .carousel:
                return NovaAdCarouselView()
            case .collection:
                return NovaAdCollectionView()
            }
        }()
    }
}
