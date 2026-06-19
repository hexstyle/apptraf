import AppKit
import AppTrafCore

final class HourlyChartView: NSView {
    var buckets: [HourBucket] = [] {
        didSet { needsDisplay = true }
    }
    var period: Period = .h24 {
        didSet { needsDisplay = true }
    }
    var onSelectionChange: ((Int64, Int64)?) -> Void = { _ in }

    private(set) var selection: (from: Int64, to: Int64)?
    private var dragAnchor: CGFloat?
    private var dragCursor: CGFloat?

    override var isFlipped: Bool { true }

    private struct Geometry {
        let chartLeft: CGFloat
        let chartRight: CGFloat
        let chartTop: CGFloat
        let chartBottom: CGFloat
        var chartWidth: CGFloat { chartRight - chartLeft }
        var chartHeight: CGFloat { chartBottom - chartTop }
    }

    private func geometry() -> Geometry {
        Geometry(
            chartLeft: 16,
            chartRight: bounds.width - 16,
            chartTop: 26,
            chartBottom: bounds.height - 24
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        let captionAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let captionText = selection.map { _ in "Hourly consumption · selection highlighted" } ?? "Hourly consumption · drag to filter"
        NSAttributedString(string: captionText, attributes: captionAttrs).draw(at: NSPoint(x: 16, y: 4))

        guard !buckets.isEmpty else {
            drawPlaceholder("No data yet")
            return
        }

        let geo = geometry()
        let totals = buckets.map { $0.total }
        guard let mx = totals.max(), mx > 0 else {
            drawPlaceholder("No traffic recorded for the period")
            return
        }

        let n = buckets.count
        let xFor: (Int) -> CGFloat = { i in
            guard n > 1 else { return geo.chartLeft + geo.chartWidth / 2 }
            return geo.chartLeft + (geo.chartWidth * CGFloat(i)) / CGFloat(n - 1)
        }
        let yFor: (UInt64) -> CGFloat = { v in
            geo.chartBottom - geo.chartHeight * CGFloat(v) / CGFloat(mx)
        }

        drawSelectionOverlay(geo: geo, xFor: xFor)

        let line = NSBezierPath()
        line.lineCapStyle = .round
        line.lineJoinStyle = .round
        line.lineWidth = 1.5

        let fill = NSBezierPath()
        fill.move(to: NSPoint(x: xFor(0), y: geo.chartBottom))
        for i in 0..<n {
            let p = NSPoint(x: xFor(i), y: yFor(buckets[i].total))
            if i == 0 { line.move(to: p) } else { line.line(to: p) }
            fill.line(to: p)
        }
        fill.line(to: NSPoint(x: xFor(n - 1), y: geo.chartBottom))
        fill.close()

        NSColor.controlAccentColor.withAlphaComponent(0.22).setFill()
        fill.fill()

        NSColor.controlAccentColor.setStroke()
        line.stroke()

        drawAxisTicks(geo: geo, xFor: xFor)

        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let mxLabel = NSAttributedString(string: humanBytes(mx), attributes: valueAttrs)
        mxLabel.draw(at: NSPoint(x: geo.chartLeft, y: geo.chartTop - 12))
    }

    private func drawSelectionOverlay(geo: Geometry, xFor: (Int) -> CGFloat) {
        var x1: CGFloat?
        var x2: CGFloat?

        if let a = dragAnchor, let c = dragCursor {
            x1 = min(a, c)
            x2 = max(a, c)
        } else if let sel = selection {
            if let i1 = buckets.firstIndex(where: { $0.hour == sel.from }),
               let i2 = buckets.firstIndex(where: { $0.hour == sel.to }) {
                x1 = xFor(i1)
                x2 = xFor(i2)
            }
        }

        guard let lo = x1, let hi = x2, hi > lo else { return }
        let clampedLo = max(lo, geo.chartLeft)
        let clampedHi = min(hi, geo.chartRight)
        let rect = NSRect(x: clampedLo, y: geo.chartTop, width: clampedHi - clampedLo, height: geo.chartHeight)
        NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
        rect.fill()
        NSColor.controlAccentColor.withAlphaComponent(0.45).setStroke()
        let frame = NSBezierPath(rect: rect)
        frame.lineWidth = 1
        frame.stroke()
    }

    private func drawAxisTicks(geo: Geometry, xFor: (Int) -> CGFloat) {
        guard buckets.count >= 2 else { return }
        let tickAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let count = buckets.count
        let step: Int
        switch period {
        case .h1:  step = max(1, count - 1)
        case .h6:  step = 1
        case .h24: step = 6
        case .d7:  step = 24
        }
        let df = DateFormatter()
        switch period {
        case .h1, .h6, .h24:
            df.dateFormat = "HH:mm"
        case .d7:
            df.dateFormat = "MMM d"
        }

        var i = 0
        while i < count {
            let x = xFor(i)
            let date = Date(timeIntervalSince1970: TimeInterval(buckets[i].hour))
            let s = NSAttributedString(string: df.string(from: date), attributes: tickAttrs)
            let sz = s.size()
            s.draw(at: NSPoint(x: x - sz.width / 2, y: geo.chartBottom + 4))
            i += step
        }
    }

    private func drawPlaceholder(_ text: String) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let s = NSAttributedString(string: text, attributes: attrs)
        let sz = s.size()
        s.draw(at: NSPoint(x: bounds.midX - sz.width / 2, y: bounds.midY - sz.height / 2))
    }

    override func mouseDown(with event: NSEvent) {
        guard !buckets.isEmpty else { return }
        let p = convert(event.locationInWindow, from: nil)
        dragAnchor = p.x
        dragCursor = p.x
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragAnchor != nil else { return }
        let p = convert(event.locationInWindow, from: nil)
        dragCursor = p.x
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            dragAnchor = nil
            dragCursor = nil
            needsDisplay = true
        }
        guard let anchor = dragAnchor, let cursor = dragCursor else { return }

        if abs(cursor - anchor) < 4 {
            // Click without drag — clear selection.
            if selection != nil {
                selection = nil
                onSelectionChange(nil)
            }
            return
        }

        let lo = min(anchor, cursor)
        let hi = max(anchor, cursor)
        guard let range = hoursForPixelRange(lo: lo, hi: hi) else { return }
        selection = range
        onSelectionChange(range)
    }

    private func hoursForPixelRange(lo: CGFloat, hi: CGFloat) -> (from: Int64, to: Int64)? {
        let geo = geometry()
        let n = buckets.count
        guard n >= 1 else { return nil }
        let w = geo.chartWidth
        guard w > 0 else { return nil }
        let frac = { (x: CGFloat) -> Double in
            Double((max(geo.chartLeft, min(geo.chartRight, x)) - geo.chartLeft) / w)
        }
        let denom = max(1, n - 1)
        let i1 = max(0, min(n - 1, Int((frac(lo) * Double(denom)).rounded())))
        let i2 = max(0, min(n - 1, Int((frac(hi) * Double(denom)).rounded())))
        let from = buckets[min(i1, i2)].hour
        let to = buckets[max(i1, i2)].hour
        return (from, to)
    }
}
