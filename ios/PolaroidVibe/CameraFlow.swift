import SwiftUI
import PhotosUI
import AVFoundation

// Photo proportions match the film formats, independently of the SF Symbol artwork.
enum PhotoRatio: String, CaseIterable, Identifiable {
    case portrait, square, landscape
    var id: String { rawValue }
    var aspect: CGFloat {
        switch self { case .portrait: return 23 / 31; case .square: return 1; case .landscape: return 99 / 62 }
    }
    var symbol: String {
        switch self { case .portrait: return "rectangle.portrait"; case .square: return "square"; case .landscape: return "rectangle" }
    }
    var label: String {
        switch self { case .portrait: return "Dọc"; case .square: return "Vuông"; case .landscape: return "Ngang" }
    }
}

private enum CameraColors {
    static let background = Color(white: 17 / 255)
    static let viewfinder = Color(white: 43 / 255)
    static let yellow = Color(red: 1, green: 0.8, blue: 0)
}

private struct CameraGlass<S: Shape>: ViewModifier {
    var shape: S
    var active = false
    var interactive = true
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(active ? CameraColors.yellow.opacity(0.18) : .clear).interactive(interactive), in: shape)
        } else {
            content.background(.regularMaterial, in: shape)
        }
    }
}

private struct CameraGlassGroup<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        if #available(iOS 26.0, *) { GlassEffectContainer(spacing: 12, content: content) }
        else { content() }
    }
}

struct CameraScreen: View {
    @EnvironmentObject private var store: PhotoStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var capture = NativeCamera()
    @State private var settings = FilmSettings()
    @State private var ratio: PhotoRatio = .square
    @State private var draftRatio: PhotoRatio = .square
    @State private var choosingRatio = false
    @State private var choosingPreset = false
    @State private var flash = false
    @State private var grid = false
    @State private var zoom: CGFloat = 1
    @State private var picker: PhotosPickerItem?
    @State private var source = FilmEngine.sampleImage
    @State private var preview = false
    @State private var gallery = false
    @State private var showGalleryAfterPreview = false
    @State private var samplePreview: UIImage?
    @State private var samplePreset: String = ""
    @State private var importing = false
    @State private var error: String?
    private let presetOrder: [FilmPreset] = [.px70, .sx70, .timeZero, .instant669]
    private var visibleRatio: PhotoRatio { choosingRatio ? draftRatio : ratio }
    private var previewIsMock: Bool { ProcessInfo.processInfo.arguments.contains("-camera-mock") || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil }
    private var frameBottomGap: CGFloat {
        choosingPreset ? 32 : visibleRatio == .square ? 28 : visibleRatio == .landscape ? 15 : 0
    }
    private let headerHeight: CGFloat = 87 // 19 top + 48 button + 20 breathing room.
    private var controlsHeight: CGFloat { choosingPreset ? 173 : 155 }
    private var previewKey: String { "\(settings.preset.rawValue)-\(settings.strength)-\(settings.texture)-\(visibleRatio.rawValue)" }
    private var useSample: Bool { ProcessInfo.processInfo.arguments.contains("-camera-sample") }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack {
                    Button {
                        if choosingRatio { choosingRatio = false }
                        else if choosingPreset { choosingPreset = false }
                        else { gallery = true }
                    } label: { Image(systemName: "chevron.backward").font(.system(size: 19, weight: .semibold, design: .rounded)).frame(width: 48, height: 48) }
                    .modifier(CameraGlass(shape: Circle()))
                    .accessibilityLabel("Quay về bộ sưu tập").accessibilityIdentifier("cameraBack")
                    Spacer()
                }.frame(height: 48).padding(.horizontal, 16).padding(.top, 19).padding(.bottom, 20)
                // Fit the photo between the toolbar and controls without consuming either gap.
                viewfinder(available: CGSize(width: geometry.size.width - 40,
                                            height: max(1, geometry.size.height - headerHeight - controlsHeight - frameBottomGap)))
                    .padding(.bottom, frameBottomGap)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                CameraGlassGroup {
                    VStack(spacing: choosingPreset ? 17 : 19) {
                        HStack {
                            quickControls
                            Spacer(minLength: 0)
                            if choosingPreset { shutter }
                            Spacer(minLength: 0)
                            formatControls
                        }.frame(height: choosingPreset ? 80 : 44)
                        HStack(alignment: .center) {
                            if choosingRatio {
                                sideButton("xmark", label: "Hủy tỉ lệ", id: "cancelRatio", leading: true) { choosingRatio = false }
                                Spacer(minLength: 8)
                                ratioPicker
                                Spacer(minLength: 8)
                                sideButton("checkmark", label: "Áp dụng tỉ lệ", id: "confirmRatio", leading: false) {
                                    ratio = draftRatio; choosingRatio = false
                                }
                            } else {
                                PhotosPicker(selection: $picker, matching: .images) {
                                    Image(systemName: "photo").font(.system(size: 27, design: .rounded)).frame(width: 64, height: 64)
                                }.modifier(CameraGlass(shape: sideShape(leading: true)))
                                    .accessibilityLabel("Chọn ảnh").accessibilityIdentifier("importPhoto").disabled(importing)
                                Spacer(minLength: 8)
                                if choosingPreset { presetPicker.frame(width: max(1, min(186, geometry.size.width - 184))) }
                                else { shutter }
                                Spacer(minLength: 8)
                                sideButton("camera.filters", label: "Chọn preset", id: "choosePreset", leading: false, active: choosingPreset) {
                                    choosingPreset.toggle()
                                }
                            }
                        }.frame(height: choosingPreset ? 64 : 80)
                    }
                }.padding(.horizontal, 20).padding(.bottom, 12)
            }
            .foregroundStyle(.white).background(CameraColors.background)
        }
        .background(CameraColors.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .animation(.smooth(duration: 0.3), value: choosingRatio)
        .animation(.smooth(duration: 0.3), value: choosingPreset)
        .animation(.smooth(duration: 0.3), value: visibleRatio)
        .task { if !previewIsMock && !useSample { capture.start() } }
        .task(id: previewKey) {
            capture.setFilmSettings(settings)
            guard useSample else { return }
            let selected = settings
            let input = FilmEngine.normalized(FilmEngine.sampleImage, maxEdge: 640, aspect: visibleRatio.aspect)
            do {
                let rendered = try await FilmRenderer.shared.render(input, settings: selected)
                guard !Task.isCancelled else { return }
                samplePreview = rendered; samplePreset = selected.preset.title
            } catch { self.error = error.localizedDescription }
        }
        .onDisappear { capture.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !preview && !gallery && !previewIsMock && !useSample { capture.start() }
            else { capture.stop() }
        }
        .onChange(of: preview) { _, showing in updateCameraVisibility(showing || gallery) }
        .onChange(of: gallery) { _, showing in updateCameraVisibility(showing || preview) }
        .fullScreenCover(isPresented: $preview, onDismiss: {
            if showGalleryAfterPreview { showGalleryAfterPreview = false; gallery = true }
        }) {
            PreviewScreen(source: source, settings: $settings) { image, selected, caption in
                try store.save(image, settings: selected, original: source, caption: caption)
                showGalleryAfterPreview = true; preview = false
            }
        }
        .fullScreenCover(isPresented: $gallery) { GalleryScreen(settings: $settings, importAspect: ratio.aspect).environmentObject(store) }
        .onChange(of: picker) { _, selected in
            guard let selected else { return }
            importing = true
            let selectedRatio = ratio
            Task {
                defer { importing = false; picker = nil }
                do {
                    guard let data = try await selected.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw FilmError.renderFailed }
                    source = FilmEngine.normalized(image, aspect: selectedRatio.aspect); preview = true
                } catch { self.error = error.localizedDescription }
            }
        }
        .alert("Camera", isPresented: Binding(get: { error != nil || capture.error != nil }, set: { if !$0 { error = nil; capture.error = nil } })) {
            Button("Đóng", role: .cancel) { error = nil; capture.error = nil }
        } message: { Text(error ?? capture.error ?? "") }
    }

    private func updateCameraVisibility(_ covered: Bool) {
        if covered { capture.stop() }
        else if scenePhase == .active && !previewIsMock && !useSample { capture.start() }
    }

    private func viewfinder(available: CGSize) -> some View {
        let width = min(max(1, available.width), available.height * visibleRatio.aspect)
        let height = width / visibleRatio.aspect
        return ZStack {
            CameraColors.viewfinder
            if useSample {
                Image(uiImage: samplePreview ?? source).resizable().scaledToFill().frame(width: width, height: height).clipped()
            } else if !previewIsMock, let image = capture.previewImage {
                Image(uiImage: image).resizable().scaledToFill().frame(width: width, height: height).clipped()
            }
            if grid {
                Canvas { context, size in
                    var path = Path()
                    for fraction in [CGFloat(1 / 3.0), CGFloat(2 / 3.0)] {
                        path.move(to: CGPoint(x: size.width * fraction, y: 0)); path.addLine(to: CGPoint(x: size.width * fraction, y: size.height))
                        path.move(to: CGPoint(x: 0, y: size.height * fraction)); path.addLine(to: CGPoint(x: size.width, y: size.height * fraction))
                    }
                    context.stroke(path, with: .color(.white.opacity(0.4)), lineWidth: 0.5)
                }.allowsHitTesting(false).accessibilityHidden(true)
            }
            if capture.denied {
                VStack(spacing: 14) {
                    Image(systemName: "camera.fill").font(.largeTitle)
                    Text("Cho phép Camera để chụp ảnh").font(.system(.subheadline, design: .rounded)).multilineTextAlignment(.center)
                    Button("Mở Cài đặt") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }.buttonStyle(.bordered)
                }.padding()
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 31))
        .accessibilityElement(children: .contain).accessibilityIdentifier("cameraViewfinder")
        .accessibilityValue(useSample ? samplePreset : capture.previewPreset)
    }

    private var quickControls: some View {
        HStack(spacing: 4) {
            Button { flash.toggle(); UISelectionFeedbackGenerator().selectionChanged() } label: {
                Image(systemName: "bolt.fill").font(.system(size: 20, design: .rounded)).foregroundStyle(flash ? CameraColors.yellow : .white)
                    .frame(width: 36, height: 36)
            }.accessibilityLabel("Flash").accessibilityValue(flash ? "Bật" : "Tắt").accessibilityIdentifier("toggleFlash")
            Button { grid.toggle(); UISelectionFeedbackGenerator().selectionChanged() } label: {
                Image(systemName: "square.grid.3x3").font(.system(size: 18, design: .rounded)).foregroundStyle(grid ? CameraColors.yellow : .white)
                    .frame(width: 36, height: 36)
            }.accessibilityLabel("Lưới").accessibilityValue(grid ? "Bật" : "Tắt").accessibilityIdentifier("toggleGrid")
        }.buttonStyle(.plain).padding(4).modifier(CameraGlass(shape: Capsule()))
    }

    private var formatControls: some View {
        HStack(spacing: 4) {
            Button { draftRatio = ratio; choosingPreset = false; choosingRatio.toggle() } label: {
                Image(systemName: visibleRatio.symbol).font(.system(size: 18, weight: .medium, design: .rounded)).frame(width: 36, height: 36)
            }.accessibilityLabel("Chọn tỉ lệ ảnh").accessibilityIdentifier("chooseRatio")
            Button { zoom = zoom == 1 ? 2 : 1; capture.setZoom(zoom) } label: {
                Text(zoom == 1 ? "1x" : "2x").font(.system(size: 15, weight: .semibold, design: .rounded)).frame(width: 36, height: 36)
            }.accessibilityLabel("Thu phóng").accessibilityValue(zoom == 1 ? "1x" : "2x").accessibilityIdentifier("toggleZoom")
        }.buttonStyle(.plain).padding(4).modifier(CameraGlass(shape: Capsule()))
    }

    private var shutter: some View {
        Button {
            let selectedRatio = ratio
            if previewIsMock || useSample || !UIImagePickerController.isSourceTypeAvailable(.camera) {
                source = FilmEngine.normalized(FilmEngine.sampleImage, aspect: selectedRatio.aspect); preview = true
            } else {
                capture.takePhoto(flash: flash) { image in
                    source = FilmEngine.normalized(image, aspect: selectedRatio.aspect); preview = true
                }
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            VStack(spacing: 4) {
                ForEach(0..<2, id: \.self) { _ in
                    HStack(spacing: 4) { ForEach(0..<3, id: \.self) { _ in Image("ShutterDot").resizable().frame(width: 6, height: 6) } }
                }
            }.accessibilityHidden(true)
                .frame(width: 62, height: 62)
                .background(LinearGradient(colors: [Color(red: 1, green: 1, blue: 0.894), Color(white: 0.694)], startPoint: .top, endPoint: .bottom), in: Circle())
                .padding(9)
        }.buttonStyle(.plain).modifier(CameraGlass(shape: Circle()))
            .disabled(capture.takingPhoto || importing || (!capture.ready && !previewIsMock && !useSample && UIImagePickerController.isSourceTypeAvailable(.camera)))
            .accessibilityLabel("Chụp ảnh").accessibilityIdentifier("shutter")
    }

    private var ratioPicker: some View {
        HStack(spacing: 4) {
            ForEach(PhotoRatio.allCases) { item in
                Button {
                    draftRatio = item
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Group {
                        if item == .portrait {
                            Image("RatioPortrait").resizable().frame(width: 16, height: 24)
                        } else {
                            RoundedRectangle(cornerRadius: 4.571)
                                .strokeBorder(.white, lineWidth: 1.714)
                                .frame(width: item == .square ? 16 : 24, height: 16)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(draftRatio == item ? Color.white.opacity(0.15) : .clear, in: Circle())
                    .contentShape(Circle())
                }.buttonStyle(.plain)
                    .accessibilityLabel(item.label).accessibilityIdentifier("ratio_\(item.rawValue)")
                    .accessibilityAddTraits(draftRatio == item ? .isSelected : [])
            }
        }.padding(4)
            .modifier(CameraGlass(shape: Capsule(), interactive: false))
            .accessibilityElement(children: .contain)
    }

    private var presetPicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(presetOrder) { preset in
                        Button { settings.preset = preset; UISelectionFeedbackGenerator().selectionChanged() } label: {
                            Text(preset.title).font(.system(size: 16, weight: settings.preset == preset ? .semibold : .regular, design: .rounded))
                                .tracking(-0.31).fixedSize()
                                .padding(.horizontal, 16).frame(height: 48)
                                .background(settings.preset == preset ? Color.white.opacity(0.15) : .clear, in: Capsule())
                        }.buttonStyle(.plain).id(preset.id).accessibilityIdentifier("preset_\(preset.rawValue)")
                            .accessibilityAddTraits(settings.preset == preset ? .isSelected : [])
                    }
                }.padding(.vertical, 4)
            }.frame(height: 56)
                // Fade the scrolling content while keeping the glass shell continuous.
                .mask {
                    HStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .white], startPoint: .leading, endPoint: .trailing).frame(width: 60)
                        Rectangle().fill(.white)
                        LinearGradient(colors: [.white, .clear], startPoint: .leading, endPoint: .trailing).frame(width: 60)
                    }
                }
                .modifier(CameraGlass(shape: Capsule(), interactive: false))
                .onAppear { proxy.scrollTo(settings.preset.id, anchor: .center) }
                .onChange(of: settings.preset) { _, preset in withAnimation { proxy.scrollTo(preset.id, anchor: .center) } }
        }
    }

    private func sideShape(leading: Bool) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: leading ? 40 : 16,
                               bottomTrailingRadius: leading ? 16 : 40, topTrailingRadius: 16)
    }
    private func sideButton(_ symbol: String, label: String, id: String, leading: Bool, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: symbol == "camera.filters" ? 27 : 20, weight: .medium, design: .rounded))
                .foregroundStyle(active || symbol == "checkmark" ? CameraColors.yellow : .white).frame(width: 64, height: 64)
        }.buttonStyle(.plain).modifier(CameraGlass(shape: sideShape(leading: leading), active: active))
            .accessibilityLabel(label).accessibilityIdentifier(id)
    }
}

/// AVFoundation owns the camera; session changes stay off the main thread.
final class NativeCamera: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "vibe.camera.session")
    private let output = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let previewQueue = DispatchQueue(label: "vibe.camera.preview", qos: .userInitiated)
    private let previewEngine = FilmEngine()
    private var filmSettings = FilmSettings()
    private var lastPreviewTime = -Double.infinity
    @Published var previewImage: UIImage?
    @Published var previewPreset = ""
    private var device: AVCaptureDevice?
    private var configured = false
    private var wantsRunning = false
    private var zoom: CGFloat = 1
    private var completion: ((UIImage) -> Void)?
    @Published var ready = false
    @Published var denied = false
    @Published var takingPhoto = false
    @Published var error: String?

    func start() {
        queue.async { self.wantsRunning = true }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
                if allowed { self?.configureAndStart() }
                else { DispatchQueue.main.async { self?.denied = true } }
            }
        default: denied = true
        }
    }
    private func configureAndStart() {
        queue.async {
            guard self.wantsRunning else { return }
            do {
                if !self.configured {
                    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
                    let input = try AVCaptureDeviceInput(device: device)
                    self.session.beginConfiguration()
                    self.session.sessionPreset = .photo
                    guard self.session.canAddInput(input), self.session.canAddOutput(self.output) else {
                        self.session.commitConfiguration(); throw FilmError.renderFailed
                    }
                    self.session.addInput(input); self.session.addOutput(self.output)
                    guard self.session.canAddOutput(self.videoOutput) else {
                        self.session.commitConfiguration(); throw FilmError.renderFailed
                    }
                    self.videoOutput.alwaysDiscardsLateVideoFrames = true
                    self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                    self.videoOutput.setSampleBufferDelegate(self, queue: self.previewQueue)
                    self.session.addOutput(self.videoOutput)
                    if let connection = self.videoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                        connection.videoRotationAngle = 90
                    }
                    self.session.commitConfiguration()
                    self.device = device; self.configured = true
                    if let connection = self.output.connection(with: .video), connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
                }
                if !self.session.isRunning { self.session.startRunning() }
                DispatchQueue.main.async { self.ready = true; self.denied = false }
            } catch { DispatchQueue.main.async { self.error = error.localizedDescription } }
        }
    }
    func stop() { queue.async { self.wantsRunning = false; if self.session.isRunning { self.session.stopRunning() } } }
    func setZoom(_ factor: CGFloat) {
        queue.async {
            self.zoom = factor
            guard let device = self.device else { return }
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = min(max(factor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
                device.unlockForConfiguration()
            } catch { DispatchQueue.main.async { self.error = error.localizedDescription } }
        }
    }
    func setFilmSettings(_ settings: FilmSettings) {
        previewQueue.async { self.filmSettings = settings; self.lastPreviewTime = -Double.infinity }
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        guard time - lastPreviewTime >= 1.0 / 15, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastPreviewTime = time
        autoreleasepool {
            let input = CIImage(cvPixelBuffer: buffer)
            let scale = min(1, 640 / max(input.extent.width, input.extent.height))
            let selected = filmSettings
            do {
                let image = try previewEngine.render(input.transformed(by: CGAffineTransform(scaleX: scale, y: scale)), settings: selected)
                DispatchQueue.main.async { self.previewImage = image; self.previewPreset = selected.preset.title }
            } catch {
                DispatchQueue.main.async { self.error = error.localizedDescription }
            }
        }
    }
    func takePhoto(flash: Bool, completion: @escaping (UIImage) -> Void) {
        guard !takingPhoto else { return }
        takingPhoto = true; self.completion = completion
        queue.async {
            guard self.session.isRunning else { DispatchQueue.main.async { self.takingPhoto = false; self.error = "Camera chưa sẵn sàng." }; return }
            let settings = AVCapturePhotoSettings()
            if self.device?.hasFlash == true { settings.flashMode = flash ? .on : .off }
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        DispatchQueue.main.async {
            self.takingPhoto = false
            if let image { self.completion?(image) }
            else { self.error = error?.localizedDescription ?? "Chưa chụp được ảnh. Thử lại nhé." }
            self.completion = nil
        }
    }
}

