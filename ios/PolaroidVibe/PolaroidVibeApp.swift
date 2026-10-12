import SwiftUI
import PhotosUI
import Photos

private enum Palette {
    static let ink = Color(red: 0.09, green: 0.10, blue: 0.09)
    static let paper = Color(red: 0.96, green: 0.94, blue: 0.89)
    static let muted = Color(red: 0.48, green: 0.49, blue: 0.44)
    static let accent = Color(red: 0.96, green: 0.64, blue: 0.40)
}

actor FilmRenderer {
    static let shared = FilmRenderer()
    private let engine = FilmEngine()
    func render(_ image: UIImage, settings: FilmSettings) throws -> UIImage {
        try engine.render(image, settings: settings)
    }
}

@main
struct PolaroidVibeApp: App {
    @StateObject private var store = PhotoStore()
    init() {
        // Native navigation titles do not inherit the SwiftUI font design.
        let navigationBar = UINavigationBar.appearance()
        func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
            let font = UIFont.systemFont(ofSize: size, weight: weight)
            return UIFont(descriptor: font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor, size: size)
        }
        var titleAttributes = navigationBar.titleTextAttributes ?? [:]
        titleAttributes[.font] = roundedFont(size: 17, weight: .semibold)
        navigationBar.titleTextAttributes = titleAttributes
        var largeTitleAttributes = navigationBar.largeTitleTextAttributes ?? [:]
        largeTitleAttributes[.font] = roundedFont(size: 34, weight: .bold)
        navigationBar.largeTitleTextAttributes = largeTitleAttributes
    }
    var body: some Scene {
        WindowGroup { CameraScreen().environmentObject(store).fontDesign(.rounded).preferredColorScheme(.dark) }
    }
}

struct PresetStrip: View {
    @Binding var selection: FilmPreset
    var dark = false
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(FilmPreset.allCases) { preset in
                    Button { selection = preset; UISelectionFeedbackGenerator().selectionChanged() } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(preset.title).font(.system(size: 17, weight: .semibold, design: .rounded))
                                Spacer(minLength: 10)
                                if selection == preset { Image(systemName: "checkmark.circle.fill").font(.system(size: 13, design: .rounded)) }
                            }
                            Text(preset.subtitle).font(.system(size: 9, design: .rounded)).opacity(0.65)
                        }
                        .frame(width: 123, alignment: .leading).padding(13)
                        .foregroundStyle(selection == preset ? Palette.ink : dark ? Palette.paper : Palette.ink)
                        .background(selection == preset ? Palette.accent : dark ? Color.white.opacity(0.07) : Color.black.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                    }.accessibilityIdentifier("preset_\(preset.rawValue)")
                }
            }.padding(.horizontal, 20)
        }
    }
}

/// One geometry and paper renderer shared by preview, storage and export.
enum InstantFrame {
    static let version = 2
    /// Versions 1 and 2 share the same layout; only the material has changed.
    static func photoImage(from framed: UIImage) -> UIImage {
        guard let image = framed.cgImage else { return framed }
        let width = CGFloat(image.width)
        let rect = CGRect(x: width * 0.06, y: width * 0.06,
                          width: width * 0.88, height: CGFloat(image.height) - width * 0.26)
        // Round inward so the thumbnail never includes the paper's edge.
        let crop = CGRect(x: ceil(rect.minX), y: ceil(rect.minY),
                          width: floor(rect.maxX) - ceil(rect.minX),
                          height: floor(rect.maxY) - ceil(rect.minY))
        guard crop.width > 0, crop.height > 0, let cropped = image.cropping(to: crop) else { return framed }
        return UIImage(cgImage: cropped)
    }
    private static let paper = UIColor(red: 245 / 255, green: 243 / 255, blue: 238 / 255, alpha: 1)
    // Material is cached once; it is independent of film color and grain.
    private static let texture: UIImage = {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128), format: format).image { renderer in
            var seed: UInt32 = 14
            for y in 0..<128 {
                for x in 0..<128 {
                    seed = 1664525 &* seed &+ 1013904223
                    let light = seed & 1 == 0
                    (light ? UIColor.white : UIColor.black).withAlphaComponent(CGFloat((seed >> 16) & 255) / 255 * 0.055).setFill()
                    renderer.cgContext.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
    }()
    static func render(_ image: UIImage, caption: PhotoCaption? = nil) -> UIImage {
        let aspect = image.size.width / max(1, image.size.height)
        let idealWidth = image.size.width / 0.88
        let width = min(idealWidth, 2200 / (0.88 / aspect + 0.26))
        let border = width * 0.06
        let photoSize = CGSize(width: width * 0.88, height: width * 0.88 / aspect)
        let size = CGSize(width: width, height: photoSize.height + width * 0.26)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            let context = renderer.cgContext
            let unit = width / 350
            let bounds = CGRect(origin: .zero, size: size)
            paper.setFill(); context.fill(CGRect(origin: .zero, size: size))
            // Paper texture is independent of the image's LUT and film grain.
            context.saveGState()
            if let material = UIImage(named: "InstantPaper") {
                context.setBlendMode(.multiply)
                material.draw(in: bounds, blendMode: .multiply, alpha: 0.32)
            } else {
                context.scaleBy(x: unit, y: unit)
                texture.drawAsPattern(in: CGRect(x: 0, y: 0, width: 350, height: size.height / unit))
            }
            context.restoreGState()
            // Broad, quiet lighting makes the coating read as one surface;
            // the fine edge lighting below supplies thickness, not a bevel.
            shade(context, in: bounds,
                  colors: [.white.withAlphaComponent(0.16), .clear, .black.withAlphaComponent(0.035)],
                  from: .zero, to: CGPoint(x: width, y: size.height))
            let rect = CGRect(origin: CGPoint(x: border, y: border), size: photoSize)
            let window = UIBezierPath(roundedRect: rect, cornerRadius: width / 350 * 1.5)
            context.saveGState(); window.addClip(); image.draw(in: rect); context.restoreGState()
            UIColor.black.withAlphaComponent(0.10).setStroke()
            window.lineWidth = width / 350 * 0.6; window.stroke()
            // The photograph sits below the rim. Soft directional shadows
            // replace a hard line, and remain inside the image window.
            context.saveGState(); window.addClip()
            shade(context, in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 3 * unit),
                  colors: [.black.withAlphaComponent(0.24), .clear],
                  from: CGPoint(x: rect.minX, y: rect.minY), to: CGPoint(x: rect.minX, y: rect.minY + 3 * unit))
            shade(context, in: CGRect(x: rect.minX, y: rect.minY, width: 2 * unit, height: rect.height),
                  colors: [.black.withAlphaComponent(0.14), .clear],
                  from: CGPoint(x: rect.minX, y: rect.minY), to: CGPoint(x: rect.minX + 2 * unit, y: rect.minY))
            context.restoreGState()
            if let caption { CaptionLayout.draw(caption, in: size) }
            // A coated film border has a thin bright upper edge and a darker
            // lower edge. Keep this below a few display points, not a 3D slab.
            shade(context, in: CGRect(x: 0, y: 0, width: width, height: 1.5 * unit),
                  colors: [.white.withAlphaComponent(0.65), .clear],
                  from: .zero, to: CGPoint(x: 0, y: 1.5 * unit))
            shade(context, in: CGRect(x: 0, y: size.height - 3 * unit, width: width, height: 3 * unit),
                  colors: [.clear, .black.withAlphaComponent(0.17)],
                  from: CGPoint(x: 0, y: size.height - 3 * unit), to: CGPoint(x: 0, y: size.height))
            shade(context, in: CGRect(x: width - 1.5 * unit, y: 0, width: 1.5 * unit, height: size.height),
                  colors: [.clear, .black.withAlphaComponent(0.07)],
                  from: CGPoint(x: width - 1.5 * unit, y: 0), to: CGPoint(x: width, y: 0))
        }
    }

    private static func shade(_ context: CGContext, in rect: CGRect,
                              colors: [UIColor], from start: CGPoint, to end: CGPoint) {
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors.map(\.cgColor) as CFArray, locations: nil) else { return }
        context.saveGState()
        context.clip(to: rect)
        context.drawLinearGradient(gradient, start: start, end: end,
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.restoreGState()
    }
}

struct PrintCard: View {
    let image: UIImage
    var body: some View {
        Image(uiImage: image).resizable()
            .aspectRatio(image.size.width / image.size.height, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.10), radius: 2, x: 0, y: 2)
            .shadow(color: .black.opacity(0.17), radius: 12, x: 0, y: 8)
    }
}

struct PreviewScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let source: UIImage
    @Binding var settings: FilmSettings
    var initialCaption: PhotoCaption? = nil
    let onSave: (UIImage, FilmSettings, PhotoCaption?) throws -> Void
    @State private var caption = PhotoCaption()
    @State private var captionEditing = false
    @FocusState private var captionFocused: Bool
    @State private var framedPreview: UIImage?
    @State private var rendered: UIImage?
    @State private var renderedKey: String?
    @State private var working = true
    @State private var error: String?
    @State private var renderTask: Task<Void, Never>?
    @State private var generation = 0
    private let presetOrder: [FilmPreset] = [.px70, .sx70, .timeZero, .instant669]
    private var renderKey: String { "\(settings.preset.rawValue)-\(settings.strength)-\(settings.texture)" }
    private var canSave: Bool { !working && rendered != nil && renderedKey == renderKey }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let base = framedPreview ?? InstantFrame.render(source)
                let aspect = base.size.width / max(1, base.size.height)
                // Restore the original 280pt preview width. Reserve the text
                // action's height so a smaller screen never overlaps the sliders.
                let availableHeight = max(1, geometry.size.height - (captionEditing ? 0 : 58))
                let imageWidth = min(280, max(1, geometry.size.width - 40), availableHeight * aspect)
                VStack(spacing: 20) {
                    CaptionCardEditor(image: base, caption: $caption) {
                        beginCaptionEditing()
                    }
                    .frame(width: imageWidth, height: imageWidth / aspect)
                    if !captionEditing {
                        Button(action: beginCaptionEditing) {
                            HStack(spacing: 10) {
                                Image(systemName: "pencil.line")
                                    .frame(width: 19, height: 16)
                                Text("Edit Text").frame(height: 22)
                            }
                                .font(.system(size: 17, design: .rounded))
                                .tracking(-0.43)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.10), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("editCaption")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Group {
                    if captionEditing {
                        HStack {
                            TextField("Write a memory…", text: $caption.text)
                                .font(.custom("Mynerve-Regular", size: 22))
                                .focused($captionFocused)
                                .onAppear { captionFocused = true }
                                .submitLabel(.done)
                                .onSubmit { finishCaptionEditing() }
                                .accessibilityLabel("Chữ trên khung Polaroid")
                            Button("Done") { finishCaptionEditing() }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    } else {
                        editingControls
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 22)
                .background(Color(white: 17 / 255))
            }
            .background(Color(white: 17 / 255).ignoresSafeArea())
            .navigationTitle("Edit Your Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.backward") }
                        .accessibilityLabel("Quay lại camera")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    saveButton
                }
            }
        }
        .padding(.top, 12)
        .background(Color(white: 17 / 255).ignoresSafeArea())
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .onAppear { caption = initialCaption ?? PhotoCaption(); scheduleRender() }
        .onChange(of: renderKey) { _, _ in scheduleRender() }
        .onDisappear { generation += 1; renderTask?.cancel() }
        .alert("Chưa xử lý được ảnh", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("Đóng", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }

    private var editingControls: some View {
        VStack(spacing: 16) {
            FilmAdjustmentSlider(title: "Cường Độ", value: $settings.strength)
            FilmAdjustmentSlider(title: "Chất Film", value: $settings.texture)
            GeometryReader { geometry in
                let cellWidth = geometry.size.width / CGFloat(presetOrder.count)
                let selectedIndex = presetOrder.firstIndex(of: settings.preset) ?? 0
                ZStack(alignment: .leading) {
                    // One persistent highlight moves beneath the buttons; no insertion/removal.
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: cellWidth, height: 48)
                        .offset(x: CGFloat(selectedIndex) * cellWidth)
                        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.86), value: selectedIndex)
                        .allowsHitTesting(false)
                    HStack(spacing: 0) {
                        ForEach(presetOrder) { preset in
                            Button {
                                guard settings.preset != preset else { return }
                                settings.preset = preset
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Text(preset == .timeZero ? "Old Day" : preset.title)
                                    .font(.system(size: 17, weight: settings.preset == preset ? .semibold : .regular, design: .rounded))
                                    .tracking(-0.43)
                                    .frame(width: cellWidth, height: 48)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("preset_\(preset.rawValue)")
                            .accessibilityAddTraits(settings.preset == preset ? .isSelected : [])
                        }
                    }
                }
            }
            .frame(height: 48)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder private var saveButton: some View {
        if #available(iOS 26.0, *) {
            Button(action: save) { Text("Save").foregroundStyle(.white) }
                .buttonStyle(.glassProminent).tint(Color(.systemBlue))
                .disabled(!canSave).accessibilityIdentifier("savePhoto")
        } else {
            Button(action: save) { Text("Save").foregroundStyle(.white) }
                .buttonStyle(.borderedProminent).tint(Color(.systemBlue))
                .clipShape(Capsule()).disabled(!canSave).accessibilityIdentifier("savePhoto")
        }
    }

    private func save() {
        guard canSave, let rendered else { return }
        do {
            try onSave(InstantFrame.render(rendered, caption: caption), settings, caption.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : caption)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch { self.error = error.localizedDescription }
    }

    private func beginCaptionEditing() {
        captionEditing = true
        captionFocused = true
    }

    private func finishCaptionEditing() {
        captionFocused = false
        captionEditing = false
    }

    private func scheduleRender() {
        generation += 1
        let current = generation, selected = settings, selectedKey = renderKey
        working = true
        renderTask?.cancel()
        renderTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(120))
                let image = try await FilmRenderer.shared.render(source, settings: selected)
                guard !Task.isCancelled, current == generation else { return }
                rendered = image
                framedPreview = InstantFrame.render(image)
                renderedKey = selectedKey
                working = false
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled, current == generation else { return }
                rendered = nil
                renderedKey = nil
                working = false
                self.error = error.localizedDescription
            }
        }
    }
}

/// Custom tick track with a native interactive glass thumb (iOS 26+).
private struct FilmAdjustmentSlider: View {
    let title: String
    @Binding var value: Double
    @State private var dragStartValue: Double?
    @GestureState private var isHolding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let thumbWidth: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, design: .rounded)).tracking(-0.23)
                .foregroundStyle(Color("Gray2"))
                .frame(height: 20)
            HStack(spacing: 16) {
                Text("\(Int((value * 100).rounded()))")
                    .font(.system(size: 16, weight: .semibold, design: .rounded)).monospacedDigit()
                    .tracking(-0.31)
                    .frame(width: 55, height: 29)
                    .background(Color.white.opacity(0.15), in: Capsule())
                GeometryReader { geometry in
                    let travel = max(1, geometry.size.width - thumbWidth)
                    ZStack(alignment: .leading) {
                        Canvas { context, size in
                            for index in 0..<28 {
                                let position = CGFloat(index) / 27
                                let x = 1.5 + position * (size.width - 3)
                                let distance = abs(Double(position) - value)
                                let height: CGFloat = distance < 0.045 ? 18 : distance < 0.08 ? 14 : distance < 0.12 ? 12 : 10
                                let rect = CGRect(x: x - 1.5, y: (size.height - height) / 2, width: 3, height: height)
                                context.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(.white.opacity(Double(position) <= value ? 1 : 0.15)))
                            }
                        }
                        .allowsHitTesting(false)
                        thumb
                            .offset(x: CGFloat(value) * travel)
                    }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .updating($isHolding) { _, holding, _ in holding = true }
                        .onChanged { event in
                            if dragStartValue == nil {
                                let thumbCenter = CGFloat(value) * travel + thumbWidth / 2
                                // Preserve the grab offset so touching the thumb never jumps the value.
                                dragStartValue = abs(event.startLocation.x - thumbCenter) <= 22
                                    ? value
                                    : min(1, max(0, Double((event.startLocation.x - thumbWidth / 2) / travel)))
                            }
                            value = min(1, max(0, (dragStartValue ?? value) + Double(event.translation.width / travel)))
                        }
                        .onEnded { _ in dragStartValue = nil })
                }
                .frame(height: 40)
            }
        }
        .onChange(of: isHolding) { _, holding in
            if !holding { dragStartValue = nil }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(Int((value * 100).rounded())) phần trăm")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(1, value + 0.01)
            case .decrement: value = max(0, value - 0.01)
            @unknown default: break
            }
        }
    }

    private var thumb: some View {
        glassThumb
            // Keep the track geometry fixed while the glass shape expands about its center.
            .frame(width: thumbWidth, height: 40)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.75), value: isHolding)
    }

    @ViewBuilder private var glassThumb: some View {
        if #available(iOS 26.0, *) {
            Capsule()
                .fill(.clear)
                .frame(width: isHolding ? 28 : thumbWidth, height: isHolding ? 48 : 40)
                .contentShape(Capsule())
                .glassEffect(.regular.interactive(), in: Capsule())
        } else {
            Capsule()
                .fill(.regularMaterial)
                .frame(width: isHolding ? 28 : thumbWidth, height: isHolding ? 48 : 40)
                .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
        }
    }

}

// Present a complete payload in one state change. A separate Boolean can
// open a modal before SwiftUI observes the image needed by its content.
private struct ImageEditorPresentation: Identifiable {
    let id = UUID()
    let source: UIImage
}

private struct ImageDetailPresentation: Identifiable {
    let photo: FilmPhoto
    let image: UIImage
    var id: UUID { photo.id }
}

struct GalleryScreen: View {
    @EnvironmentObject private var store: PhotoStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var settings: FilmSettings
    let importAspect: CGFloat
    @State private var selectedID: UUID?
    @State private var thumbnailID: UUID?
    @State private var picker: PhotosPickerItem?
    @State private var showPicker = false
    @State private var importing = false
    @State private var editor: ImageEditorPresentation?
    @State private var detail: ImageDetailPresentation?
    @State private var error: String?
    @State private var images: [UUID: UIImage] = [:]
    @State private var thumbnails: [UUID: UIImage] = [:]
    private let background = Color(white: 17 / 255)
    private var motion: Animation? { reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88) }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    if store.photos.isEmpty {
                        ContentUnavailableView {
                            Label("Your first photo", systemImage: "photo.stack")
                        } description: {
                            Text("Add an image or open the camera to start your collection.")
                        } actions: {
                            Button("Camera") { dismiss() }
                                .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // 66pt above and 99pt below the 409pt image stage in the design.
                        let stageHeight = min(409, max(120, geometry.size.height - 239))
                        let breathingRoom = max(48, geometry.size.height - stageHeight - 108)
                        Spacer(minLength: 0).frame(height: breathingRoom * 0.4)
                        photoCarousel(width: geometry.size.width, height: stageHeight)
                        Spacer(minLength: 0).frame(height: breathingRoom * 0.6)
                        thumbnailStrip(width: geometry.size.width)
                            .padding(.bottom, 44)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(background.ignoresSafeArea())
            .navigationTitle("")
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarLeading) { galleryTitle }
                        .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) { galleryTitle }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showPicker = true } label: { Label("Your Image", systemImage: "photo") }
                        Button { dismiss() } label: { Label("Camera", systemImage: "camera") }
                    } label: { Image(systemName: "plus") }
                    .disabled(importing)
                    .accessibilityLabel("Add photo")
                    .accessibilityIdentifier("galleryAdd")
                }
            }
            .sheet(item: $detail) { selection in
                DetailScreen(photo: selection.photo, image: selection.image)
            }
        }
        .padding(.top, 12)
        .background(background.ignoresSafeArea())
        .fontDesign(.rounded)
        .foregroundStyle(.white)
        .tint(.white)
        .preferredColorScheme(.dark)
        .photosPicker(isPresented: $showPicker, selection: $picker, matching: .images)
        .onChange(of: picker) { _, selected in
            guard let selected else { return }
            importing = true
            Task {
                defer { importing = false; picker = nil }
                do {
                    guard let data = try await selected.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { throw FilmError.renderFailed }
                    editor = ImageEditorPresentation(source: FilmEngine.normalized(image, aspect: importAspect))
                } catch { self.error = error.localizedDescription }
            }
        }
        .fullScreenCover(item: $editor) { session in
            PreviewScreen(source: session.source, settings: $settings) { image, selected, caption in
                try store.save(image, settings: selected, original: session.source, caption: caption)
                selectedID = store.photos.first?.id
                editor = nil
            }
        }
        .task(id: store.photos.map { "\($0.id)-\($0.revision ?? 0)" }) {
            // Decode display-sized copies once, never during a scroll frame.
            var loaded: [UUID: UIImage] = [:]
            var loadedThumbnails: [UUID: UIImage] = [:]
            for photo in store.photos {
                guard !Task.isCancelled else { return }
                let pair = await store.galleryImages(for: photo)
                if let pair {
                    loaded[photo.id] = pair.framed
                    loadedThumbnails[photo.id] = pair.thumbnail
                }
            }
            guard !Task.isCancelled else { return }
            images = loaded
            thumbnails = loadedThumbnails
            if selectedID == nil || !store.photos.contains(where: { $0.id == selectedID }) {
                selectedID = store.photos.first?.id
            }
            thumbnailID = selectedID
        }
        .onChange(of: selectedID) { _, id in
            withAnimation(motion) { thumbnailID = id }
        }
        .alert("Gallery", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("Đóng", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }

    private var galleryTitle: some View {
        Text("Gallery")
            .font(.system(size: 34, weight: .bold, design: .rounded))
            .tracking(0.4)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityAddTraits(.isHeader)
    }

    private func photoCarousel(width: CGFloat, height: CGFloat) -> some View {
        let cardWidth = min(304, max(1, width - 86))
        let cardSpacing: CGFloat = 16
        let stride = cardWidth + cardSpacing
        // Keep full-sized scroll targets for native paging, but bring the
        // neighboring cards into view. The visual offset is separate from
        // the spacing between native scroll targets.
        let visibleStride = min(stride, max(cardWidth * 0.75 + 16,
                                           width / 2 + cardWidth * 0.25 - 28))
        let reduceMotion = reduceMotion
        return ScrollView(.horizontal) {
            LazyHStack(spacing: cardSpacing) {
                ForEach(store.photos) { photo in
                    Group {
                        if let image = images[photo.id] {
                            TiltCard(image: image, enabled: selectedID == photo.id) { openDetail(photo) }
                        } else {
                            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(width: cardWidth, height: height)
                    .visualEffect { content, geometry in
                        let distance = geometry.frame(in: .named("galleryCarouselViewport")).midX - width / 2
                        let position = min(1, max(-1, distance / stride))
                        let progress = abs(position)
                        // Read the stationary layout frame, not selectedID or
                        // the transformed image. Scale and position follow the
                        // same continuous distance, including between pages.
                        return content
                            .scaleEffect(1 - progress * 0.6)
                            .rotationEffect(.degrees(reduceMotion ? 0 : Double(position) * 6))
                            .offset(x: -position * (stride - visibleStride))
                            .opacity(1 - Double(progress) * 0.35)
                    }
                    .contentShape(Rectangle())
                    .id(photo.id)
                    .accessibilityLabel("Ảnh \(photo.settings.preset.title)")
                    .accessibilityAddTraits(selectedID == photo.id ? .isSelected : [])
                }
            }
            .scrollTargetLayout()
        }
        .coordinateSpace(name: "galleryCarouselViewport")
        .contentMargins(.horizontal, max(0, (width - cardWidth) / 2), for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $selectedID, anchor: .center)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .frame(height: height)
        .overlay { edgeFade(width: 48) }
        .accessibilityIdentifier("galleryCarousel")
    }

    private func thumbnailStrip(width: CGFloat) -> some View {
        let reduceMotion = reduceMotion
        return ScrollView(.horizontal) {
            LazyHStack(spacing: 19) {
                ForEach(store.photos) { photo in
                    Button {
                        withAnimation(motion) { selectedID = photo.id; thumbnailID = photo.id }
                    } label: {
                        Group {
                            if let image = thumbnails[photo.id] {
                                Image(uiImage: image).resizable().scaledToFill()
                            } else { Color(.systemGray) }
                        }
                        .frame(width: 48, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .visualEffect { content, geometry in
                        // Measure the untouched layout in the viewport, not the
                        // transformed image. A single signed distance drives
                        // both scale and perspective continuously while scrolling.
                        let distance = geometry.frame(in: .named("galleryThumbnailViewport")).midX - width / 2
                        let position = max(-1, min(1, distance / max(1, width / 2)))
                        let depth = abs(position)
                        return content
                            .scaleEffect(reduceMotion ? 1 : 1 - depth * 0.24)
                            .rotation3DEffect(.degrees(reduceMotion ? 0 : -position * 65),
                                              axis: (x: 0, y: 1, z: 0), perspective: 0.65)
                    }
                    .id(photo.id)
                    .accessibilityLabel("Chọn ảnh \(photo.settings.preset.title)")
                    .accessibilityAddTraits(selectedID == photo.id ? .isSelected : [])
                }
            }
            .scrollTargetLayout()
        }
        .coordinateSpace(name: "galleryThumbnailViewport")
        .contentMargins(.horizontal, max(0, (width - 48) / 2), for: .scrollContent)
        .scrollPosition(id: $thumbnailID, anchor: .center)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .frame(height: 64)
        .overlay { edgeFade(width: min(172, width / 2)) }
        .accessibilityIdentifier("galleryThumbnails")
    }

    private func edgeFade(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [background, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: width)
            Spacer(minLength: 0)
            LinearGradient(colors: [.clear, background], startPoint: .leading, endPoint: .trailing)
                .frame(width: width)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func openDetail(_ photo: FilmPhoto) {
        guard let image = store.image(for: photo) else {
            error = "Không đọc được ảnh này."
            return
        }
        detail = ImageDetailPresentation(photo: photo, image: image)
    }
}

struct DetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PhotoStore
    let photo: FilmPhoto
    let image: UIImage
    @State private var editedPhoto: FilmPhoto?
    @State private var editedImage: UIImage?
    @State private var confirmDelete = false
    @State private var saving = false
    @State private var notice: String?
    @State private var editor: ImageEditorPresentation?
    @State private var editingSettings = FilmSettings()
    private var currentPhoto: FilmPhoto { editedPhoto ?? photo }
    private var currentImage: UIImage { editedImage ?? image }
    private var canEdit: Bool { store.hasOriginal(for: currentPhoto) }
    private let background = Color(.secondarySystemBackground)
    // Figma's Gray 2 is fixed #AEAEB2, not systemGray2's darker
    // dark-mode variant. Date and film settings share this design token.
    private let metadataColor = Color("Gray2")

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // The reference's 304x409 image slot includes the sample
                        // asset's surrounding whitespace. Keep the actual paper
                        // within 240x359 and preserve each saved image's aspect.
                        Image(uiImage: currentImage).resizable().scaledToFit()
                            .frame(maxWidth: 240, maxHeight: 359)
                            .frame(width: min(304, geometry.size.width - 40), height: 409)
                            .accessibilityLabel("Ảnh Polaroid")
                        metadata
                        Spacer(minLength: 24)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actions.padding(.leading, 20).padding(.trailing, 12)
                    .padding(.top, 12).padding(.bottom, 22)
                    .background(background)
            }
            .background(background)
            .navigationTitle("Image Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Image Detail")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(white: 245 / 255))
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .foregroundStyle(Color(white: 245 / 255))
                        .accessibilityLabel("Close Image Detail")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .fontDesign(.rounded)
        .foregroundStyle(.white)
        .tint(.white)
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(background)
        .presentationCornerRadius(38)
        .confirmationDialog("Delete image?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                do { try store.delete(currentPhoto); dismiss() }
                catch { notice = error.localizedDescription }
            }
        } message: {
            Text("This removes the image from this app’s Gallery. Copies saved to Photos stay on your device.")
        }
        .alert("Image Detail", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("OK") { notice = nil }
        } message: { Text(notice ?? "") }
        .fullScreenCover(item: $editor) { session in
            PreviewScreen(source: session.source, settings: $editingSettings, initialCaption: currentPhoto.caption) { rendered, selected, caption in
                try store.update(currentPhoto, image: rendered, settings: selected, caption: caption)
                editedPhoto = store.photos.first { $0.id == currentPhoto.id }
                editedImage = rendered
                editor = nil
            }
        }
    }

    private var metadata: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text(dateLabel("HH:mm"))
                separator
                Text(dateLabel("dd-MM-yyyy"))
            }
            .font(.system(size: 15, design: .rounded)).tracking(-0.23)
            .foregroundStyle(metadataColor)
            .frame(height: 20)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.white.opacity(0.1), in: Capsule())
            VStack(spacing: 10) {
                Text("Preset: \(currentPhoto.settings.preset.title)")
                    .font(.system(size: 22, weight: .bold, design: .rounded)).tracking(-0.26)
                    .foregroundStyle(.white)
                    .frame(height: 28)
                HStack(spacing: 12) {
                    Text("Cường độ: \(Int((currentPhoto.settings.strength * 100).rounded()))%")
                    separator
                    Text("Chất Film: \(Int((currentPhoto.settings.texture * 100).rounded()))%")
                }
                .font(.system(size: 15, design: .rounded)).tracking(-0.23)
                .foregroundStyle(metadataColor)
                .frame(height: 20)
            }
        }
    }

    private var separator: some View {
        Rectangle().fill(Color(.systemGray)).frame(width: 1, height: 16)
            .accessibilityHidden(true)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            detailButton(action: { confirmDelete = true }, tint: Color(red: 1, green: 56 / 255, blue: 60 / 255)) {
                Image(systemName: "trash").frame(width: 48)
            }
            .disabled(saving).accessibilityLabel("Delete image")
            detailButton(action: openEditor) {
                Image(systemName: "square.and.pencil").frame(width: 48)
            }
            .disabled(!canEdit || saving).accessibilityLabel("Edit image")
            .accessibilityHint(canEdit ? "" : "The original image is unavailable for this older photo.")
            detailButton(action: saveToDevice) {
                Text(saving ? "Saving…" : "Save To Device").frame(maxWidth: .infinity)
            }
            .disabled(saving).accessibilityIdentifier("saveToDevice")
        }
    }

    private func dateLabel(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: currentPhoto.date)
    }

    private func openEditor() {
        guard let original = store.original(for: currentPhoto) else {
            notice = "The original image is unavailable for this older photo."
            return
        }
        editingSettings = currentPhoto.settings
        editor = ImageEditorPresentation(source: original)
    }

    private func saveToDevice() {
        guard !saving else { return }
        saving = true
        let savedImage = currentImage
        let capturedDate = currentPhoto.date
        Task { @MainActor in
            defer { saving = false }
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                notice = "Allow this app to add photos in iPhone Settings, then try again."
                return
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    let request = PHAssetChangeRequest.creationRequestForAsset(from: savedImage)
                    request.creationDate = capturedDate
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                notice = "Saved to Photos."
            } catch { notice = error.localizedDescription }
        }
    }

    @ViewBuilder
    private func detailButton<Label: View>(action: @escaping () -> Void, tint: Color = .white,
                                           @ViewBuilder label: () -> Label) -> some View {
        if #available(iOS 26, *) {
            Button(action: action) {
                label().font(.system(size: 17, weight: .semibold, design: .rounded))
                    .tracking(-0.43).frame(height: 48)
            }
            .buttonStyle(.plain)
            .foregroundStyle(tint)
            .glassEffect(.regular.tint(tint == .white ? .clear : tint.opacity(0.2)).interactive(), in: Capsule())
        } else {
            Button(action: action) {
                label().font(.system(size: 17, weight: .semibold, design: .rounded))
                    .tracking(-0.43).frame(height: 48)
            }
            .buttonStyle(.plain).foregroundStyle(tint)
            .background(tint == .white ? Color.white.opacity(0.1) : tint.opacity(0.2), in: Capsule())
        }
    }
}

struct AboutScreen: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Polaroid vibe.").font(.system(size: 29, weight: .bold, design: .rounded))
                    Text("Một nơi nhỏ cho những khoảnh khắc đáng giữ.")
                    Text("Bản thử Camera UI").foregroundStyle(.secondary)
                }
                Section("Cách thử") {
                    Text("Chụp bằng camera iPhone hoặc chọn ảnh có sẵn. Đổi film, chỉnh màu, rồi lưu vào bộ sưu tập.")
                    Text("Ảnh được xử lý trên máy theo tỉ lệ đã chọn, giới hạn cạnh dài 1600 px. Bộ sưu tập lưu riêng trong app.")
                    Text("Màu dùng LUT gốc. Lớp chất film native đang là bản thử, có thể khác bản web.")
                }
                Section("Bộ màu") {
                    Text("PictureFX SX-70 — Marc Roovers / PictureFX")
                    Text("669, PX-70, Time Zero — Pat David / G’MIC, CC BY-SA 4.0")
                }
            }.navigationTitle("Về vibe.").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Xong") { dismiss() } } }
        }.presentationDragIndicator(.visible)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
