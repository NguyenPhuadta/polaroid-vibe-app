import SwiftUI
import QuartzCore

// SwiftUI adaptation of Bencho's Tilt card (MIT): https://bencho.dev/licence
// Uses the project's saved photograph, rather than Bencho's unlicensed pictures.
struct TiltCard: View {
    let image: UIImage
    let enabled: Bool
    var onTap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pose = TiltPose.zero

    var body: some View {
        GeometryReader { geometry in
            let aspect = image.size.width / max(1, image.size.height)
            let width = min(geometry.size.width, geometry.size.height * aspect)
            let height = width / aspect
            // The frame never moves. Measuring the rotating card would ask a
            // surface that has turned away where the finger originally landed.
            ZStack {
                Image(uiImage: image).resizable().scaledToFit()
                    .modifier(TiltSurface(pose: pose))
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .overlay {
                TiltTouchSurface(enabled: enabled && !reduceMotion, onTap: onTap) { location in
                    guard let location else { settle(to: .zero); return }
                    settle(to: TiltPose(
                        x: min(100, max(-100, (location.x / width * 2 - 1) * 100)),
                        y: min(100, max(-100, (location.y / height * 2 - 1) * 100)),
                        amount: 100
                    ))
                }
                .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onTap() }
            .onChange(of: enabled) { _, active in
                if !active { settle(to: .zero) }
            }
            .onChange(of: reduceMotion) { _, _ in settle(to: .zero) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func settle(to target: TiltPose) {
        // One spring, for everything that settles. Position, sheen and shadow
        // share an animatable value instead of three independent transitions.
        // Native springs keep velocity when retargeted and need no permanent rAF.
        withAnimation(reduceMotion ? nil : .interpolatingSpring(stiffness: 180, damping: 16)) {
            pose = reduceMotion ? .zero : target
        }
    }
}

private struct TiltPose {
    var x: Double
    var y: Double
    var amount: Double
    static let zero = TiltPose(x: 0, y: 0, amount: 0)
}

private struct TiltSurface: AnimatableModifier {
    var pose: TiltPose
    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, Double> {
        get { .init(.init(pose.x, pose.y), pose.amount) }
        set { pose = TiltPose(x: newValue.first.first, y: newValue.first.second, amount: newValue.second) }
    }

    func body(content: Content) -> some View {
        let sx = pose.x / 100
        let sy = pose.y / 100
        let lit = min(1, max(0, pose.amount / 100))
        let point = UnitPoint(x: (sx + 1) / 2, y: (sy + 1) / 2)
        let opposite = UnitPoint(x: 1 - point.x, y: 1 - point.y)
        content
            .overlay {
                GeometryReader { geometry in
                    // The dent follows the finger; the rim catches light on
                    // the opposite side. Both are percentages, never pixels,
                    // so portrait, square and landscape share the same feel.
                    EllipticalGradient(colors: [.black.opacity(0.16 * lit), .clear],
                        center: point, startRadiusFraction: 0, endRadiusFraction: 0.48)
                    EllipticalGradient(colors: [.white.opacity(0.10 * lit), .clear],
                        center: opposite, startRadiusFraction: 0, endRadiusFraction: 0.58)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            // The shadow TIGHTENS. A pressed card has less air beneath it;
            // growing the shadow would imply lifting and fight the other cues.
            .shadow(color: .black.opacity(0.28 - 0.08 * lit),
                    radius: 1.5, x: 0, y: 2 - lit)
            .shadow(color: .black.opacity(0.22 - 0.07 * lit),
                    radius: 22 - 10 * lit, x: 0, y: 20 - 11 * lit)
            .modifier(TiltProjection(sx: sx, sy: sy, lit: lit))
    }

}

private struct TiltProjection: GeometryEffect {
    let sx: Double
    let sy: Double
    let lit: Double

    func effectValue(size: CGSize) -> ProjectionTransform {
        // 800 against a ~320pt card is about two and a half card heights back:
        // visible foreshortening without making ten degrees look like thirty.
        var transform = CATransform3DIdentity
        transform.m34 = -1 / 800
        // Translate FIRST: retreat is in the room's axes, not the tilted card's.
        // 14pt is deliberately small; past twenty a press starts reading as zoom.
        transform = CATransform3DTranslate(transform, 0, 0, -14 * lit)
        // IT SINKS, IT DOES NOT LIFT. Top -> positive X, right -> positive Y.
        // The Polaroid rests upright; only holding and dragging applies tilt.
        transform = CATransform3DRotate(transform, -sy * 10 * .pi / 180, 1, 0, 0)
        transform = CATransform3DRotate(transform, sx * 10 * .pi / 180, 0, 1, 0)
        // Rotate about the photo centre, not the top-left origin. The outer
        // untransformed gesture frame remains the source of pointer coordinates.
        let toOrigin = CATransform3DMakeTranslation(-size.width / 2, -size.height / 2, 0)
        let toCentre = CATransform3DMakeTranslation(size.width / 2, size.height / 2, 0)
        return ProjectionTransform(CATransform3DConcat(CATransform3DConcat(toOrigin, transform), toCentre))
    }
}

// A fixed UIKit touch surface owns tap and hold together. A SwiftUI priority
// gesture inside a Button can consume its tap, and changing scrollDisabled
// during the hold can cancel the very gesture responsible for unlocking it.
private struct TiltTouchSurface: UIViewRepresentable {
    var enabled: Bool
    var onTap: () -> Void
    var onPosition: (CGPoint?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let hold = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.hold(_:)))
        hold.minimumPressDuration = 0.3
        hold.allowableMovement = 10
        hold.delegate = context.coordinator
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:)))
        tap.delegate = context.coordinator
        tap.require(toFail: hold)
        view.addGestureRecognizer(hold)
        view.addGestureRecognizer(tap)
        context.coordinator.holdRecognizer = hold
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.holdRecognizer?.isEnabled = enabled
    }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        // Explicit cancellation also covers navigating away during a hold.
        coordinator.holdRecognizer?.isEnabled = false
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: TiltTouchSurface
        weak var holdRecognizer: UILongPressGestureRecognizer?
        init(_ parent: TiltTouchSurface) { self.parent = parent }

        @objc func tap(_ gesture: UITapGestureRecognizer) {
            if gesture.state == .ended { parent.onTap() }
        }

        @objc func hold(_ gesture: UILongPressGestureRecognizer) {
            switch gesture.state {
            case .began, .changed: parent.onPosition(gesture.location(in: gesture.view))
            case .ended, .cancelled, .failed: parent.onPosition(nil)
            default: break
            }
        }

        private func scrollView(for gesture: UIGestureRecognizer) -> UIScrollView? {
            var ancestor = gesture.view?.superview
            while let view = ancestor {
                if let scroll = view as? UIScrollView { return scroll }
                ancestor = view.superview
            }
            return nil
        }

        func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
            if let scroll = scrollView(for: gesture), scroll.isDragging || scroll.isDecelerating {
                return false
            }
            return gesture !== holdRecognizer || parent.enabled
        }

        func gestureRecognizer(_ gesture: UIGestureRecognizer,
                               shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
            // The scroll pan waits only for this touch's hold decision. Moving
            // over 10pt BEFORE 0.3s fails the hold and releases the native pan.
            // Once a hold begins, movement belongs to tilt until release.
            // This dependency never disables the ScrollView itself.
            gesture === holdRecognizer && parent.enabled &&
                other === scrollView(for: gesture)?.panGestureRecognizer
        }
    }
}
