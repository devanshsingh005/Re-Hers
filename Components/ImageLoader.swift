import UIKit
import CryptoKit

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
    private let diskCacheQueue = DispatchQueue(label: "com.rehers.imageloader.disk")
    private let diskCacheDirectory: URL
    
    private init() {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        diskCacheDirectory = cachesDirectory.appendingPathComponent("RehearseImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
    }
    
    public func loadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = canonicalCacheKey(for: urlString)

        // Check cache first
        if let cachedImage = cache.object(forKey: cacheKey as NSString) {
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        }

        if let cachedImage = cachedDiskImage(for: cacheKey) {
            cache.setObject(cachedImage, forKey: cacheKey as NSString)
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
            self.loadingTasks[cacheKey]?.cancel()
            
            // Create new download task
            let task = ImageLoader.session.dataTask(with: url) { [weak self] data, response, error in
                guard let self = self else { return }
                
                self.loadingTasksQueue.async {
                    // Remove task from dictionary
                    self.loadingTasks.removeValue(forKey: cacheKey)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200,
                          let data = data,
                          let image = UIImage(data: data),
                          error == nil else {
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                        return
                    }
                    
                    // Cache the image
                    self.cache.setObject(image, forKey: cacheKey as NSString)
                    self.storeDiskImageData(data, for: cacheKey)
                    
                    DispatchQueue.main.async {
                        completion(image)
                    }
                }
            }
            
            // Store and start task
            self.loadingTasks[cacheKey] = task
            task.resume()
        }
    }
    
    public func cancelLoad(for urlString: String) {
        let cacheKey = canonicalCacheKey(for: urlString)
        loadingTasksQueue.async { [weak self] in
            guard let self = self else { return }
            self.loadingTasks[cacheKey]?.cancel()
            self.loadingTasks.removeValue(forKey: cacheKey)
        }
    }

    private func canonicalCacheKey(for urlString: String) -> String {
        guard var components = URLComponents(string: urlString) else { return urlString }
        components.query = nil
        components.fragment = nil
        return components.string ?? urlString
    }

    private func cachedDiskImage(for cacheKey: String) -> UIImage? {
        diskCacheQueue.sync {
            let fileURL = diskCacheFileURL(for: cacheKey)
            guard let data = try? Data(contentsOf: fileURL),
                  let image = UIImage(data: data) else {
                return nil
            }
            return image
        }
    }

    private func storeDiskImageData(_ data: Data, for cacheKey: String) {
        diskCacheQueue.async { [diskCacheDirectory] in
            let fileURL = diskCacheDirectory.appendingPathComponent(Self.diskCacheFileName(for: cacheKey))
            try? data.write(to: fileURL, options: [.atomic])
        }
    }

    private func diskCacheFileURL(for cacheKey: String) -> URL {
        diskCacheDirectory.appendingPathComponent(Self.diskCacheFileName(for: cacheKey))
    }

    private static func diskCacheFileName(for cacheKey: String) -> String {
        let digest = SHA256.hash(data: Data(cacheKey.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

public extension UIImage {
    /// Normalizes the image's orientation to `.up` by redrawing it.
    /// This fixes issues where EXIF orientation is stripped during `jpegData` or `pngData` extraction, 
    /// which commonly causes uploaded images to appear rotated by 90 degrees.
    func normalized() -> UIImage {
        if self.imageOrientation == .up {
            return self
        }

        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.draw(in: CGRect(origin: .zero, size: self.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage ?? self
    }
}
