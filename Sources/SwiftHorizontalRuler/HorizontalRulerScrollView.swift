import UIKit

/// UIKit-backed horizontal ruler with snapping scroll behavior.
///
/// Renders ticks via `CAShapeLayer` paths (not individual UIViews) for minimal
/// view-hierarchy overhead. Supports VoiceOver with the `.adjustable` trait.
public class HorizontalRulerScrollView: UIView {

    // MARK: - Layout Constants

    private enum Layout {
        static let minorTickHeight: CGFloat = 16
        static let majorTickHeight: CGFloat = 32
        static let tickWidth: CGFloat = 1.5
        static let topInset: CGFloat = 12
        static let labelFontSize: CGFloat = 10
        static let labelTopMargin: CGFloat = 4
        static let indicatorWidth: CGFloat = 14
        static let indicatorLineWidth: CGFloat = 2
        static let indicatorTriangleHeight: CGFloat = 10
    }

    // MARK: - Subviews & Layers

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let minorTicksLayer = CAShapeLayer()
    private let majorTicksLayer = CAShapeLayer()
    private var labelLayers: [CATextLayer] = []

    private let indicatorLine = CALayer()
    private let indicatorTriangle = CAShapeLayer()

    // MARK: - State

    private let config: HorizontalRulerConfig
    private var pendingInitialValue: Double?
    private var hasBuiltContent = false

    // MARK: - Public Interface

    /// Called whenever the selected value changes during scrolling.
    public var onValueChanged: ((Double) -> Void)?

    /// Whether the user is currently dragging the ruler.
    public var isDragging: Bool { scrollView.isDragging }

    /// Whether the ruler is decelerating after a drag.
    public var isDecelerating: Bool { scrollView.isDecelerating }

    /// The value currently at the center indicator.
    public var currentValue: Double {
        guard bounds.width > 0 else { return config.minValue }
        let centerContentX = scrollView.contentOffset.x + bounds.width / 2
        return config.value(atContentX: centerContentX)
    }

    // MARK: - Init

    public init(config: HorizontalRulerConfig) {
        self.config = config
        super.init(frame: .zero)
        setupScrollView()
        setupTickLayers()
        setupIndicator()
        setupAccessibility()
        registerForTraitChanges()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupScrollView() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = self
        scrollView.decelerationRate = .fast
        addSubview(scrollView)
        scrollView.addSubview(contentView)
    }

    private func setupTickLayers() {
        minorTicksLayer.fillColor = nil
        minorTicksLayer.lineWidth = Layout.tickWidth
        minorTicksLayer.lineCap = .butt
        contentView.layer.addSublayer(minorTicksLayer)

        majorTicksLayer.fillColor = nil
        majorTicksLayer.lineWidth = Layout.tickWidth
        majorTicksLayer.lineCap = .butt
        contentView.layer.addSublayer(majorTicksLayer)

        applyTickColors()
    }

    private func setupIndicator() {
        indicatorLine.backgroundColor = config.indicatorColor.cgColor
        layer.addSublayer(indicatorLine)

        indicatorTriangle.fillColor = config.indicatorColor.cgColor
        layer.addSublayer(indicatorTriangle)
    }

    private func setupAccessibility() {
        isAccessibilityElement = true
        accessibilityTraits = .adjustable
    }

    private func registerForTraitChanges() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: HorizontalRulerScrollView, _: UITraitCollection) in
            view.applyTickColors()
            view.applyLabelColors()
        }
    }

    // MARK: - Layout

    override public func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }

        let centerX = bounds.width / 2
        let contentWidth = CGFloat(config.tickCount) * config.tickSpacing

        scrollView.frame = bounds
        scrollView.contentSize = CGSize(width: contentWidth, height: bounds.height)
        scrollView.contentInset = UIEdgeInsets(top: 0, left: centerX, bottom: 0, right: centerX)
        contentView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: bounds.height)

        if !hasBuiltContent {
            hasBuiltContent = true
            buildTicks()
        }

        layoutIndicator(centerX: centerX)

        if let value = pendingInitialValue {
            pendingInitialValue = nil
            let offset = config.contentX(for: value) - centerX
            scrollView.contentOffset = CGPoint(x: offset, y: 0)
        }
    }

    // MARK: - Tick Rendering (CAShapeLayer)

    private func buildTicks() {
        let total = config.tickCount
        let perMajor = config.minorTicksPerMajor

        let minorPath = CGMutablePath()
        let majorPath = CGMutablePath()

        for i in 0..<total {
            let x = CGFloat(i) * config.tickSpacing
            let isMajor = i % perMajor == 0
            let tickHeight = isMajor ? Layout.majorTickHeight : Layout.minorTickHeight

            let path = isMajor ? majorPath : minorPath
            path.move(to: CGPoint(x: x, y: Layout.topInset))
            path.addLine(to: CGPoint(x: x, y: Layout.topInset + tickHeight))

            if isMajor {
                let tickValue = config.minValue + Double(i) * config.minorIncrement
                let label = makeLabel(text: config.labelFormatter(tickValue))
                let labelY = Layout.topInset + Layout.majorTickHeight + Layout.labelTopMargin + Layout.labelFontSize / 2
                label.position = CGPoint(x: x, y: labelY)
                contentView.layer.addSublayer(label)
                labelLayers.append(label)
            }
        }

        minorTicksLayer.path = minorPath
        majorTicksLayer.path = majorPath
    }

    private func makeLabel(text: String) -> CATextLayer {
        let font = UIFont.systemFont(ofSize: Layout.labelFontSize, weight: .medium)
        let size = (text as NSString).size(withAttributes: [.font: font])

        let label = CATextLayer()
        label.string = text
        label.font = font
        label.fontSize = Layout.labelFontSize
        label.foregroundColor = UIColor.secondaryLabel.cgColor
        label.alignmentMode = .center
        label.contentsScale = traitCollection.displayScale
        label.bounds = CGRect(origin: .zero, size: size)
        return label
    }

    // MARK: - Indicator Layout

    private func layoutIndicator(centerX: CGFloat) {
        let lineHeight = Layout.majorTickHeight + 4
        indicatorLine.frame = CGRect(
            x: centerX - Layout.indicatorLineWidth / 2,
            y: Layout.indicatorTriangleHeight,
            width: Layout.indicatorLineWidth,
            height: lineHeight
        )

        let triPath = CGMutablePath()
        triPath.move(to: CGPoint(x: centerX, y: Layout.indicatorTriangleHeight))
        triPath.addLine(to: CGPoint(x: centerX - Layout.indicatorWidth / 2, y: 0))
        triPath.addLine(to: CGPoint(x: centerX + Layout.indicatorWidth / 2, y: 0))
        triPath.closeSubpath()
        indicatorTriangle.path = triPath
    }

    // MARK: - Color Updates

    private func applyTickColors() {
        minorTicksLayer.strokeColor = UIColor.label.withAlphaComponent(0.25).cgColor
        majorTicksLayer.strokeColor = UIColor.label.withAlphaComponent(0.6).cgColor
    }

    private func applyLabelColors() {
        let color = UIColor.secondaryLabel.cgColor
        for label in labelLayers {
            label.foregroundColor = color
        }
    }

    // MARK: - Public API

    /// Programmatically set the ruler to a specific value.
    public func setValue(_ value: Double, animated: Bool) {
        guard bounds.width > 0 else {
            pendingInitialValue = value
            return
        }
        let offset = config.contentX(for: value) - bounds.width / 2
        scrollView.setContentOffset(CGPoint(x: offset, y: 0), animated: animated)
    }

    // MARK: - Accessibility

    override public var accessibilityValue: String? {
        get { config.labelFormatter(currentValue) }
        set {}
    }

    override public func accessibilityIncrement() {
        let newValue = min(currentValue + config.minorIncrement, config.maxValue)
        setValue(newValue, animated: true)
        onValueChanged?(config.clampAndRound(newValue))
    }

    override public func accessibilityDecrement() {
        let newValue = max(currentValue - config.minorIncrement, config.minValue)
        setValue(newValue, animated: true)
        onValueChanged?(config.clampAndRound(newValue))
    }
}

// MARK: - UIScrollViewDelegate

extension HorizontalRulerScrollView: UIScrollViewDelegate {

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard bounds.width > 0 else { return }
        onValueChanged?(currentValue)
    }

    public func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        let centerX = bounds.width / 2
        let targetContentX = targetContentOffset.pointee.x + centerX
        let snappedX = (targetContentX / config.tickSpacing).rounded() * config.tickSpacing
        targetContentOffset.pointee.x = snappedX - centerX
    }
}
