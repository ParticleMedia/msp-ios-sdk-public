//
//  NovaUIUtils.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 11/6/24.
//

import Foundation
import UIKit


public class NovaUIUtils {
    public static func setImage(from url: URL, to imageView: UIImageView, completion: @escaping () -> Void) {
        // Create a URL session data task to fetch the image data
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            // Check if there's an error or if the data is nil
            if let error = error {
                print("Failed to load image: \(error.localizedDescription)")
                completion()
                return
            }
            
            // Make sure we have valid data
            guard let data = data else {
                print("No data received.")
                completion()
                return
            }
            
            // Attempt to create an image from the data
            if let image = UIImage(data: data) {
                // Update the imageView on the main thread
                DispatchQueue.main.async {
                    imageView.image = image
                }
            } else {
                print("Failed to create image from data.")
            }
            
            completion()
        }
        
        // Start the data task
        task.resume()
    }

}
