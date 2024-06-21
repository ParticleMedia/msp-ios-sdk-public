
import Foundation
import UIKit

public extension UIImage {
    func tint(_ tintColor: UIColor) -> UIImage {
        UIImage(image: self, tintColor: tintColor) ?? self
    }
}

extension UIImage {
    @objc convenience init?(image: UIImage, tintColor: UIColor) {
        func iconCgImage(for userInterfaceStyle: UIUserInterfaceStyle) -> CGImage? {
            var iconColor = tintColor
            iconColor = tintColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: userInterfaceStyle))
            
            let iconRender = UIGraphicsImageRenderer(
                size: CGSize(width: image.size.width, height: image.size.height)
            )
            
            let iconImage = iconRender.image { context in
                let bounds = context.format.bounds
                iconColor.setFill()
                context.fill(bounds)
                image.draw(in: bounds, blendMode: .destinationIn, alpha: 1.0)
            }
            
            return iconImage.cgImage
        }
        
        guard let lightCgImage = iconCgImage(for: .light), let darkCgImage = iconCgImage(for: .dark) else { return nil }
        
        self.init(cgImage: lightCgImage, scale: image.scale, orientation: image.imageOrientation)
        
        let darkImage = UIImage(cgImage: darkCgImage, scale: image.scale, orientation: image.imageOrientation)
        let traitCollection = UITraitCollection(traitsFrom: [
            UITraitCollection(displayScale: UITraitCollection.current.displayScale),
            UITraitCollection(userInterfaceStyle: .dark),
        ])
        self.imageAsset?.register(darkImage, with: traitCollection)
    }
}

extension UIImage {
    private class __ {}

    static func BundleUrl() -> URL? {
        return Bundle(for: __.self).url(forResource: "IconResourceBundle", withExtension: "bundle")
    }
}

public extension UIImage {

    // MARK: - System

    @objc convenience init?(systemName: Icon.System) {
        guard let url = Self.BundleUrl() else { fatalError("Wrong bundle url") }

        self.init(named: systemName.description, in: Bundle(url: url), compatibleWith: nil)
    }

    @objc convenience init?(systemName: Icon.System, tintColor: UIColor) {
        guard let image = UIImage(systemName: systemName) else {
            return nil
        }

        func iconCgImage(for userInterfaceStyle: UIUserInterfaceStyle) -> CGImage? {
            var iconColor = tintColor
            iconColor = tintColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: userInterfaceStyle))

            let iconRender = UIGraphicsImageRenderer(
                size: CGSize(width: image.size.width, height: image.size.height)
            )

            let iconImage = iconRender.image { context in
                let bounds = context.format.bounds
                iconColor.setFill()
                context.fill(bounds)
                image.draw(in: bounds, blendMode: .destinationIn, alpha: 1.0)
            }

            return iconImage.cgImage
        }

        guard let lightCgImage = iconCgImage(for: .light), let darkCgImage = iconCgImage(for: .dark) else { return nil }

        self.init(cgImage: lightCgImage, scale: image.scale, orientation: image.imageOrientation)

        let darkImage = UIImage(cgImage: darkCgImage, scale: image.scale, orientation: image.imageOrientation)
        let traitCollection = UITraitCollection(traitsFrom: [
            UITraitCollection(displayScale: UITraitCollection.current.displayScale),
            UITraitCollection(userInterfaceStyle: .dark),
        ])
        self.imageAsset?.register(darkImage, with: traitCollection)
    }
}

