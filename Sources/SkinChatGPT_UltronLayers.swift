import SwiftUI
import CoreGraphics
import Foundation

extension UltronRenderer {
    // MARK: Shockwave

    func drawShockwave(_ c: inout GraphicsContext, _ f: UFrame) {
        guard f.bass > 0.15 else { return }

        let period = 1.15
        let phase = CGFloat(f.time.truncatingRemainder(dividingBy: period)) / CGFloat(period)
        let radius = f.radius * (0.14 + phase * 0.90)
        let opacity = (1 - phase) * f.bass * 0.20

        drawEllipse(
            c: &c,
            center: f.center,
            radius: radius,
            yScale: 0.58,
            rotation: CGFloat(f.time) * 0.04,
            color: UltronPalette.cyan.opacity(opacity),
            width: max(0.5, f.radius * 0.0018)
        )
    }

    // MARK: Instability

    func drawGlitchInstability(_ c: inout GraphicsContext, _ f: UFrame) {
        let pulse = 0.5 + 0.5 * CGFloat(sin(f.time * 6.7))
        guard pulse > 0.97 else { return }

        for i in 0..<5 {
            let y = f.center.y
                + (CGFloat(i) - 2) * f.radius * 0.08
                + CGFloat(sin(f.time * 19 + Double(i))) * f.radius * 0.012
            let offset = CGFloat(sin(f.time * 23 + Double(i) * 2.7)) * f.radius * 0.025

            var path = Path()
            path.move(to: CGPoint(x: f.center.x - f.radius * 0.65 + offset, y: y))
            path.addLine(to: CGPoint(x: f.center.x + f.radius * 0.65 + offset, y: y + f.radius * 0.003))

            c.stroke(
                path,
                with: .color(UltronPalette.cyan.opacity(0.012 + f.activity * 0.05)),
                lineWidth: max(0.35, f.radius * 0.0008)
            )
        }
    }

    // MARK: Bloom

    func drawBloom(_ c: inout GraphicsContext, _ f: UFrame) {
        let gradient = Gradient(colors: [
            UltronPalette.white.opacity(0.035 + f.activity * 0.045),
            UltronPalette.cyan.opacity(0.025 + f.activity * 0.035),
            .clear
        ])
        c.drawRadialGradient(
            gradient,
            center: f.center,
            startRadius: 0,
            endRadius: f.radius * (0.12 + f.activity * 0.045)
        )
    }


    // MARK: Organic Tendrils

    func drawOrganicTendrils(_ c: inout GraphicsContext, _ f: UFrame) {
        let count = Int(UMath.clamp(f.size / 20, 20, 62))

        for i in 0..<count {
            let seed = CGFloat(i) * 1.71
            var path = Path()

            for step in 0...19 {
                let u = CGFloat(step) / 19
                let a = seed
                    + CGFloat(f.time) * (0.045 + CGFloat(i % 6) * 0.008)
                    + u * (1.2 + CGFloat(i % 4) * 0.34)

                let growth = 0.08 + u * (0.76 + 0.06 * UMath.hash(i * 13))
                let organic =
                    1.0
                    + 0.10 * CGFloat(sin(Double(i * 19 + step * 7) + f.time * 1.6))
                    + 0.04 * CGFloat(sin(Double(step * 31) + f.time * 2.7))

                let p = UPoint3(
                    x: cos(a) * growth * organic,
                    y: sin(a) * growth * 0.48 * organic,
                    z: 0.52 * sin(a * 1.6 + seed)
                )

                let q = UMath.project(p, radius: f.radius, center: f.center).point
                if step == 0 { path.move(to: q) }
                else { path.addLine(to: q) }
            }

            let pulse = transferPulse(index: i * 47 + 3400, time: f.time)
            drawGlowPath(
                c: &c,
                path: path,
                color: pulse > 0.84 ? UltronPalette.electric : f.color,
                opacity: 0.008 + f.activity * 0.038 + pulse * 0.055,
                width: max(0.3, f.radius * 0.00075)
            )
        }
    }

    // MARK: Fracture Plates

    func drawFracturePlates(_ c: inout GraphicsContext, _ f: UFrame) {
        let count = Int(UMath.clamp(f.size / 15, 28, 82))

        for i in 0..<count {
            let seed = CGFloat(i)
            let a = seed * 2.77 + CGFloat(f.time) * (0.018 + CGFloat(i % 5) * 0.005)
            let radius = 0.25 + UMath.hash(i * 37) * 0.68
            let width = 0.025 + UMath.hash(i * 53) * 0.075
            let height = 0.012 + UMath.hash(i * 71) * 0.045

            let p = UPoint3(
                x: cos(a) * radius,
                y: sin(a) * radius * 0.59,
                z: UMath.hash(i * 97) * 1.6 - 0.8
            )
            let q = UMath.project(p, radius: f.radius, center: f.center)

            let angle = a + CGFloat(UMath.hash(i * 11) - 0.5)
            var path = Path()

            let points = [
                CGPoint(x: -width, y: -height),
                CGPoint(x: width * 0.55, y: -height * 0.85),
                CGPoint(x: width, y: height * 0.45),
                CGPoint(x: -width * 0.42, y: height),
                CGPoint(x: -width, y: -height)
            ]

            for (index, point) in points.enumerated() {
                let x = q.point.x + point.x * cos(angle) - point.y * sin(angle)
                let y = q.point.y + point.x * sin(angle) + point.y * cos(angle)
                if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }

            let pulse = ping(index: i * 67 + 3600, time: f.time)
            c.stroke(
                path,
                with: .color((pulse > 0.87 ? UltronPalette.cyan : f.color).opacity(
                    0.012 + f.activity * 0.035 + pulse * 0.08
                )),
                lineWidth: max(0.35, f.radius * 0.00085)
            )
        }
    }

    // MARK: Activation Cascade

    func drawActivationCascade(_ c: inout GraphicsContext, _ f: UFrame) {
        let cascade = 0.5 + 0.5 * CGFloat(sin(f.time * 0.93))
        let count = 14

        for i in 0..<count {
            let wave = cascade + CGFloat(i) / CGFloat(count) * 0.38
            let local = wave.truncatingRemainder(dividingBy: 1.0)
            let radius = f.radius * (0.10 + local * 0.78)
            let a = CGFloat(i) * 2.41 + CGFloat(f.time) * 0.05

            let p = CGPoint(
                x: f.center.x + cos(a) * radius,
                y: f.center.y + sin(a) * radius * 0.57
            )

            let previous = CGPoint(
                x: f.center.x + cos(a - 0.10) * max(0, radius - f.radius * 0.055),
                y: f.center.y + sin(a - 0.10) * max(0, radius - f.radius * 0.055) * 0.57
            )

            drawSegment(
                c: &c,
                from: previous,
                to: p,
                color: UltronPalette.electric,
                opacity: (1 - local) * f.activity * 0.16,
                width: max(0.45, f.radius * 0.0013),
                glow: local < 0.20
            )
        }
    }

    // MARK: Surface Pulses

    func drawSurfacePulses(_ c: inout GraphicsContext, _ f: UFrame) {
        for shell in 0..<6 {
            let q = CGFloat(shell) / 5
            let radius = f.radius * (0.22 + q * 0.66)
            let phase = CGFloat(f.time) * (0.16 - q * 0.03) + q * 3.7
            let active = 0.5 + 0.5 * CGFloat(sin(f.time * (1.1 + Double(shell) * 0.13) + Double(shell)))

            if active < 0.62 { continue }

            drawEllipse(
                c: &c,
                center: f.center,
                radius: radius,
                yScale: 0.37 + q * 0.27,
                rotation: phase,
                color: UltronPalette.cyan.opacity((active - 0.62) * 0.16),
                width: max(0.4, f.radius * 0.0011)
            )
        }
    }

    // MARK: Depth Sparks

    func drawDepthSparks(_ c: inout GraphicsContext, _ f: UFrame) {
        let count = Int(UMath.clamp(f.size / 13, 30, 90))

        for i in 0..<count {
            let depth = UMath.hash(i * 19)
            let angle = CGFloat(i) * 2.13 + CGFloat(f.time) * (0.015 + CGFloat(i % 3) * 0.004)
            let radius = 0.16 + UMath.hash(i * 41) * 0.78

            let p = UPoint3(
                x: cos(angle) * radius,
                y: sin(angle) * radius * 0.60,
                z: depth * 1.8 - 0.9
            )
            let q = UMath.project(p, radius: f.radius, center: f.center)

            let packet = transferPulse(index: i * 151 + 3900, time: f.time)
            guard packet > 0.60 else { continue }

            let length = f.radius * (0.004 + packet * 0.025)
            let direction = angle + 0.8

            drawSegment(
                c: &c,
                from: q.point,
                to: CGPoint(
                    x: q.point.x + cos(direction) * length,
                    y: q.point.y + sin(direction) * length
                ),
                color: depth > 0.55 ? UltronPalette.electric : f.color,
                opacity: packet * (0.06 + depth * 0.09),
                width: max(0.35, f.radius * 0.0009),
                glow: packet > 0.85
            )
        }
    }

    // MARK: Code Fragments

    func drawCodeFragments(_ c: inout GraphicsContext, _ f: UFrame) {
        // These are intentionally abstract blocks rather than readable text.
        // At film scale they function as code/data texture.
        let count = Int(UMath.clamp(f.size / 21, 16, 48))

        for i in 0..<count {
            let a = CGFloat(i) * 2.63 + CGFloat(f.time) * 0.024
            let radius = f.radius * (0.34 + UMath.hash(i * 29) * 0.52)

            let center = CGPoint(
                x: f.center.x + cos(a) * radius,
                y: f.center.y + sin(a) * radius * 0.55
            )

            let width = f.radius * (0.012 + UMath.hash(i * 13) * 0.028)
            let height = max(0.6, f.radius * 0.0025)
            let lines = 2 + i % 4
            let pulse = ping(index: i * 179 + 4200, time: f.time)

            for line in 0..<lines {
                let y = center.y + CGFloat(line) * height * 1.7
                let lineWidth = width * (0.42 + UMath.hash(i * 17 + line * 3) * 0.58)

                var path = Path()
                path.move(to: CGPoint(x: center.x, y: y))
                path.addLine(to: CGPoint(x: center.x + lineWidth, y: y))

                c.stroke(
                    path,
                    with: .color((pulse > 0.86 ? UltronPalette.electric : f.color).opacity(
                        0.008 + pulse * 0.065 + f.activity * 0.012
                    )),
                    lineWidth: max(0.3, f.radius * 0.0007)
                )
            }
        }
    }



    // MARK: Cortical Rings

    func drawCorticalRings(_ c: inout GraphicsContext, _ f: UFrame) {
        for ring in 0..<7 {
            let q = CGFloat(ring) / 6
            let radius = f.radius * (0.20 + q * 0.67)
            let rotation = CGFloat(f.time) * (ring.isMultiple(of: 2) ? 0.021 : -0.028) + q * 0.7

            var path = Path()
            for i in 0...56 {
                let u = CGFloat(i) / 56
                let a = u * UMath.tau + rotation
                let fracture = 1
                    + 0.025 * CGFloat(sin(Double(i * 7 + ring * 13) + f.time * 2.1))
                    + f.neuralEnergy * 0.035 * CGFloat(sin(Double(i) * 0.31 + f.time * 7.0))

                let p = CGPoint(
                    x: f.center.x + cos(a) * radius * fracture,
                    y: f.center.y + sin(a) * radius * (0.34 + q * 0.31) * fracture
                )

                if i == 0 { path.move(to: p) }
                else { path.addLine(to: p) }
            }

            c.stroke(
                path,
                with: .color(f.color.opacity(0.010 + f.activity * 0.035)),
                lineWidth: max(0.35, f.radius * 0.0007)
            )
        }
    }

    // MARK: Organic Cross Links

    func drawOrganicCrossLinks(_ c: inout GraphicsContext, _ f: UFrame) {
        let count = Int(UMath.clamp(f.size / 19, 24, 68))

        for i in 0..<count {
            let a = CGFloat(i) * 2.47 + CGFloat(f.time) * 0.019
            let r0 = 0.14 + UMath.hash(i * 23) * 0.26
            let r1 = r0 + 0.20 + UMath.hash(i * 61) * 0.36

            let p0 = UMath.project(
                UPoint3(
                    x: cos(a) * r0,
                    y: sin(a) * r0 * 0.55,
                    z: UMath.hash(i * 17) * 1.5 - 0.75
                ),
                radius: f.radius,
                center: f.center
            )

            let p1 = UMath.project(
                UPoint3(
                    x: cos(a + 0.8) * r1,
                    y: sin(a + 0.8) * r1 * 0.55,
                    z: UMath.hash(i * 31) * 1.5 - 0.75
                ),
                radius: f.radius,
                center: f.center
            )

            let pulse = transferPulse(index: i * 211 + 5100, time: f.time)
            drawSegment(
                c: &c,
                from: p0.point,
                to: p1.point,
                color: pulse > 0.82 ? UltronPalette.cyan : f.color,
                opacity: 0.008 + f.activity * 0.038 + pulse * 0.07,
                width: max(0.35, f.radius * 0.00075),
                glow: pulse > 0.9
            )
        }
    }

    // MARK: Reassembly Shards

    func drawReassemblyShards(_ c: inout GraphicsContext, _ f: UFrame) {
        let count = Int(UMath.clamp(f.size / 14, 28, 76))

        for i in 0..<count {
            let pulse = ping(index: i * 227 + 5300, time: f.time)
            let phase = CGFloat(i) * 1.91 + CGFloat(f.time) * 0.06
            let startRadius = 0.16 + UMath.hash(i * 17) * 0.58
            let targetRadius = max(0.10, startRadius - pulse * 0.13)

            let p0 = CGPoint(
                x: f.center.x + cos(phase) * f.radius * startRadius,
                y: f.center.y + sin(phase) * f.radius * startRadius * 0.58
            )
            let p1 = CGPoint(
                x: f.center.x + cos(phase) * f.radius * targetRadius,
                y: f.center.y + sin(phase) * f.radius * targetRadius * 0.58
            )

            drawSegment(
                c: &c,
                from: p0,
                to: p1,
                color: pulse > 0.87 ? UltronPalette.electric : f.color,
                opacity: 0.012 + pulse * 0.12,
                width: max(0.4, f.radius * 0.001),
                glow: pulse > 0.9
            )
        }
    }

    // MARK: Neural Pulse Fronts

    func drawNeuralPulseFronts(_ c: inout GraphicsContext, _ f: UFrame) {
        for front in 0..<5 {
            let wave = (CGFloat(f.time) * (0.14 + CGFloat(front) * 0.023) + CGFloat(front) * 0.27)
                .truncatingRemainder(dividingBy: 1.0)

            let radius = f.radius * (0.13 + wave * 0.79)
            let alpha = (1 - wave) * (0.025 + f.neuralEnergy * 0.12)

            drawEllipse(
                c: &c,
                center: f.center,
                radius: radius,
                yScale: 0.48 + CGFloat(front % 3) * 0.08,
                rotation: CGFloat(f.time) * (0.03 + CGFloat(front) * 0.009),
                color: UltronPalette.electric.opacity(alpha),
                width: max(0.4, f.radius * 0.0012)
            )
        }
    }

    // MARK: Peripheral Tendrils

    func drawPeripheralTendrils(_ c: inout GraphicsContext, _ f: UFrame) {
        for i in 0..<18 {
            let a = CGFloat(i) * 2.83 + CGFloat(f.time) * 0.012
            var path = Path()

            for step in 0...10 {
                let u = CGFloat(step) / 10
                let radius = 0.48 + u * 0.40
                let wobble = 0.055 * CGFloat(sin(Double(step * 9 + i * 7) + f.time * 2.2))

                let p = CGPoint(
                    x: f.center.x + cos(a + wobble) * f.radius * radius,
                    y: f.center.y + sin(a + wobble) * f.radius * radius * 0.56
                )

                if step == 0 { path.move(to: p) }
                else { path.addLine(to: p) }
            }

            let packet = transferPulse(index: i * 241 + 5500, time: f.time)
            drawGlowPath(
                c: &c,
                path: path,
                color: packet > 0.82 ? UltronPalette.cyan : f.color,
                opacity: 0.006 + f.activity * 0.025 + packet * 0.04,
                width: max(0.3, f.radius * 0.00065)
            )
        }
    }

    // MARK: Voice Contraction

    func drawVoiceContractions(_ c: inout GraphicsContext, _ f: UFrame) {
        guard f.speaking else { return }

        for i in 0..<6 {
            let q = CGFloat(i) / 5
            let contraction = f.level * (0.012 + q * 0.022)
            let radius = f.radius * (0.26 + q * 0.10 - contraction)

            var path = Path()
            for sample in 0...48 {
                let a = CGFloat(sample) / 48 * UMath.tau + CGFloat(f.time) * (0.04 + q * 0.02)
                let jag = 1 + contraction * CGFloat(sin(Double(sample * 7 + i * 13) + f.time * 14))
                let p = CGPoint(
                    x: f.center.x + cos(a) * radius * jag,
                    y: f.center.y + sin(a) * radius * (0.38 + q * 0.12) * jag
                )

                if sample == 0 { path.move(to: p) }
                else { path.addLine(to: p) }
            }

            c.stroke(
                path,
                with: .color(UltronPalette.cyan.opacity(0.010 + f.level * 0.045)),
                lineWidth: max(0.35, f.radius * 0.00075)
            )
        }
    }



    // MARK: Final Optical Pass

    func drawOpticalEdgePass(_ c: inout GraphicsContext, _ f: UFrame) {
        let count = 14
        for i in 0..<count {
            let a = CGFloat(i) * 2.27 + CGFloat(f.time) * 0.019
            let radius = f.radius * (0.38 + CGFloat(i % 6) * 0.075)
            let p0 = CGPoint(
                x: f.center.x + cos(a) * radius,
                y: f.center.y + sin(a) * radius * 0.55
            )
            let p1 = CGPoint(
                x: f.center.x + cos(a + 0.07) * (radius + f.radius * 0.022),
                y: f.center.y + sin(a + 0.07) * (radius + f.radius * 0.022) * 0.55
            )
            let packet = ping(index: i * 313 + 11000, time: f.time)
            drawSegment(
                c: &c,
                from: p0,
                to: p1,
                color: UltronPalette.white,
                opacity: packet * 0.15 + f.neuralEnergy * 0.014,
                width: max(0.35, f.radius * 0.0008),
                glow: packet > 0.91
            )
        }
    }



    // MARK: Final Surface Highlights

    func drawSurfaceHighlights(_ c: inout GraphicsContext, _ f: UFrame) {
        for i in 0..<10 {
            let packet = transferPulse(index: i * 331 + 12000, time: f.time)
            guard packet > 0.82 else { continue }

            let a = CGFloat(i) * 2.73 + CGFloat(f.time) * 0.033
            let radius = f.radius * (0.30 + CGFloat(i % 5) * 0.11)
            let p = CGPoint(
                x: f.center.x + cos(a) * radius,
                y: f.center.y + sin(a) * radius * 0.56
            )

            drawDot(
                c: &c,
                point: p,
                radius: max(0.7, f.radius * 0.004),
                color: UltronPalette.white,
                opacity: packet * 0.22
            )
        }
    }


    // MARK: Primitive Rendering

    func drawEllipse(
        c: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        yScale: CGFloat,
        rotation: CGFloat,
        color: Color,
        width: CGFloat
    ) {
        var path = Path()
        for i in 0...96 {
            let a = CGFloat(i) / 96 * UMath.tau
            let x0 = cos(a) * radius
            let y0 = sin(a) * radius * yScale
            let x = center.x + x0 * cos(rotation) - y0 * sin(rotation)
            let y = center.y + x0 * sin(rotation) + y0 * cos(rotation)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        c.stroke(path, with: .color(color), lineWidth: width)
    }

    func drawSegment(
        c: inout GraphicsContext,
        from p0: CGPoint,
        to p1: CGPoint,
        color: Color,
        opacity: CGFloat,
        width: CGFloat,
        glow: Bool
    ) {
        if glow {
            c.stroke(
                Path { path in
                    path.move(to: p0)
                    path.addLine(to: p1)
                },
                with: .color(color.opacity(opacity * 0.12)),
                lineWidth: width * 5
            )
            c.stroke(
                Path { path in
                    path.move(to: p0)
                    path.addLine(to: p1)
                },
                with: .color(color.opacity(opacity * 0.24)),
                lineWidth: width * 2.2
            )
        }

        c.stroke(
            Path { path in
                path.move(to: p0)
                path.addLine(to: p1)
            },
            with: .color(color.opacity(opacity)),
            lineWidth: width
        )
    }

    func drawGlowPath(
        c: inout GraphicsContext,
        path: Path,
        color: Color,
        opacity: CGFloat,
        width: CGFloat
    ) {
        c.stroke(path, with: .color(color.opacity(opacity * 0.10)), lineWidth: width * 5)
        c.stroke(path, with: .color(color.opacity(opacity * 0.24)), lineWidth: width * 2.0)
        c.stroke(path, with: .color(color.opacity(opacity)), lineWidth: width)
    }

    func drawDot(
        c: inout GraphicsContext,
        point: CGPoint,
        radius: CGFloat,
        color: Color,
        opacity: CGFloat
    ) {
        let gradient = Gradient(colors: [
            color.opacity(opacity),
            color.opacity(opacity * 0.16),
            .clear
        ])
        c.drawRadialGradient(
            gradient,
            center: point,
            startRadius: 0,
            endRadius: radius * 4.8
        )
        c.fill(
            Path(ellipseIn: CGRect(
                x: point.x - radius * 0.55,
                y: point.y - radius * 0.55,
                width: radius * 1.1,
                height: radius * 1.1
            )),
            with: .color(color.opacity(opacity))
        )
    }

    // MARK: Procedural Timing

    func qScale(_ shell: Int) -> CGFloat {
        0.34 + CGFloat(shell % 4) * 0.08
    }

    func shellActivation(_ shell: Int, time: Double) -> CGFloat {
        let seed = Double(shell) * 1.731
        let wave = 0.5 + 0.5 * sin(time * (0.37 + Double(shell % 3) * 0.08) + seed)
        let pop = 0.5 + 0.5 * sin(time * 2.1 + seed * 4.3)
        return CGFloat(pow(wave, 4) * 0.75 + pow(pop, 9) * 0.25)
    }

    func transferPulse(index: Int, time: Double) -> CGFloat {
        let phase = UMath.hash(index * 17) * UMath.tau
        let carrier = 0.5 + 0.5 * sin(time * (0.65 + Double(index % 9) * 0.07) + Double(phase))
        return CGFloat(pow(Double(carrier), 6.5))
    }

    func ping(index: Int, time: Double) -> CGFloat {
        let phase = UMath.hash(index * 23) * UMath.tau
        let carrier = 0.5 + 0.5 * sin(time * (0.48 + Double(index % 7) * 0.11) + Double(phase))
        return CGFloat(pow(Double(carrier), 12.0))
    }
}

