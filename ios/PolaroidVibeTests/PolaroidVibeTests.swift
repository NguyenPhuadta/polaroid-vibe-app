import XCTest
import UIKit
@testable import PolaroidVibe

final class PolaroidVibeTests: XCTestCase {
    private func solid(_ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8), format: {
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; return format
        }()).image { context in
            color.setFill(); context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }
    private func rgb(_ image: UIImage) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: 4)
        pixels.withUnsafeMutableBytes { bytes in
            let context = CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                                    bytesPerRow: 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
            context.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return Array(pixels.prefix(3))
    }
    func testCropsKeepAllThreeFilmRatiosAndPixelLimit() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 1800)).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 1200, height: 1800))
        }
        for ratio in PhotoRatio.allCases {
            let cropped = FilmEngine.normalized(image, maxEdge: 800, aspect: ratio.aspect)
            XCTAssertEqual(cropped.size.width / cropped.size.height, ratio.aspect, accuracy: 0.002)
            XCTAssertLessThanOrEqual(max(cropped.size.width, cropped.size.height), 800)
            let rendered = try FilmEngine().render(cropped, settings: FilmSettings(strength: 0, texture: 0))
            XCTAssertEqual(rendered.size, cropped.size)
        }
    }
    func testAllRealLUTsRenderAndZeroStrengthBypassesColor() throws {
        let engine = FilmEngine()
        let image = solid(UIColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1))
        for preset in FilmPreset.allCases {
            let rendered = try engine.render(image, settings: FilmSettings(preset: preset, strength: 1, texture: 0))
            XCTAssertEqual(rendered.size, image.size)
            XCTAssertNotEqual(rgb(rendered), rgb(image), "\(preset) should change the test color")
            let bypass = try engine.render(image, settings: FilmSettings(preset: preset, strength: 0, texture: 0))
            for (actual, expected) in zip(rgb(bypass), rgb(image)) { XCTAssertLessThanOrEqual(abs(Int(actual) - Int(expected)), 1) }
        }
    }
    func testHaldAxesAndColorSpaceMatchSourcePNGAtCubeEndpoints() throws {
        let engine = FilmEngine()
        // The LUT resources live in the hosted app, not the test bundle.
        for preset in FilmPreset.allCases where preset != .sx70 {
            let url = Bundle.main.url(forResource: preset.asset, withExtension: "png")!
            let png = UIImage(contentsOfFile: url.path)!.cgImage!
            for r in [0, 63] { for g in [0, 63] { for b in [0, 63] {
                let index = r + g * 64 + b * 64 * 64
                let pixel = png.cropping(to: CGRect(x: index % 512, y: index / 512, width: 1, height: 1))!
                let expected = rgb(UIImage(cgImage: pixel))
                let image = solid(UIColor(red: CGFloat(r) / 63, green: CGFloat(g) / 63, blue: CGFloat(b) / 63, alpha: 1))
                let actual = rgb(try engine.render(image, settings: FilmSettings(preset: preset, strength: 1, texture: 0)))
                for (value, reference) in zip(actual, expected) {
                    XCTAssertLessThanOrEqual(abs(Int(value) - Int(reference)), 2, "\(preset) endpoint \(r),\(g),\(b)")
                }
            } } }
        }
    }
    func testTextureIsDeterministicAndExportMatchesSquarePreview() throws {
        let engine = FilmEngine()
        let image = solid(.gray)
        let settings = FilmSettings(texture: 0.6)
        let first = try engine.render(image, settings: settings)
        let second = try engine.render(image, settings: settings)
        XCTAssertEqual(first.pngData(), second.pngData())
        let sample = FilmEngine.normalized(FilmEngine.sampleImage)
        XCTAssertEqual(sample.size.width, sample.size.height)
        XCTAssertLessThanOrEqual(sample.size.width, 1600)
    }
}
