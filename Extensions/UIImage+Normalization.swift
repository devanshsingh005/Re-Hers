import UIKit

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
