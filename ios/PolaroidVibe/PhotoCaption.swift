import SwiftUI

/// Keep handwriting separate from the source photograph so editing never
/// stacks ink or film colors onto a previously exported image.
struct PhotoCaption: Codable {
    var text = ""
    var x: Double = 0.5
    // nil means the middle of the lower paper border, for any photo ratio.
    var y: Double? = nil
}

enum CaptionLayout {
    static let ink = UIColor(red: 0.16, green: 0.15, blue: 0.14, alpha: 0.94)

    static func glyph(_ text: String, width: CGFloat) -> UIImage? {
        let text = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let unit = width / 350
        let font = UIFont(name: "Mynerve-Regular", size: 24 * unit) ?? UIFont.systemFont(ofSize: 24 * unit)
        let natural = (text as NSString).size(withAttributes: [.font: font])
        // Shrink a long line to keep all ink inside the paper. Preview and
        // export use this same measurement, including Vietnamese accents.
        let scale = min(1, (width - 12 * unit) / max(1, natural.width))
        let fitted = font.withSize(font.pointSize * scale)
        let measured = (text as NSString).size(withAttributes: [.font: fitted])
        let size = CGSize(width: ceil(measured.width) + 2 * unit, height: ceil(measured.height) + 2 * unit)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            (text as NSString).draw(at: CGPoint(x: unit, y: unit), withAttributes: [.font: fitted, .foregroundColor: ink])
        }
    }

    static func center(_ caption: PhotoCaption, size: CGSize, glyph: CGSize, translation: CGSize = .zero) -> CGPoint {
        let w = size.width, h = size.height, margin = w * 0.06, gap = w / 350 * 3
        let photoBottom = h - w * 0.20
        let desired = CGPoint(x: w * caption.x + translation.width,
                              y: (caption.y.map { h * $0 } ?? (photoBottom + w * 0.10)) + translation.height)
        // Four disjoint pieces of paper. Restrict the WHOLE ink rectangle,
        // not just its center: neither the image nor the outside can be hit.
        let regions = [CGRect(x: 0, y: photoBottom, width: w, height: h - photoBottom),
                       CGRect(x: 0, y: 0, width: w, height: margin),
                       CGRect(x: 0, y: margin, width: margin, height: photoBottom - margin),
                       CGRect(x: w - margin, y: margin, width: margin, height: photoBottom - margin)]
        let candidates = regions.compactMap { region -> CGPoint? in
            let allowed = region.insetBy(dx: glyph.width / 2 + gap, dy: glyph.height / 2 + gap)
            guard allowed.width >= 0, allowed.height >= 0 else { return nil }
            return CGPoint(x: min(allowed.maxX, max(allowed.minX, desired.x)),
                           y: min(allowed.maxY, max(allowed.minY, desired.y)))
        }
        return candidates.min { a, b in
            hypot(a.x - desired.x, a.y - desired.y) < hypot(b.x - desired.x, b.y - desired.y)
        } ?? CGPoint(x: w / 2, y: photoBottom + w * 0.10)
    }

    static func draw(_ caption: PhotoCaption, in size: CGSize) {
        guard let glyph = glyph(caption.text, width: size.width) else { return }
        let point = center(caption, size: size, glyph: glyph.size)
        glyph.draw(at: CGPoint(x: point.x - glyph.size.width / 2, y: point.y - glyph.size.height / 2))
    }
}

struct CaptionCardEditor: View {
    let image: UIImage
    @Binding var caption: PhotoCaption
    let edit: () -> Void
    @GestureState private var translation = CGSize.zero

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            // Work at a fixed logical width so export and display retain the
            // same crop, ink size and position on every screen and photo ratio.
            let logical = CGSize(width: 350, height: 350 * image.size.height / image.size.width)
            let scale = size.width / 350
            ZStack(alignment: .topLeading) {
                PrintCard(image: image)
                if let glyph = CaptionLayout.glyph(caption.text, width: 350) {
                    let delta = CGSize(width: translation.width / scale, height: translation.height / scale)
                    let point = CaptionLayout.center(caption, size: logical, glyph: glyph.size, translation: delta)
                    Image(uiImage: glyph).resizable()
                        .frame(width: glyph.size.width * scale, height: glyph.size.height * scale)
                        .padding(6)
                        .contentShape(Rectangle())
                        .position(x: point.x * scale, y: point.y * scale)
                        .onTapGesture(perform: edit)
                        .gesture(DragGesture(minimumDistance: 8)
                            .updating($translation) { value, state, _ in state = value.translation }
                            .onEnded { value in
                                let delta = CGSize(width: value.translation.width / scale, height: value.translation.height / scale)
                                let end = CaptionLayout.center(caption, size: logical, glyph: glyph.size, translation: delta)
                                caption.x = end.x / logical.width
                                caption.y = end.y / logical.height
                            })
                        .accessibilityLabel("Chữ: \(caption.text)")
                        .accessibilityHint("Chạm để sửa chữ; kéo để đổi vị trí trên viền giấy")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction(.default, edit)
                } else {
                    Button(action: edit) {
                        Text("Tap to add text")
                            .font(.custom("Mynerve-Regular", size: 20 * scale))
                            .foregroundStyle(Color(uiColor: CaptionLayout.ink).opacity(0.5))
                            .frame(width: size.width, height: size.width * 0.20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(x: size.width / 2, y: size.height - size.width * 0.10)
                }
            }
        }
    }
}
