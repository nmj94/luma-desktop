import AppKit

let directory = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(size)
    let rect = NSRect(x: s * 0.06, y: s * 0.06, width: s * 0.88, height: s * 0.88)
    let path = NSBezierPath(roundedRect: rect, xRadius: s * 0.21, yRadius: s * 0.21)
    path.addClip()
    NSGradient(colors: [NSColor(srgbRed: 0.04, green: 0.08, blue: 0.18, alpha: 1), NSColor(srgbRed: 0.08, green: 0.24, blue: 0.32, alpha: 1)])!.draw(in: rect, angle: 65)
    for i in 0..<3 {
        let band = NSBezierPath()
        let y = s * (0.27 + Double(i) * 0.12)
        band.move(to: NSPoint(x: -s * 0.1, y: y))
        band.curve(to: NSPoint(x: s * 1.1, y: y + s * 0.35), controlPoint1: NSPoint(x: s * 0.40, y: y - s * 0.3), controlPoint2: NSPoint(x: s * 0.55, y: y + s * 0.6))
        band.lineWidth = s * 0.055
        NSColor(srgbRed: 0.35 + Double(i) * 0.13, green: 0.88, blue: 0.79 + Double(i) * 0.06, alpha: 0.55 + Double(i) * 0.2).setStroke()
        band.stroke()
    }
    NSColor.white.withAlphaComponent(0.9).setFill()
    NSBezierPath(ovalIn: NSRect(x: s * 0.68, y: s * 0.72, width: s * 0.037, height: s * 0.037)).fill()
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    let names: [String]
    switch size {
    case 16: names = ["icon_16x16.png"]
    case 32: names = ["icon_16x16@2x.png", "icon_32x32.png"]
    case 64: names = ["icon_32x32@2x.png"]
    case 128: names = ["icon_128x128.png"]
    case 256: names = ["icon_128x128@2x.png", "icon_256x256.png"]
    case 512: names = ["icon_256x256@2x.png", "icon_512x512.png"]
    default: names = ["icon_512x512@2x.png"]
    }
    for name in names { try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name)) }
}
