#!/usr/bin/env swift
import AppKit
import CoreGraphics

let outputDir = "Resources/AppTraf.iconset"
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

func render(pixels: Int) -> Data {
    let size = CGFloat(pixels)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 32
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    // Background squircle
    let inset = size * 0.085
    let corner = size * 0.225
    let bg = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let bgPath = CGPath(roundedRect: bg, cornerWidth: corner, cornerHeight: corner, transform: nil)

    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    let colors = [
        NSColor(red: 0.055, green: 0.647, blue: 0.914, alpha: 1.0).cgColor,
        NSColor(red: 0.047, green: 0.290, blue: 0.431, alpha: 1.0).cgColor,
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
    ctx.restoreGState()

    // Hairline border for a polished edge at large sizes
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.08).cgColor)
    ctx.setLineWidth(max(1.0, size * 0.004))
    ctx.strokePath()
    ctx.restoreGState()

    // Chart area: clip to background squircle so nothing bleeds at corners
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    // Data points across the chart, y values are relative to the squircle
    let chartLeft = size * 0.17
    let chartRight = size * 0.83
    let chartBase = size * 0.36           // bottom of fill / baseline
    let pts: [CGPoint] = [
        CGPoint(x: chartLeft,                                                    y: size * 0.44),
        CGPoint(x: chartLeft + (chartRight - chartLeft) * 0.22, y: size * 0.58),
        CGPoint(x: chartLeft + (chartRight - chartLeft) * 0.42, y: size * 0.48),
        CGPoint(x: chartLeft + (chartRight - chartLeft) * 0.64, y: size * 0.72),
        CGPoint(x: chartLeft + (chartRight - chartLeft) * 0.84, y: size * 0.60),
        CGPoint(x: chartRight,                                                   y: size * 0.66),
    ]

    // Smooth cubic curve through the points
    let line = CGMutablePath()
    line.move(to: pts[0])
    for i in 1..<pts.count {
        let prev = pts[i - 1]
        let curr = pts[i]
        let cp1 = CGPoint(x: prev.x + (curr.x - prev.x) * 0.5, y: prev.y)
        let cp2 = CGPoint(x: prev.x + (curr.x - prev.x) * 0.5, y: curr.y)
        line.addCurve(to: curr, control1: cp1, control2: cp2)
    }

    // Filled area below the curve
    let fill = line.mutableCopy()!
    fill.addLine(to: CGPoint(x: pts.last!.x, y: chartBase))
    fill.addLine(to: CGPoint(x: pts.first!.x, y: chartBase))
    fill.closeSubpath()

    ctx.addPath(fill)
    ctx.setFillColor(NSColor(white: 1.0, alpha: 0.22).cgColor)
    ctx.fillPath()

    // Stroke the curve
    ctx.addPath(line)
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(max(1.5, size * 0.038))
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()

    // Data point dots — skip at very small sizes (would just look like noise)
    if size >= 64 {
        let r = max(2.0, size * 0.032)
        for p in pts {
            let dot = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fillEllipse(in: dot)
            // inner blue ring for definition at the bigger sizes
            if size >= 256 {
                let inner = r * 0.45
                let hole = CGRect(x: p.x - inner, y: p.y - inner, width: inner * 2, height: inner * 2)
                ctx.setFillColor(NSColor(red: 0.047, green: 0.290, blue: 0.431, alpha: 1.0).cgColor)
                ctx.fillEllipse(in: hole)
            }
        }
    }

    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])!
}

let entries: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, px) in entries {
    let data = render(pixels: px)
    let url = URL(fileURLWithPath: "\(outputDir)/\(name)")
    try! data.write(to: url)
    print("wrote \(name) (\(px)x\(px))")
}
