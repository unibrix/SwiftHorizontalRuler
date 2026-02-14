import UIKit

/// Haptic feedback style triggered on each tick while scrolling.
public enum RulerHapticStyle {
    /// No haptic feedback.
    case none
    /// Selection tick — subtle, like scrolling a picker. Default.
    case selection
    /// Light impact.
    case light
    /// Medium impact.
    case medium
    /// Heavy impact.
    case heavy

    var impactStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .none, .selection: return .light
        case .light: return .light
        case .medium: return .medium
        case .heavy: return .heavy
        }
    }
}

/// Configuration for a horizontal ruler picker.
///
/// All parameters are validated at init time. Invalid configurations
/// will trigger a precondition failure in debug builds.
public struct HorizontalRulerConfig {
    /// Minimum selectable value.
    public let minValue: Double
    /// Maximum selectable value.
    public let maxValue: Double
    /// Distance between minor (small) ticks in value units.
    public let minorIncrement: Double
    /// Distance between major (labeled) ticks in value units.
    public let majorIncrement: Double
    /// Point spacing in points between adjacent minor ticks.
    public let tickSpacing: CGFloat
    /// Formats a tick value into a label string. Called only for major ticks.
    public let labelFormatter: (Double) -> String
    /// Color of the center indicator line and triangle. Defaults to the view's tint color.
    public let indicatorColor: UIColor
    /// Haptic feedback style. Defaults to `.selection`.
    public let hapticStyle: RulerHapticStyle

    /// Total number of ticks for this configuration.
    var tickCount: Int {
        Int((maxValue - minValue) / minorIncrement) + 1
    }

    /// Number of minor ticks between each major tick.
    var minorTicksPerMajor: Int {
        max(1, Int(majorIncrement / minorIncrement))
    }

    public init(
        minValue: Double,
        maxValue: Double,
        minorIncrement: Double,
        majorIncrement: Double,
        tickSpacing: CGFloat = 6,
        indicatorColor: UIColor = .tintColor,
        hapticStyle: RulerHapticStyle = .selection,
        labelFormatter: @escaping (Double) -> String = { String(format: "%.0f", $0) }
    ) {
        precondition(minValue < maxValue, "minValue (\(minValue)) must be less than maxValue (\(maxValue))")
        precondition(minorIncrement > 0, "minorIncrement must be positive")
        precondition(majorIncrement > 0, "majorIncrement must be positive")
        precondition(majorIncrement >= minorIncrement, "majorIncrement must be >= minorIncrement")
        precondition(tickSpacing > 0, "tickSpacing must be positive")

        self.minValue = minValue
        self.maxValue = maxValue
        self.minorIncrement = minorIncrement
        self.majorIncrement = majorIncrement
        self.tickSpacing = tickSpacing
        self.indicatorColor = indicatorColor
        self.hapticStyle = hapticStyle
        self.labelFormatter = labelFormatter
    }

    /// Clamp a raw value to [minValue, maxValue] and round to the nearest minor increment.
    func clampAndRound(_ value: Double) -> Double {
        let clamped = min(max(value, minValue), maxValue)
        return (clamped / minorIncrement).rounded() * minorIncrement
    }

    /// Content offset (from left edge) for a given value.
    func contentX(for value: Double) -> CGFloat {
        CGFloat((value - minValue) / minorIncrement) * tickSpacing
    }

    /// Value at a given content-space x position.
    func value(atContentX x: CGFloat) -> Double {
        clampAndRound(minValue + Double(x / tickSpacing) * minorIncrement)
    }
}
