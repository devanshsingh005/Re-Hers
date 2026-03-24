import UIKit

public class ImageLoader {
    public static let shared = ImageLoader()
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()
    private var cache = NSCache<NSString, UIImage>()
    private var loadingTasks: [String: URLSessionDataTask] = [:]
    
    private init() {}
    
    public func loadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        // Check cache first
        if let cachedImage = cache.object(forKey: urlString as NSString) {
            completion(cachedImage)
            return
        }
        
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        // Cancel existing task for this URL if any
        loadingTasks[urlString]?.cancel()
        
        // Create new download task
        let task = ImageLoader.session.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Remove task from dictionary
            self.loadingTasks.removeValue(forKey: urlString)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let mimeType = httpResponse.mimeType,
                  mimeType.hasPrefix("image/"),
                  let data = data,
                  let image = UIImage(data: data),
                  error == nil else {
                completion(nil)
                return
            }
            
            // Cache the image
            self.cache.setObject(image, forKey: urlString as NSString)
            
            DispatchQueue.main.async {
                completion(image)
            }
        }
        
        // Store and start task
        loadingTasks[urlString] = task
        task.resume()
    }
    
    public func cancelLoad(for urlString: String) {
        loadingTasks[urlString]?.cancel()
        loadingTasks.removeValue(forKey: urlString)
    }
}
