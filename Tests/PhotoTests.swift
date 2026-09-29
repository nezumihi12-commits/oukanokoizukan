import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import Hanazukan

final class PhotoTests: XCTestCase {
    private func fixture() throws -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
        let output = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil))
        let properties: [CFString: Any] = [
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 0.0,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 135.0,
                kCGImagePropertyGPSLongitudeRef: "W"
            ],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:09:29 12:30:00"]
        ]
        CGImageDestinationAddImage(destination, try XCTUnwrap(image.cgImage), properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return output as Data
    }
    func testMetadataZeroCoordinateAndHemisphere() throws {
        let result = try PhotoService.prepare(fixture(), useMetadata: true)
        XCTAssertEqual(result.location?.latitude, 0)
        XCTAssertEqual(result.location?.longitude, -135)
        XCTAssertNotNil(result.capturedAt)
        XCTAssertNotNil(UIImage(data: result.jpeg))
        let source = try XCTUnwrap(CGImageSourceCreateWithData(result.jpeg as CFData, nil))
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        XCTAssertNil(properties?[kCGImagePropertyGPSDictionary as String])
    }
    func testMetadataOptOutAndInvalidImage() throws {
        let result = try PhotoService.prepare(fixture(), useMetadata: false)
        XCTAssertNil(result.location)
        XCTAssertNil(result.capturedAt)
        XCTAssertThrowsError(try PhotoService.prepare(Data("invalid".utf8), useMetadata: true))
    }
}
