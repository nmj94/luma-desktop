import AppKit
import QuartzCore
import SwiftUI

extension NSColor {
    convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((rgb >> 16) & 255) / 255, green: CGFloat((rgb >> 8) & 255) / 255, blue: CGFloat(rgb & 255) / 255, alpha: alpha)
    }
}
extension Color { init(rgb: UInt32) { self.init(nsColor: NSColor(rgb: rgb)) } }

final class SceneView: NSView {
    let scene: BuiltinScene
    private let canvas = CALayer()
    private var paused = false
    override var isOpaque: Bool { true }

    init(scene: BuiltinScene, animated: Bool = true) {
        self.scene = scene
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(rgb: scene.colors[0]).cgColor
        layer?.masksToBounds = true
        canvas.bounds = CGRect(x: 0, y: 0, width: 1600, height: 1000)
        layer?.addSublayer(canvas)
        constructScene()
        if !animated { setPaused(true) }
    }
    required init?(coder: NSCoder) { nil }

    private func constructScene() {
        let p = scene.colors
        let base = CAGradientLayer()
        base.frame = canvas.bounds
        base.colors = [NSColor(rgb: p[0]).cgColor, NSColor(rgb: p[1]).cgColor, NSColor(rgb: p[0]).cgColor]
        base.startPoint = CGPoint(x: 0.2, y: 1)
        base.endPoint = CGPoint(x: 0.9, y: 0)
        canvas.addSublayer(base)

        for i in 0..<5 {
            let glow = CAGradientLayer()
            glow.type = .radial
            glow.bounds = CGRect(x: 0, y: 0, width: 1500, height: 1050)
            glow.position = CGPoint(x: 250 + i * 280, y: 380 + (i % 3) * 120)
            glow.colors = [NSColor(rgb: p[2 + i % 3], alpha: scene == .cosmos ? 0.36 : 0.50).cgColor, NSColor(rgb: p[2 + i % 3], alpha: 0.14).cgColor, NSColor(rgb: p[0], alpha: 0).cgColor]
            glow.locations = [0, 0.3, 1]
            glow.startPoint = CGPoint(x: 0.5, y: 0.5)
            glow.endPoint = CGPoint(x: 1, y: 1)
            glow.transform = CATransform3DMakeRotation(-0.38 + Double(i) * 0.22, 0, 0, 1)
            canvas.addSublayer(glow)
            let drift = CAKeyframeAnimation(keyPath: "position")
            let x = glow.position.x, y = glow.position.y
            drift.values = [NSValue(point: NSPoint(x: x, y: y)), NSValue(point: NSPoint(x: x + 170, y: y - 140)), NSValue(point: NSPoint(x: x - 120, y: y + 100)), NSValue(point: NSPoint(x: x, y: y))]
            drift.keyTimes = [0, 0.34, 0.68, 1]
            drift.duration = Double(28 + i * 7)
            drift.calculationMode = .cubic
            drift.repeatCount = .infinity
            glow.add(drift, forKey: "drift")
            let breath = CABasicAnimation(keyPath: "transform.scale")
            breath.fromValue = 0.85; breath.toValue = 1.24
            breath.duration = Double(13 + i * 3); breath.autoreverses = true; breath.repeatCount = .infinity
            breath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            glow.add(breath, forKey: "breath")
        }

        if scene == .aurora || scene == .ocean {
            for i in 0..<4 {
                let ribbon = CAGradientLayer()
                ribbon.bounds = CGRect(x: 0, y: 0, width: 1900, height: 170 + i * 65)
                ribbon.position = CGPoint(x: 740 + i * 90, y: 430 + i * 90)
                ribbon.colors = [NSColor.clear.cgColor, NSColor(rgb: p[2 + i % 2], alpha: 0.12).cgColor, NSColor(rgb: p[2 + i % 2], alpha: 0.36).cgColor, NSColor.clear.cgColor]
                ribbon.locations = [0, 0.48, 0.66, 1]
                ribbon.transform = CATransform3DMakeRotation(-0.37, 0, 0, 1)
                canvas.addSublayer(ribbon)
                let wave = CABasicAnimation(keyPath: "transform.rotation.z")
                wave.fromValue = -0.47; wave.toValue = -0.17
                wave.duration = Double(19 + i * 5); wave.autoreverses = true; wave.repeatCount = .infinity
                wave.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                ribbon.add(wave, forKey: "wave")
            }
        }

        var random = UInt64(72813)
        func next() -> CGFloat {
            random = random &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((random >> 33) % 10000) / 10000
        }
        for i in 0..<(scene == .cosmos ? 150 : 65) {
            let star = CALayer()
            let radius = next() > 0.92 ? 2.8 : 1.2
            star.frame = CGRect(x: next() * 1600, y: next() * 1000, width: radius, height: radius)
            star.cornerRadius = radius / 2
            star.backgroundColor = NSColor.white.withAlphaComponent(0.18 + next() * 0.62).cgColor
            canvas.addSublayer(star)
            if i % 3 == 0 {
                let twinkle = CABasicAnimation(keyPath: "opacity")
                twinkle.fromValue = 0.18; twinkle.toValue = 0.85
                twinkle.duration = Double(2 + next() * 5); twinkle.autoreverses = true; twinkle.repeatCount = .infinity
                star.add(twinkle, forKey: "twinkle")
            }
        }
        let shade = CAGradientLayer()
        shade.frame = canvas.bounds
        shade.colors = [NSColor.black.withAlphaComponent(0.50).cgColor, NSColor.clear.cgColor, NSColor.black.withAlphaComponent(0.10).cgColor]
        shade.locations = [0, 0.5, 1]
        canvas.addSublayer(shade)
    }

    override func layout() {
        super.layout()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        canvas.position = CGPoint(x: bounds.midX, y: bounds.midY)
        let scale = max(bounds.width / 1600, bounds.height / 1000)
        canvas.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        CATransaction.commit()
    }

    func setPaused(_ value: Bool) {
        guard value != paused else { return }
        paused = value
        if value {
            let time = canvas.convertTime(CACurrentMediaTime(), from: nil)
            canvas.speed = 0; canvas.timeOffset = time
        } else {
            let time = canvas.timeOffset
            canvas.speed = 1; canvas.timeOffset = 0; canvas.beginTime = 0
            canvas.beginTime = canvas.convertTime(CACurrentMediaTime(), from: nil) - time
        }
    }
}

struct ScenePreview: NSViewRepresentable {
    let scene: BuiltinScene
    var animated = true
    func makeNSView(context: Context) -> SceneView { SceneView(scene: scene, animated: animated) }
    func updateNSView(_ nsView: SceneView, context: Context) { nsView.setPaused(!animated) }
}
