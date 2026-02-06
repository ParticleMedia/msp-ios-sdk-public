@_implementationOnly import Kingfisher
import UIKit

/// Public utility for loading images from URLs.
/// This wraps Kingfisher internally so adapters don't need to import Kingfisher directly.
@MainActor
public enum NovaImageLoader {
    /// Load an image from a URL into an image view.
    /// - Parameters:
    ///   - imageView: The UIImageView to load the image into
    ///   - url: The URL of the image
    ///   - placeholder: Optional placeholder image while loading
    public static func setImage(
        for imageView: UIImageView,
        with url: URL?,
        placeholder: UIImage? = nil
    ) {
        imageView.kf.setImage(with: url, placeholder: placeholder)
    }
}
