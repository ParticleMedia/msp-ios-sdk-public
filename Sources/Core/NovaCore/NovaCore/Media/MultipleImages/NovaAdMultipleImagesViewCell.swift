//
//  NovaAdMultipleImagesViewCell.swift
//  NBNovaAds
//
//  Created by Shanyu Li on 2024/8/7.
//

import UIKit

class NovaAdMultipleImagesViewCell: UICollectionViewCell {
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setImage(with url: URL) {
        imageView.kf.setImage(with: url)
    }
}

private extension NovaAdMultipleImagesViewCell {
    func setupSubviews() {
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
