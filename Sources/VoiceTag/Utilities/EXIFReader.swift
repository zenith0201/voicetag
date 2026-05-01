import Foundation
import ImageIO

// MARK: - EXIFReader

struct EXIFReader {

    struct ImageMetadata {
        var dateTaken: Date?
        var cameraModel: String?
        var latitude: Double?
        var longitude: Double?
        var width: Int?
        var height: Int?
    }

    static func read(from url: URL) -> ImageMetadata {
        var meta = ImageMetadata()
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return meta
        }

        // Pixel dimensions
        if let width = props[kCGImagePropertyPixelWidth as String] as? Int {
            meta.width = width
        }
        if let height = props[kCGImagePropertyPixelHeight as String] as? Int {
            meta.height = height
        }

        // EXIF
        if let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            if let dateStr = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy:MM:dd HH:mm:ss"
                meta.dateTaken = fmt.date(from: dateStr)
            }
        }

        // Tiff / camera model
        if let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            meta.cameraModel = tiff[kCGImagePropertyTIFFModel as String] as? String
        }

        // GPS
        if let gps = props[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double ?? 0
            let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String ?? "N"
            let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double ?? 0
            let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String ?? "E"
            meta.latitude = latRef == "S" ? -lat : lat
            meta.longitude = lonRef == "W" ? -lon : lon
        }

        return meta
    }

    static func formattedDate(_ url: URL) -> String? {
        guard let date = read(from: url).dateTaken else { return nil }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }
}
