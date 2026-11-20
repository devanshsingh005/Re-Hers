import UIKit
import CryptoKit

/// Loads remote images with a memory cache, a disk cache and at most one download per URL.
///
/// Disk reads, downloads and decoding all happen off the main thread; every completion runs on
/// the main queue. Callers asking for an image that is already downloading wait for that same
/// download instead of cancelling it.
nonisolated public final class ImageLoader: @unchecked Sendable {
    public static let shared = ImageLoader()

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    /// Thread-safe on its own.
    private let cache = NSCache<NSString, UIImage>()
    /// Owns `waiters`, `tasks` and `tokens`, and does the disk work.
    private let queue = DispatchQueue(label: "com.rehers.imageloader", qos: .userInitiated)
    private var waiters: [String: [(UIImage?) -> Void]] = [:]
    private var tasks: [String: URLSessionDataTask] = [:]
    /// Identifies the current download per key, so a cancelled one can't answer a newer request.
    private var tokens: [String: UUID] = [:]
    private let diskCacheDirectory: URL

    private init() {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        diskCacheDirectory = cachesDirectory.appendingPathComponent("RehearseImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
    }

    public func loadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        let key = canonicalCacheKey(for: urlString)
        if let image = cache.object(forKey: key as NSString) {
            DispatchQueue.main.async { completion(image) }
            return
        }

        queue.async { [self] in
            // Already on its way: wait for it.
            if waiters[key] != nil {
                waiters[key]?.append(completion)
                return
            }
            waiters[key] = [completion]

            if let data = try? Data(contentsOf: diskCacheFileURL(for: key)), let image = decoded(data) {
                cache.setObject(image, forKey: key as NSString)
                finish(key, with: image)
                return
            }
            guard let url = URL(string: urlString) else {
                finish(key, with: nil)
                return
            }

            let token = UUID()
            let task = Self.session.dataTask(with: url) { [self] data, response, error in
                var image: UIImage?
                if error == nil, (response as? HTTPURLResponse)?.statusCode == 200,
                   let data, let decodedImage = decoded(data) {
                    image = decodedImage
                    cache.setObject(decodedImage, forKey: key as NSString)
                    queue.async { [self] in try? data.write(to: diskCacheFileURL(for: key), options: [.atomic]) }
                }
                queue.async { [self] in
                    guard tokens[key] == token else { return }   // cancelled, or superseded
                    tokens[key] = nil
                    tasks[key] = nil
                    finish(key, with: image)
                }
            }
            tokens[key] = token
            tasks[key] = task
            task.resume()
        }
    }

    /// Stops loading `urlString`; its pending completions are dropped.
    public func cancelLoad(for urlString: String) {
        let key = canonicalCacheKey(for: urlString)
        queue.async { [self] in
            tasks[key]?.cancel()
            tasks[key] = nil
            tokens[key] = nil
            waiters[key] = nil
        }
    }

    // MARK: - Private (call on `queue`)

    private func finish(_ key: String, with image: UIImage?) {
        let callbacks = waiters.removeValue(forKey: key) ?? []
        DispatchQueue.main.async { callbacks.forEach { $0(image) } }
    }

    /// Decodes now, off the main thread, so drawing the image later doesn't stall scrolling.
    private func decoded(_ data: Data) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        return image.preparingForDisplay() ?? image
    }

    private func canonicalCacheKey(for urlString: String) -> String {
        guard var components = URLComponents(string: urlString) else { return urlString }
        components.query = nil
        components.fragment = nil
        return components.string ?? urlString
    }

    private func diskCacheFileURL(for cacheKey: String) -> URL {
        let digest = SHA256.hash(data: Data(cacheKey.utf8))
        return diskCacheDirectory.appendingPathComponent(digest.map { String(format: "%02x", $0) }.joined())
    }
}
