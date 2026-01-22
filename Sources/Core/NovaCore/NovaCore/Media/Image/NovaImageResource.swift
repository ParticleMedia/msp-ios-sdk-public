//
//  NovaImageResource.swift
//  Pods
//
//  Created by Shanyu Li on 2025/8/7.
//

@_implementationOnly import Kingfisher
import UIKit

enum NovaAdImageResource {
    case imageURLStr(String)
    case image(UIImage)
    case imageUrl(URL)
}

enum NovaAdImageResourceError: LocalizedError {
    case convertToURL(String)
    case downloadError((URL, String))

    var errorDescription: String? {
        switch self {
        case .convertToURL(let str):
            return "Failed to convert string to URL: \(str)"
        case .downloadError(let (url, err)):
            return "Failed to download image with url: \(url), error info: \(err)"
        }
    }
}

struct NovaAdImageResourceDownloader {
    static func downloadImage(for resource: NovaAdImageResource) async throws -> UIImage {
        switch resource {
        case .imageURLStr(let string):
            guard let url = URL(string: string) else {
                throw NovaAdImageResourceError.convertToURL(string)
            }
            return try await downloadImage(with: url)
        case .image(let image):
            return image
        case .imageUrl(let url):
            return try await downloadImage(with: url)
        }
    }


    private static func downloadImage(with url: URL) async throws -> UIImage {
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = response as! HTTPURLResponse
        let statusCode = httpResponse.statusCode
        guard (200...299).contains(statusCode) else {
            throw NovaAdImageResourceError.downloadError((url, "Invalid status code: \(statusCode)"))
        }
        guard let image = UIImage(data: data) else {
            throw NovaAdImageResourceError.downloadError((url, "Failed to create image from data"))
        }
        return image
    }
}


extension UIImageView {
    func novaSetup(with resource: NovaAdImageResource, completion: @escaping (UIImage?) -> Void) {
        switch resource {
        case .image(let image):
            self.image = image
            completion(image)
        case .imageURLStr(let imageURLStr):
            guard let imageURL = URL(string: imageURLStr) else {
                DebugLogger.ui.error("Invalid image URL: \(imageURLStr)")
                return
            }

            kf.setImage(with: imageURL) { result in
                switch result {
                case .success(let imageResult):
                    DispatchQueue.main.async {
                        completion(imageResult.image)
                    }
                case .failure(let error):
                    DebugLogger.ui.error("Set image on view failed: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        case .imageUrl(let imageUrl):
            kf.setImage(with: imageUrl) { result in
                switch result {
                case .success(let imageResult):
                    DispatchQueue.main.async {
                        completion(imageResult.image)
                    }
                case .failure(let error):
                    DebugLogger.ui.error("Set image on view failed: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        }
    }
}
