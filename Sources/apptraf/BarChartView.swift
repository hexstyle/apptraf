import AppKit
import AppTrafCore

final class BarChartView: NSView {
    var entries: [AggRow] = []
    var metric: SortMetric = .total

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        let captionAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let caption = NSAttributedString(string: "Top 10 by \(metric.label)", attributes: captionAttrs)
        caption.draw(at: NSPoint(x: 16, y: 4))

        guard !entries.isEmpty else {
            drawPlaceholder("No data yet")
            return
        }

        let values = entries.map { metric.value(of: $0) }
        guard let mx = values.max(), mx > 0 else {
            drawPlaceholder("No traffic recorded for the period")
            return
        }

        let padX: CGFloat = 16
        let padTop: CGFloat = 26
        let labelArea: CGFloat = 32
        let chartTop = padTop
        let chartBottom = bounds.height - labelArea
        let chartLeft = padX
        let chartRight = bounds.width - padX
        let chartWidth = chartRight - chartLeft
        let chartHeight = chartBottom - chartTop

        let n = CGFloat(entries.count)
        let slot = chartWidth / n
        let barWidth = max(8, slot * 0.62)
        let leadGap = (slot - barWidth) / 2

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]

        for (i, e) in entries.enumerated() {
            let v = CGFloat(metric.value(of: e))
            let h = chartHeight * (v / CGFloat(mx))
            let x = chartLeft + CGFloat(i) * slot + leadGap
            let y = chartBottom - h
            let rect = NSRect(x: x, y: y, width: barWidth, height: max(2, h))

            NSColor.controlAccentColor.setFill()
            let path = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
            path.fill()

            let label = truncateLabel(e.app, maxWidth: slot - 4)
            let attrLabel = NSAttributedString(string: label, attributes: labelAttrs)
            let lsz = attrLabel.size()
            attrLabel.draw(at: NSPoint(
                x: x + barWidth/2 - lsz.width/2,
                y: chartBottom + 6
            ))

            let valueStr = NSAttributedString(string: humanBytes(UInt64(v)), attributes: valueAttrs)
            let vsz = valueStr.size()
            let valueY = max(chartTop, y - vsz.height - 2)
            valueStr.draw(at: NSPoint(
                x: x + barWidth/2 - vsz.width/2,
                y: valueY
            ))
        }
    }

    private func truncateLabel(_ s: String, maxWidth: CGFloat) -> String {
        let font = NSFont.systemFont(ofSize: 9)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        if (s as NSString).size(withAttributes: attrs).width <= maxWidth { return s }
        var trimmed = s
        while trimmed.count > 1 {
            trimmed.removeLast()
            let candidate = trimmed + "…"
            if (candidate as NSString).size(withAttributes: attrs).width <= maxWidth {
                return candidate
            }
        }
        return "…"
    }

    private func drawPlaceholder(_ text: String) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let s = NSAttributedString(string: text, attributes: attrs)
        let sz = s.size()
        s.draw(at: NSPoint(x: bounds.midX - sz.width/2, y: bounds.midY - sz.height/2))
    }
}
