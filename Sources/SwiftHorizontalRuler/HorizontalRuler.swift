import SwiftUI
import UIKit

/// A SwiftUI horizontal ruler picker backed by UIKit for reliable scroll behavior.
///
/// ```swift
/// @State private var weight: Double = 70
///
/// HorizontalRuler(
///     value: $weight,
///     config: HorizontalRulerConfig(
///         minValue: 30, maxValue: 200,
///         minorIncrement: 0.5, majorIncrement: 5
///     )
/// )
/// .frame(height: 70)
/// ```
public struct HorizontalRuler: UIViewRepresentable {
    @Binding public var value: Double
    public let config: HorizontalRulerConfig

    public init(value: Binding<Double>, config: HorizontalRulerConfig) {
        self._value = value
        self.config = config
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public func makeUIView(context: Context) -> HorizontalRulerScrollView {
        let ruler = HorizontalRulerScrollView(config: config)
        ruler.onValueChanged = { [weak coordinator = context.coordinator] newValue in
            coordinator?.handleValueChange(newValue)
        }
        ruler.setValue(value, animated: false)
        return ruler
    }

    public func updateUIView(_ ruler: HorizontalRulerScrollView, context: Context) {
        context.coordinator.parent = self

        // Only sync externally-driven value changes; don't fight the scroll.
        guard !ruler.isDragging, !ruler.isDecelerating else { return }
        if abs(ruler.currentValue - value) > config.minorIncrement {
            ruler.setValue(value, animated: false)
        }
    }

    // MARK: - Coordinator

    public class Coordinator {
        var parent: HorizontalRuler
        private var lastHapticValue: Double
        private var feedbackGenerator: UIFeedbackGenerator?

        init(parent: HorizontalRuler) {
            self.parent = parent
            self.lastHapticValue = parent.value
            self.feedbackGenerator = Self.makeFeedbackGenerator(for: parent.config.hapticStyle)
        }

        func handleValueChange(_ newValue: Double) {
            parent.value = newValue
            fireHapticIfNeeded(for: newValue)
        }

        // MARK: - Haptics

        private func fireHapticIfNeeded(for newValue: Double) {
            guard parent.config.hapticStyle != .none else { return }
            guard abs(newValue - lastHapticValue) >= parent.config.minorIncrement * 0.9 else { return }

            switch feedbackGenerator {
            case let gen as UISelectionFeedbackGenerator:
                gen.selectionChanged()
                gen.prepare()
            case let gen as UIImpactFeedbackGenerator:
                gen.impactOccurred()
                gen.prepare()
            default:
                break
            }
            lastHapticValue = newValue
        }

        private static func makeFeedbackGenerator(for style: RulerHapticStyle) -> UIFeedbackGenerator? {
            switch style {
            case .none:
                return nil
            case .selection:
                let gen = UISelectionFeedbackGenerator()
                gen.prepare()
                return gen
            case .light, .medium, .heavy:
                let gen = UIImpactFeedbackGenerator(style: style.impactStyle)
                gen.prepare()
                return gen
            }
        }
    }
}
