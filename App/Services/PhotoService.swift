import Foundation
import ImageIO
import UniformTypeIdentifiers

struct PreparedPhoto: Sendable {
    let jpeg: Data
    let capturedAt: Date?
    let location: GeoPoint?
}
enum PhotoService {
    static func prepare(_ data: Data, useMetadata: Bool) throws -> PreparedPhoto {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 1800,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else { throw PhotoError.invalid }
        let properties: [String: Any] = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]) ?? [:]
        var capturedAt: Date?
        var point: GeoPoint?
        if useMetadata {
            let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
            if let date = exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                capturedAt = formatter.date(from: date)
            }
            if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any],
               let lat = (gps[kCGImagePropertyGPSLatitude as String] as? NSNumber)?.doubleValue,
               let lon = (gps[kCGImagePropertyGPSLongitude as String] as? NSNumber)?.doubleValue {
                let latitude = (gps[kCGImagePropertyGPSLatitudeRef as String] as? String) == "S" ? -lat : lat
                let longitude = (gps[kCGImagePropertyGPSLongitudeRef as String] as? String) == "W" ? -lon : lon
                let candidate = GeoPoint(latitude: latitude, longitude: longitude, recordedAt: capturedAt ?? Date(), source: "EXIF")
                if candidate.valid { point = candidate }
            }
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { throw PhotoError.invalid }
        // Re-encode pixels without embedding location in the image. Metadata lives in the local model.
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw PhotoError.invalid }
        return PreparedPhoto(jpeg: output as Data, capturedAt: capturedAt, location: point)
    }
}
enum PhotoError: LocalizedError {
    case invalid
    var errorDescription: String? { "画像を読み込めません。別の写真でお試しください。" }
}
