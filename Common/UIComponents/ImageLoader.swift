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
    private let loadingTasksQueue = DispatchQueue(label: "com.rehers.imageloader.tasks")
    
    private init() {}
    
    public func loadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        // Check cache first
        if let cachedImage = cache.object(forKey: urlString as NSString) {
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        }
        
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        loadingTasksQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Cancel existing task for this URL if any
            self.loadingTasks[urlString]?.cancel()
            
            // Create new download task
            let task = ImageLoader.session.dataTask(with: url) { [weak self] data, response, error in
                guard let self = self else { return }
                
                self.loadingTasksQueue.async {
                    // Remove task from dictionary
                    self.loadingTasks.removeValue(forKey: urlString)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200,
                          let mimeType = httpResponse.mimeType,
                          mimeType.hasPrefix("image/"),
                          let data = data,
                          let image = UIImage(data: data),
                          error == nil else {
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                        return
                    }
                    
                    // Cache the image
                    self.cache.setObject(image, forKey: urlString as NSString)
                    
                    DispatchQueue.main.async {
                        completion(image)
                    }
                }
            }
            
            // Store and start task
            self.loadingTasks[urlString] = task
            task.resume()
        }
    }
    
    public func cancelLoad(for urlString: String) {
        loadingTasksQueue.async { [weak self] in
            guard let self = self else { return }
            self.loadingTasks[urlString]?.cancel()
            self.loadingTasks.removeValue(forKey: urlString)
        }
    }
}
