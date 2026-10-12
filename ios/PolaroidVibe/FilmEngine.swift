import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum FilmPreset: String, CaseIterable, Codable, Identifiable {
    case sx70, instant669, px70, timeZero
    var id: String { rawValue }
    var title: String {
        switch self {
        case .sx70: return "Soft"
        case .instant669: return "Clear"
        case .px70: return "Sunny"
        case .timeZero: return "Old Days"
        }
    }
    var subtitle: String {
        switch self {
        case .sx70: return "Mềm mại · xanh olive"
        case .instant669: return "Trong trẻo · kem dịu"
        case .px70: return "Vintage · vàng ấm"
        case .timeZero: return "Phai màu · hoài niệm"
        }
    }
    var asset: String {
        switch self {
        case .sx70: return "picturefx-sx70"
        case .instant669: return "gmic-669"
        case .px70: return "gmic-px70"
        case .timeZero: return "gmic-timezero"
        }
    }
}

struct FilmSettings: Codable {
    var preset: FilmPreset = .sx70
    var strength: Double = 1
    var texture: Double = 0.6
}

enum FilmError: LocalizedError {
    case missingAsset, invalidLUT, renderFailed
    var errorDescription: String? {
        switch self {
        case .missingAsset: return "Không tìm thấy bộ màu trong app."
        case .invalidLUT: return "Không đọc được bộ màu film."
        case .renderFailed: return "Chưa xử lý được ảnh này. Thử ảnh khác nhé."
        }
    }
}

final class FilmEngine {
    static let shared = FilmEngine()
    static var sampleImage: UIImage {
        if let url = Bundle.main.url(forResource: "sample", withExtension: "jpg"),
           let image = UIImage(contentsOfFile: url.path) { return image }
        return UIGraphicsImageRenderer(size: CGSize(width: 600, height: 600)).image { ctx in
            UIColor.darkGray.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 600, height: 600))
        }
    }
    private let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
    private var grainCache: (CGSize, CIImage)?
    private var cache: [FilmPreset: (Int, Data)] = [:]

    // Rasterizing first applies EXIF orientation and bounds memory use on iPhone.
    static func normalized(_ image: UIImage, maxEdge: CGFloat = 1600, aspect: CGFloat = 1) -> UIImage {
        let cropWidth = min(image.size.width, image.size.height * aspect)
        let cropHeight = cropWidth / aspect
        let reduction = min(1, maxEdge / max(cropWidth, cropHeight))
        let size = CGSize(width: max(1, round(cropWidth * reduction)), height: max(1, round(cropHeight * reduction)))
        let scale = max(size.width / image.size.width, size.height / image.size.height)
        let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2,
                                  width: drawn.width, height: drawn.height))
        }
    }

    func render(_ image: UIImage, settings: FilmSettings) throws -> UIImage {
        guard let cg = image.cgImage else { throw FilmError.renderFailed }
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let input = CIImage(cgImage: cg, options: [.colorSpace: colorSpace])
        return try render(input, settings: settings)
    }

    // Shared LUT/texture pipeline for live camera buffers and captured photographs.
    func render(_ input: CIImage, settings: FilmSettings) throws -> UIImage {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let extent = input.extent.integral
        var output = input
        if settings.strength > 0 {
            let (dimension, data) = try cube(settings.preset)
            guard let filter = CIFilter(name: "CIColorCubeWithColorSpace", parameters: [
                "inputImage": input, "inputCubeDimension": dimension,
                "inputCubeData": data, "inputColorSpace": colorSpace
            ]), let colored = filter.outputImage else { throw FilmError.renderFailed }
            let dissolve = CIFilter.dissolveTransition()
            dissolve.inputImage = input
            dissolve.targetImage = colored
            dissolve.time = Float(settings.strength)
            output = dissolve.outputImage ?? colored
        }
        let amount = Float(settings.texture)
        if amount > 0 {
            let soft = CIFilter.gaussianBlur()
            soft.inputImage = output.clampedToExtent()
            soft.radius = amount * 0.65
            output = (soft.outputImage ?? output).cropped(to: extent)
            let cast = CIFilter.colorMatrix()
            cast.inputImage = output
            cast.rVector = CIVector(x: CGFloat(1 - amount * 0.025), y: 0, z: 0, w: 0)
            cast.gVector = CIVector(x: 0, y: CGFloat(1 - amount * 0.04), z: 0, w: 0)
            cast.bVector = CIVector(x: 0, y: 0, z: CGFloat(1 - amount * 0.085), w: 0)
            cast.biasVector = CIVector(x: CGFloat(amount * 0.028), y: CGFloat(amount * 0.02), z: CGFloat(amount * 0.012), w: 0)
            output = cast.outputImage ?? output
            // Seeded luminance grain stays stable as the sliders change.
            let width = Int(extent.width), height = Int(extent.height)
            let grain: CIImage
            if let cached = grainCache, cached.0 == extent.size {
                grain = cached.1
            } else {
                var noise = [UInt8](repeating: 255, count: width * height * 4)
                for pixel in 0..<(width * height) {
                    var hash = UInt32(truncatingIfNeeded: pixel) &* 374761393 &+ 31337
                    hash = (hash ^ (hash >> 13)) &* 1274126177
                    let value = UInt8((hash ^ (hash >> 16)) & 255)
                    noise[pixel * 4] = value
                    noise[pixel * 4 + 1] = value
                    noise[pixel * 4 + 2] = value
                }
                let generated = CIImage(bitmapData: Data(noise), bytesPerRow: width * 4,
                                    size: extent.size, format: .RGBA8, colorSpace: colorSpace)
                grain = generated
                grainCache = (extent.size, generated)
            }
            let overlay = CIFilter.softLightBlendMode()
            overlay.inputImage = grain
            overlay.backgroundImage = output
            let blend = CIFilter.dissolveTransition()
            blend.inputImage = output
            blend.targetImage = overlay.outputImage
            blend.time = amount * 0.12
            output = blend.outputImage ?? output
            let vignette = CIFilter.vignette()
            vignette.inputImage = output
            vignette.intensity = amount * 0.45
            vignette.radius = Float(min(extent.width, extent.height)) * 0.65
            output = vignette.outputImage ?? output
        }
        guard let result = context.createCGImage(output.cropped(to: extent), from: extent,
                                                format: .RGBA8, colorSpace: colorSpace) else { throw FilmError.renderFailed }
        return UIImage(cgImage: result)
    }

    private func cube(_ preset: FilmPreset) throws -> (Int, Data) {
        if let cached = cache[preset] { return cached }
        let result: (Int, Data)
        if preset == .sx70 {
            guard let url = Bundle.main.url(forResource: preset.asset, withExtension: "cube") else { throw FilmError.missingAsset }
            let text = try String(contentsOf: url, encoding: .utf8)
            var dimension = 0
            var values: [Float] = []
            for raw in text.components(separatedBy: .newlines) {
                let line = raw.components(separatedBy: "#")[0].trimmingCharacters(in: .whitespaces)
                let fields = line.split(whereSeparator: { $0.isWhitespace })
                if fields.isEmpty || line.hasPrefix("TITLE") { continue }
                if fields[0] == "LUT_3D_SIZE" { dimension = Int(fields.last!) ?? 0; continue }
                if fields[0] == "DOMAIN_MIN" || fields[0] == "DOMAIN_MAX" {
                    let expected: Float = fields[0] == "DOMAIN_MIN" ? 0 : 1
                    guard fields.count == 4, fields.dropFirst().allSatisfy({ Float($0) == expected }) else { throw FilmError.invalidLUT }
                    continue
                }
                guard fields.count == 3 else { throw FilmError.invalidLUT }
                for field in fields {
                    guard let value = Float(field), value.isFinite else { throw FilmError.invalidLUT }
                    values.append(value)
                }
                values.append(1)
            }
            guard dimension >= 2, dimension <= 256, values.count == dimension * dimension * dimension * 4 else { throw FilmError.invalidLUT }
            result = (dimension, values.withUnsafeBytes { Data($0) })
        } else {
            guard let url = Bundle.main.url(forResource: preset.asset, withExtension: "png"),
                  let source = UIImage(contentsOfFile: url.path)?.cgImage else { throw FilmError.missingAsset }
            let level = Int(round(pow(Double(source.width), 1.0 / 3)))
            guard source.width == source.height, level * level * level == source.width else { throw FilmError.invalidLUT }
            let dimension = level * level
            var pixels = [UInt8](repeating: 0, count: source.width * source.height * 4)
            let success = pixels.withUnsafeMutableBytes { bytes -> Bool in
                guard let ctx = CGContext(data: bytes.baseAddress, width: source.width, height: source.height,
                                          bitsPerComponent: 8, bytesPerRow: source.width * 4,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
                // A raw bitmap draw already preserves the PNG's scanline order.
                // Flipping here would reverse Hald rows and scramble the LUT axes.
                ctx.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
                return true
            }
            guard success else { throw FilmError.invalidLUT }
            var values = pixels.map { Float($0) / 255 }
            for index in stride(from: 3, to: values.count, by: 4) { values[index] = 1 }
            result = (dimension, values.withUnsafeBytes { Data($0) })
        }
        cache[preset] = result
        return result
    }
}
