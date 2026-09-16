import SwiftUI
import CoreGraphics
import Foundation

struct UltronRenderer {
    func render(context: inout GraphicsContext, frame f: UFrame) {
        var additive = context
        additive.blendMode = HologramManager.shared.currentBlendMode.graphicsBlendMode

        drawAtmosphere(&additive, f)
        drawFarOrganicVolume(&additive, f)
        drawGrowingShells(&additive, f)
        drawFracturedSurface(&additive, f)
        drawNeuralNetwork(&additive, f)
        drawDataStreams(&additive, f)
        drawCauseEffectPackets(&additive, f)
        drawAngularSpines(&additive, f)
        drawAudioEnergy(&additive, f)
        drawElectricalPings(&additive, f)
        drawCore(&additive, f)
        drawForegroundShell(&additive, f)
        drawFragments(&additive, f)
        drawShockwave(&additive, f)
        drawGlitchInstability(&additive, f)

        drawOrganicTendrils(&additive, f)
        drawFracturePlates(&additive, f)
        drawActivationCascade(&additive, f)
        drawSurfacePulses(&additive, f)
        drawDepthSparks(&additive, f)
        drawCodeFragments(&additive, f)

        drawCorticalRings(&additive, f)
        drawOrganicCrossLinks(&additive, f)
        drawReassemblyShards(&additive, f)
        drawNeuralPulseFronts(&additive, f)
        drawPeripheralTendrils(&additive, f)
        drawVoiceContractions(&additive, f)
        drawOpticalEdgePass(&additive, f)
        drawSurfaceHighlights(&additive, f)
        drawBloom(&additive, f)
    }

    // MARK: Atmosphere

    func drawAtmosphere(_ c: inout GraphicsContext, _ f: UFrame) {
        let pulse = 1 + f.bass * 0.075 + CGFloat(sin(f.time * 0.76)) * 0.012
        let g = Gradient(colors: [
            f.color.opacity(0.060 + f.activity * 0.022),
            UltronPalette.cyan.opacity(0.020 + f.activity * 0.012),
            .clear
        ])
        c.drawRadialGradient(
            g,
            center: f.center,
            startRadius: 0,
            endRadius: f.radius * 1.02 * pulse
        )
    }

    func drawFarOrganicVolume(_ c: inout GraphicsContext, _ f: UFrame) {
        let count = Int(UMath.clamp(f.size / 8.5, 90, 240))
        for i in 0..<count {
            let fi = CGFloat(i)
            let a = fi * 2.399 + CGFloat(f.time) * (0.003 + CGFloat(i % 7) * 0.001)
            let shell = 0.20 + UMath.hash(i * 19) * 0.72
            let organic = 0.86
                + 0.08 * CGFloat(sin(Double(i) * 0.71 + f.time * 0.42))
                + 0.06 * CGFloat(sin(Double(i) * 1.91 - f.time * 0.28))
            let p = UPoint3(
                x: cos(a) * shell * organic,
                y: sin(a) * shell * organic * 0.67,
                z: CGFloat(sin(Double(i) * 1.37 + f.time * 0.12)) * 0.72
            )
            let q = UMath.project(p, radius: f.radius, center: f.center)
            let depth = UMath.clamp((q.depth + 1) * 0.5)
            let flicker = 0.45 + 0.55 * CGFloat(sin(f.time * (0.7 + Double(i % 9) * 0.08) + Double(i)))
            let dot = max(0.35, f.radius * 0.0015)
            drawDot(
                c: &c,
                point: q.point,
                radius: dot * (1 + depth),
                color: f.color,
                opacity: (0.008 + f.activity * 0.018) * depth * flicker
            )
        }
    }

    // MARK: Center-Out Growth / Shells

    func drawGrowingShells(_ c: inout GraphicsContext, _ f: UFrame) {
        let shells = 10
        for shell in 0..<shells {
            let q = CGFloat(shell) / CGFloat(shells - 1)
            let radius = f.radius * (0.15 + q * 0.68)
            let activation = shellActivation(shell, time: f.time)
            let rotation = URotation(
                x: 0.18 + q * 0.61,
                y: CGFloat(f.time) * (0.011 + q * 0.018),
                z: CGFloat(f.time) * (-0.017 + q * 0.011)
            )
            drawOrganicShell(
                c: &c,
                f: f,
                radius: radius,
                rotation: rotation,
                shellIndex: shell,
                activation: activation
            )
        }
    }

    func drawOrganicShell(
        c: inout GraphicsContext,
        f: UFrame,
        radius: CGFloat,
        rotation: URotation,
        shellIndex: Int,
        activation: CGFloat
    ) {
        let segments = 24 + shellIndex * 4
        var last: CGPoint?

        for i in 0...segments {
            let u = CGFloat(i) / CGFloat(segments)
            let angle = u * UMath.tau

            let radialNoise =
                1.0
                + 0.055 * CGFloat(sin(Double(shellIndex * 17 + i * 3)) )
                + 0.035 * CGFloat(sin(Double(i * 11) + f.time * (1.7 + Double(shellIndex) * 0.2)))

            let spike = f.neuralEnergy * 0.055
                * max(0, CGFloat(sin(Double(i) * 1.73 + f.time * 5.0)))

            let p = UPoint3(
                x: cos(angle) * (radius / f.radius) * radialNoise,
                y: sin(angle) * (radius / f.radius) * (0.45 + qScale(shellIndex) * 0.26) * radialNoise,
                z: sin(angle * 2.0 + Double(shellIndex)) * 0.42 + spike
            )

            let projected = UMath.project(rotation.apply(p), radius: f.radius, center: f.center)

            if let previous = last {
                let depth = UMath.clamp((projected.depth + 1) * 0.5)
                let alpha = (0.010 + activation * 0.055 + f.activity * 0.022) * (0.30 + depth)
                drawSegment(
                    c: &c,
                    from: previous,
                    to: projected.point,
                    color: shellIndex % 3 == 0 ? UltronPalette.cyan : f.color,
                    opacity: alpha,
                    width: max(0.35, f.radius * (0.0008 + activation * 0.0009)),
                    glow: activation > 0.82
                )
            }

            last = projected.point
        }
    }

    // MARK: Fractured Surface

    func drawFracturedSurface(_ c: inout GraphicsContext, _ f: UFrame) {
        let count = Int(UMath.clamp(f.size / 12, 38, 105))
        for i in 0..<count {
            let seed = CGFloat(i)
            let angle = seed * 2.177 + CGFloat(f.time) * (0.017 + CGFloat(i % 6) * 0.004)
            let radius = 0.23 + UMath.hash(i * 43) * 0.65

            let p0 = UPoint3(
                x: cos(angle) * radius,
                y: sin(angle) * radius * 0.62,
                z: UMath.hash(i * 11) * 1.5 - 0.75
            )

            let branch = 0.018 + UMath.hash(i * 71) * 0.11
            let p1 = UPoint3(
                x: p0.x + cos(angle + 0.8) * branch,
                y: p0.y + sin(angle + 0.8) * branch,
                z: p0.z + (UMath.hash(i * 91) - 0.5) * 0.30
            )

            let q0 = UMath.project(p0, radius: f.radius, center: f.center)
            let q1 = UMath.project(p1, radius: f.radius, center: f.center)
            let pulse = ping(index: i * 31, time: f.time)

            drawSegment(
                c: &c,
                from: q0.point,
                to: q1.point,
                color: pulse > 0.86 ? UltronPalette.electric : f.color,
                opacity: 0.018 + f.activity * 0.07 + pulse * 0.13,
                width: max(0.35, f.radius * 0.0011),
                glow: pulse > 0.90
            )
        }
    }

    // MARK: Neural Network

    func drawNeuralNetwork(_ c: inout GraphicsContext, _ f: UFrame) {
        let nodeCount = Int(UMath.clamp(f.size / 15, 34, 96))
        var nodes: [UProjection] = []
        nodes.reserveCapacity(nodeCount)

        for i in 0..<nodeCount {
            let fi = CGFloat(i)
            let angle = fi * 2.399 + CGFloat(f.time) * (0.015 + CGFloat(i % 4) * 0.004)
            let radius = 0.12 + UMath.hash(i * 17) * 0.78
            let p = UPoint3(
                x: cos(angle) * radius,
                y: sin(angle) * radius * (0.45 + 0.22 * UMath.hash(i * 23)),
                z: UMath.hash(i * 61) * 1.6 - 0.8
            )
            nodes.append(UMath.project(p, radius: f.radius, center: f.center))
        }

        for i in 0..<nodes.count {
            let neighborA = (i * 5 + 7) % nodes.count
            let neighborB = (i * 11 + 13) % nodes.count

            drawNeuralEdge(
                c: &c,
                f: f,
                a: nodes[i],
                b: nodes[neighborA],
                index: i
            )

            if i % 3 == 0 {
                drawNeuralEdge(
                    c: &c,
                    f: f,
                    a: nodes[i],
                    b: nodes[neighborB],
                    index: i + 101
                )
            }
        }

        for (i, node) in nodes.enumerated() {
            let pulse = ping(index: i * 43, time: f.time)
            drawDot(
                c: &c,
                point: node.point,
                radius: max(0.55, f.radius * (0.0015 + pulse * 0.003)),
                color: pulse > 0.90 ? UltronPalette.electric : f.color,
                opacity: 0.025 + pulse * 0.19 + f.activity * 0.025
            )
        }
    }

    func drawNeuralEdge(
        c: inout GraphicsContext,
        f: UFrame,
        a: UProjection,
        b: UProjection,
        index: Int
    ) {
        let pulse = transferPulse(index: index, time: f.time)
        let depth = UMath.clamp((a.depth + b.depth) * 0.25 + 0.5)
        let alpha = (0.012 + f.activity * 0.06 + pulse * 0.17) * (0.35 + depth)

        var path = Path()
        path.move(to: a.point)

        let mx = (a.point.x + b.point.x) * 0.5
        let my = (a.point.y + b.point.y) * 0.5
        let bend = CGFloat(sin(Double(index) * 1.73 + f.time * 1.8)) * f.radius * 0.025

        path.addQuadCurve(
            to: b.point,
            control: CGPoint(x: mx - bend, y: my + bend)
        )

        c.stroke(
            path,
            with: .color((pulse > 0.75 ? UltronPalette.cyan : f.color).opacity(alpha)),
            lineWidth: max(0.35, f.radius * (0.0008 + pulse * 0.001))
        )

        if pulse > 0.72 {
            let packet = CGPoint(
                x: a.point.x + (b.point.x - a.point.x) * pulse,
                y: a.point.y + (b.point.y - a.point.y) * pulse
            )
            drawDot(
                c: &c,
                point: packet,
                radius: max(0.7, f.radius * 0.0032),
                color: UltronPalette.electric,
                opacity: pulse * 0.55
            )
        }
    }

    // MARK: Data Streams

    func drawDataStreams(_ c: inout GraphicsContext, _ f: UFrame) {
        let count = Int(UMath.clamp(f.size / 18, 24, 66))
        for i in 0..<count {
            let fi = CGFloat(i)
            let seed = fi * 2.91
            let phase = seed + CGFloat(f.time) * (0.09 + CGFloat(i % 8) * 0.013)
            let points = 15
            var path = Path()

            for step in 0..<points {
                let u = CGFloat(step) / CGFloat(points - 1)
                let angle = phase + u * (1.25 + CGFloat(i % 5) * 0.31)
                let radius = 0.07 + u * (0.82 + 0.06 * UMath.hash(i * 37))
                let z = sin(angle * 1.9 + seed) * 0.66

                let p = UPoint3(
                    x: cos(angle) * radius,
                    y: sin(angle) * radius * 0.55,
                    z: z
                )
                let q = UMath.project(p, radius: f.radius, center: f.center).point
                if step == 0 { path.move(to: q) }
                else { path.addLine(to: q) }
            }

            let pulse = transferPulse(index: i * 29 + 900, time: f.time)
            c.stroke(
                path,
                with: .color(f.color.opacity(0.012 + f.activity * 0.055 + pulse * 0.055)),
                lineWidth: max(0.35, f.radius * 0.0009)
            )

            if pulse > 0.76 {
                let a = phase + pulse * 1.4
                let rr = 0.07 + pulse * 0.82
                let p = UPoint3(
                    x: cos(a) * rr,
                    y: sin(a) * rr * 0.55,
                    z: sin(a * 1.9 + seed) * 0.66
                )
                let q = UMath.project(p, radius: f.radius, center: f.center)
                drawDot(
                    c: &c,
                    point: q.point,
                    radius: max(0.7, f.radius * 0.0035),
                    color: UltronPalette.electric,
                    opacity: pulse * 0.62
                )
            }
        }
    }

    // MARK: Cause and Effect

    func drawCauseEffectPackets(_ c: inout GraphicsContext, _ f: UFrame) {
        let events = 12
        for i in 0..<events {
            let packet = transferPulse(index: i * 83 + 1200, time: f.time)
            guard packet > 0.74 else { continue }

            let a = CGFloat(i) * 2.41 + CGFloat(f.time) * 0.08
            let r0 = f.radius * (0.18 + CGFloat(i % 5) * 0.11)
            let r1 = r0 + f.radius * (0.08 + packet * 0.14)

            let p0 = CGPoint(
                x: f.center.x + cos(a) * r0,
                y: f.center.y + sin(a) * r0 * 0.58
            )
            let p1 = CGPoint(
                x: f.center.x + cos(a + 0.45) * r1,
                y: f.center.y + sin(a + 0.45) * r1 * 0.58
            )

            drawSegment(
                c: &c,
                from: p0,
                to: p1,
                color: UltronPalette.electric,
                opacity: packet * 0.52,
                width: max(0.6, f.radius * 0.002),
                glow: true
            )
        }
    }

    // MARK: Angular Spines

    func drawAngularSpines(_ c: inout GraphicsContext, _ f: UFrame) {
        let count = 18
        for i in 0..<count {
            let a = CGFloat(i) / CGFloat(count) * UMath.tau + CGFloat(f.time) * (i.isMultiple(of: 2) ? 0.028 : -0.034)
            let inner = 0.08 + UMath.hash(i * 41) * 0.15
            let outer = 0.35 + UMath.hash(i * 71) * 0.60

            var path = Path()
            let steps = 6
            for j in 0...steps {
                let u = CGFloat(j) / CGFloat(steps)
                let rr = inner + (outer - inner) * u
                let angular = a + CGFloat(sin(Double(j * 13 + i * 7) + f.time * 1.2)) * 0.08
                let z = (UMath.hash(i * 17 + j * 3) - 0.5) * 1.2
                let p = UPoint3(
                    x: cos(angular) * rr,
                    y: sin(angular) * rr * 0.60,
                    z: z
                )
                let q = UMath.project(p, radius: f.radius, center: f.center).point
                if j == 0 { path.move(to: q) }
                else { path.addLine(to: q) }
            }

            let pulse = ping(index: i * 59, time: f.time)
            c.stroke(
                path,
                with: .color(f.color.opacity(0.012 + f.activity * 0.045 + pulse * 0.07)),
                lineWidth: max(0.4, f.radius * (0.001 + pulse * 0.001))
            )
        }
    }

    // MARK: Audio Energy

    func drawAudioEnergy(_ c: inout GraphicsContext, _ f: UFrame) {
        let samples = Int(UMath.clamp(f.size * 0.78, 150, 320))
        let inner = f.radius * 0.18

        for i in 0..<samples {
            let u = CGFloat(i) / CGFloat(samples)
            let angle = u * UMath.tau + CGFloat(f.time) * 0.022

            let spectral = 0.16 + 0.84 * abs(sin(Double(i) * 0.119 + f.time * 1.7))
            let neural = 0.42 + 0.58 * UMath.noise(u * 29.0, CGFloat(i % 31))
            let amplitude = f.neuralEnergy * spectral * neural
            let tooth = CGFloat(abs(sin(Double(i) * 0.37)))
            let length = f.radius * (0.007 + amplitude * (0.09 + tooth * 0.09))

            let r0 = inner + CGFloat(i % 5) * f.radius * 0.002
            let r1 = r0 + length

            let p0 = CGPoint(
                x: f.center.x + cos(angle) * r0,
                y: f.center.y + sin(angle) * r0 * 0.64
            )
            let p1 = CGPoint(
                x: f.center.x + cos(angle) * r1,
                y: f.center.y + sin(angle) * r1 * 0.64
            )

            drawSegment(
                c: &c,
                from: p0,
                to: p1,
                color: amplitude > 0.52 ? UltronPalette.electric : f.color,
                opacity: 0.018 + amplitude * 0.64,
                width: max(0.45, f.radius * (0.0009 + amplitude * 0.0018)),
                glow: amplitude > 0.62
            )
        }
    }

    // MARK: Electrical Pings

    func drawElectricalPings(_ c: inout GraphicsContext, _ f: UFrame) {
        let eventCount = 8 + Int(f.activity * 7)
        for i in 0..<eventCount {
            let pulse = ping(index: i * 97 + 2200, time: f.time)
            guard pulse > 0.88 else { continue }

            let a = CGFloat(i) * 2.77 + CGFloat(f.time) * 0.07
            let radius = f.radius * (0.24 + CGFloat(i % 5) * 0.10)
            let p0 = CGPoint(
                x: f.center.x + cos(a) * radius * 0.45,
                y: f.center.y + sin(a) * radius * 0.28
            )
            let p1 = CGPoint(
                x: f.center.x + cos(a + 0.35) * radius,
                y: f.center.y + sin(a + 0.35) * radius * 0.58
            )

            drawJaggedArc(
                c: &c,
                from: p0,
                to: p1,
                seed: i * 31,
                frame: f,
                strength: (pulse - 0.88) * 8
            )
        }
    }

    func drawJaggedArc(
        c: inout GraphicsContext,
        from p0: CGPoint,
        to p1: CGPoint,
        seed: Int,
        frame f: UFrame,
        strength: CGFloat
    ) {
        let segments = 7 + seed % 5
        var path = Path()
        for i in 0...segments {
            let u = CGFloat(i) / CGFloat(segments)
            let bx = p0.x + (p1.x - p0.x) * u
            let by = p0.y + (p1.y - p0.y) * u
            let jitter = CGFloat(sin(Double(seed * 13 + i * 31) + f.time * 17.0))
                * f.radius * 0.018 * sin(.pi * u)
            let x = bx - jitter * 0.45
            let y = by + jitter
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }

        drawGlowPath(
            c: &c,
            path: path,
            color: UltronPalette.electric,
            opacity: 0.05 + strength * 0.28,
            width: max(0.5, f.radius * 0.0022)
        )
    }

    // MARK: Core

    func drawCore(_ c: inout GraphicsContext, _ f: UFrame) {
        let birth = 1 + 0.035 * CGFloat(sin(f.time * 1.4))
        let reaction = 1 + f.level * 0.07 + f.bass * 0.025
        let coreRadius = f.radius * 0.105 * birth * reaction

        for layer in stride(from: 10, through: 1, by: -1) {
            let q = CGFloat(layer) / 10
            let rr = coreRadius * (0.6 + q * 2.2)
            let gradient = Gradient(colors: [
                UltronPalette.electric.opacity(0.010 + f.level * 0.008),
                f.color.opacity(0.016 + f.activity * 0.012),
                .clear
            ])
            c.drawRadialGradient(
                gradient,
                center: f.center,
                startRadius: 0,
                endRadius: rr
            )
        }

        // Nested irregular shells: this is the "living" processing heart.
        for shell in 0..<7 {
            let q = CGFloat(shell) / 6
            let sides = 7 + shell
            let rr = coreRadius * (0.48 + q * 0.78)
            var path = Path()

            for i in 0...sides {
                let a = CGFloat(i) / CGFloat(sides) * UMath.tau
                    + CGFloat(f.time) * (shell.isMultiple(of: 2) ? 0.06 : -0.08)
                let distortion = 0.84
                    + 0.12 * CGFloat(sin(Double(i * 11 + shell * 7) + f.time * 3.0))
                let p = CGPoint(
                    x: f.center.x + cos(a) * rr * distortion,
                    y: f.center.y + sin(a) * rr * 0.57 * distortion
                )
                if i == 0 { path.move(to: p) }
                else { path.addLine(to: p) }
            }

            c.stroke(
                path,
                with: .color((shell == 0 ? UltronPalette.electric : f.color).opacity(
                    0.08 + q * 0.12 + f.level * 0.08
                )),
                lineWidth: max(0.55, f.radius * (0.0012 + q * 0.001))
            )
        }

        drawDot(
            c: &c,
            point: f.center,
            radius: max(1.2, coreRadius * 0.16),
            color: UltronPalette.white,
            opacity: 0.96
        )
    }

    // MARK: Foreground Shell

    func drawForegroundShell(_ c: inout GraphicsContext, _ f: UFrame) {
        for i in 0..<5 {
            let q = CGFloat(i) / 4
            let radius = f.radius * (0.43 + q * 0.40)
            let rotation = URotation(
                x: CGFloat(f.time) * (0.008 + q * 0.009),
                y: 0.35 + q * 0.71,
                z: CGFloat(f.time) * (-0.012 + q * 0.006)
            )

            let segments = 20 + i * 4
            for segment in 0..<segments {
                if (segment + i * 5) % 7 == 0 { continue }

                let a0 = CGFloat(segment) / CGFloat(segments) * UMath.tau
                let a1 = a0 + UMath.tau / CGFloat(segments) * (0.32 + 0.28 * UMath.hash(segment + i * 41))

                let p0 = rotation.apply(UPoint3(
                    x: cos(a0) * radius / f.radius,
                    y: sin(a0) * radius / f.radius * 0.55,
                    z: sin(a0 * 3.0 + Double(i)) * 0.45
                ))
                let p1 = rotation.apply(UPoint3(
                    x: cos(a1) * radius / f.radius,
                    y: sin(a1) * radius / f.radius * 0.55,
                    z: sin(a1 * 3.0 + Double(i)) * 0.45
                ))

                let q0 = UMath.project(p0, radius: f.radius, center: f.center)
                let q1 = UMath.project(p1, radius: f.radius, center: f.center)
                let depth = UMath.clamp((q0.depth + q1.depth) * 0.25 + 0.5)
                let pulse = transferPulse(index: segment + i * 71, time: f.time)

                drawSegment(
                    c: &c,
                    from: q0.point,
                    to: q1.point,
                    color: pulse > 0.82 ? UltronPalette.cyan : f.color,
                    opacity: (0.018 + pulse * 0.10) * (0.35 + depth),
                    width: max(0.4, f.radius * (0.0009 + pulse * 0.001)),
                    glow: pulse > 0.9
                )
            }
        }
    }

    // MARK: Fragments

    func drawFragments(_ c: inout GraphicsContext, _ f: UFrame) {
        let count = Int(UMath.clamp(f.size / 16, 24, 74))
        for i in 0..<count {
            let fi = CGFloat(i)
            let a = fi * 4.11 + CGFloat(f.time) * (0.021 + CGFloat(i % 4) * 0.007)
            let radius = f.radius * (0.38 + UMath.hash(i * 33) * 0.50)
            let p = CGPoint(
                x: f.center.x + cos(a) * radius,
                y: f.center.y + sin(a) * radius * 0.57
            )

            let length = f.radius * (0.006 + UMath.hash(i * 17) * 0.018)
            let angle = a + CGFloat(UMath.hash(i * 59) - 0.5)
            let q = CGPoint(
                x: p.x + cos(angle) * length,
                y: p.y + sin(angle) * length
            )

            let pulse = ping(index: i * 113, time: f.time)
            drawSegment(
                c: &c,
                from: p,
                to: q,
                color: pulse > 0.88 ? UltronPalette.electric : f.color,
                opacity: 0.018 + f.activity * 0.05 + pulse * 0.08,
                width: max(0.35, f.radius * 0.0011),
                glow: pulse > 0.92
            )
        }
    }

}
