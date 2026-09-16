import SwiftUI
import CoreGraphics

extension GraphicsContext {
    func drawRadialGradient(_ gradient: Gradient, center: CGPoint, startRadius: CGFloat, endRadius: CGFloat) {
        let rect = CGRect(x: center.x - endRadius, y: center.y - endRadius, width: endRadius * 2, height: endRadius * 2)
        fill(Path(ellipseIn: rect), with: .radialGradient(gradient, center: center, startRadius: startRadius, endRadius: endRadius))
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
