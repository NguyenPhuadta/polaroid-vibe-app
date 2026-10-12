import SwiftUI
import ImageIO

struct GalleryImages {
    let framed: UIImage
    let thumbnail: UIImage
}

struct FilmPhoto: Codable, Identifiable {
    let id: UUID
    let date: Date
    let settings: FilmSettings
    var frameVersion: Int? = nil
    var originalFileName: String? = nil
    var renderFileName: String? = nil
    var revision: Int? = nil
    var caption: PhotoCaption? = nil
    var fileName: String { renderFileName ?? "\(id.uuidString).jpg" }
}

@MainActor
final class PhotoStore: ObservableObject {
    @Published private(set) var photos: [FilmPhoto] = []
    private let directory: URL
    init() {
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FilmPhotos", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if let data = try? Data(contentsOf: directory.appendingPathComponent("photos.json")) {
                photos = try JSONDecoder().decode([FilmPhoto].self, from: data)
            }
        } catch { print("Gallery could not be loaded: \(error.localizedDescription)") }
    }
    func save(_ image: UIImage, settings: FilmSettings, original: UIImage? = nil, caption: PhotoCaption? = nil) throws {
        guard let data = image.jpegData(compressionQuality: 0.96) else { throw FilmError.renderFailed }
        let id = UUID()
        let originalName = original == nil ? nil : "\(id.uuidString)-original.png"
        let photo = FilmPhoto(id: id, date: Date(), settings: settings, frameVersion: InstantFrame.version, originalFileName: originalName, caption: caption)
        let imageURL = directory.appendingPathComponent(photo.fileName)
        let updated = [photo] + photos
        do {
            if let original, let originalName {
                guard let originalData = original.pngData() else { throw FilmError.renderFailed }
                try originalData.write(to: directory.appendingPathComponent(originalName), options: .atomic)
            }
            try data.write(to: imageURL, options: .atomic)
            try JSONEncoder().encode(updated).write(to: directory.appendingPathComponent("photos.json"), options: .atomic)
            photos = updated
        } catch {
            try? FileManager.default.removeItem(at: imageURL)
            if let originalName { try? FileManager.default.removeItem(at: directory.appendingPathComponent(originalName)) }
            throw error
        }
    }

    func original(for photo: FilmPhoto) -> UIImage? {
        guard let name = photo.originalFileName else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(name).path)
    }

    func hasOriginal(for photo: FilmPhoto) -> Bool {
        guard let name = photo.originalFileName else { return false }
        return FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path)
    }

    func update(_ photo: FilmPhoto, image: UIImage, settings: FilmSettings, caption: PhotoCaption? = nil) throws {
        guard let index = photos.firstIndex(where: { $0.id == photo.id }),
              let data = image.jpegData(compressionQuality: 0.96) else { throw FilmError.renderFailed }
        let previous = photos[index]
        let name = "\(UUID().uuidString).jpg"
        let imageURL = directory.appendingPathComponent(name)
        let replacement = FilmPhoto(id: previous.id, date: previous.date, settings: settings,
                                    frameVersion: InstantFrame.version, originalFileName: previous.originalFileName,
                                    renderFileName: name, revision: (previous.revision ?? 0) + 1, caption: caption)
        var updated = photos
        updated[index] = replacement
        // Write a new render before committing the index. A failed save must
        // leave the previous image and its metadata together and usable.
        do {
            try data.write(to: imageURL, options: .atomic)
            try JSONEncoder().encode(updated).write(to: directory.appendingPathComponent("photos.json"), options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: imageURL)
            throw error
        }
        photos = updated
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(previous.fileName))
    }

    func delete(_ photo: FilmPhoto) throws {
        let updated = photos.filter { $0.id != photo.id }
        // Commit the gallery index first; a failed write must not lose the photo.
        try JSONEncoder().encode(updated).write(to: directory.appendingPathComponent("photos.json"), options: .atomic)
        photos = updated
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(photo.fileName))
        if let name = photo.originalFileName {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }
    func image(for photo: FilmPhoto) -> UIImage? {
        guard let image = UIImage(contentsOfFile: directory.appendingPathComponent(photo.fileName).path) else { return nil }
        if photo.frameVersion == InstantFrame.version { return image }
        // Upgrade the presentation without rewriting saved files or film colors.
        let unframed = photo.frameVersion == nil ? image : InstantFrame.photoImage(from: image)
        return InstantFrame.render(unframed)
    }

    func galleryImages(for photo: FilmPhoto) async -> GalleryImages? {
        let url = directory.appendingPathComponent(photo.fileName)
        let needsFrame = photo.frameVersion == nil
        let needsNewMaterial = photo.frameVersion != InstantFrame.version
        return await Task.detached(priority: .userInitiated) { () -> GalleryImages? in
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 1000,
                    kCGImageSourceShouldCacheImmediately: true
                  ] as CFDictionary) else { return nil }
            let image = UIImage(cgImage: thumbnail)
            let unframed = needsFrame ? image : InstantFrame.photoImage(from: image)
            let small = FilmEngine.normalized(unframed, maxEdge: 192,
                                             aspect: unframed.size.width / max(1, unframed.size.height))
            return GalleryImages(framed: needsNewMaterial ? InstantFrame.render(unframed) : image, thumbnail: small)
        }.value
    }
}
