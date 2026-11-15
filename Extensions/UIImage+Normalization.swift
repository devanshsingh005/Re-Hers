import UIKit

public extension UIImage {
    /// The image redrawn so `imageOrientation` is `.up`, at the same size and scale.
    ///
    /// Camera and scanner images carry their rotation as EXIF metadata, which `pngData()`,
    /// `jpegData()` and PDF drawing drop; without this, uploads can come out rotated 90°.
    func normalized() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// PNG data of the upright image, or JPEG when PNG encoding fails, drawing it only once.
    func normalizedImageData(jpegQuality: CGFloat = 1.0) -> Data? {
        let upright = normalized()
        return upright.pngData() ?? upright.jpegData(compressionQuality: jpegQuality)
    }
}
