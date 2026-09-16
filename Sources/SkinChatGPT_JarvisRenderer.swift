import SwiftUI
import CoreGraphics
import Foundation

struct JARVISRenderer {
    func render(context: inout GraphicsContext, frame f: JARVISFrame) {
        var additive = context
        additive.blendMode = HologramManager.shared.currentBlendMode.graphicsBlendMode

        drawBackgroundVolume(&additive, f)
        drawOuterAtmosphere(&additive, f)

        // Far-to-near ordering is intentional. The hologram is a spatial
        // volume, not a collection of circles painted on one plane.
        drawDeepDataField(&additive, f)
        drawOrreryBackRings(&additive, f)
        drawOrbitalDataBelts(&additive, f)
        drawCrossAxisRings(&additive, f)
        drawMovingDataStreams(&additive, f)
        drawAngularDataBlocks(&additive, f)
        drawRadialEqualizer(&additive, f)
        drawTelemetryTicks(&additive, f)
        drawFineFilaments(&additive, f)
        drawDataNodes(&additive, f)
        drawCentralHeart(&additive, f)
        drawHeartRays(&additive, f)
        drawForegroundRings(&additive, f)
        drawVoiceVibration(&additive, f)
        drawTransientGlints(&additive, f)

        drawDataRibbon(&additive, f)
        drawAxisMarkers(&additive, f)
        drawRingDeformation(&additive, f)
        drawCoreCage(&additive, f)
        drawParticleTrails(&additive, f)
        drawDepthFlares(&additive, f)

        drawHardDrivePlatterData(&additive, f)
        drawMeridianBands(&additive, f)
        drawPeripheralPackets(&additive, f)
        drawMicroDataClusters(&additive, f)
        drawAudioHalo(&additive, f)
        drawCalibrationArcs(&additive, f)
        drawOpticalEdgePass(&additive, f)
        drawScanPlane(&additive, f)
    }

    // MARK: Atmosphere

    func drawBackgroundVolume(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        let pulse = 1 + f.bass * 0.055 + CGFloat(sin(f.time * 0.82)) * 0.012
        let g = Gradient(colors: [
            f.color.opacity(0.055 + f.activity * 0.018),
            JARVISPalette.amber.opacity(0.022 + f.activity * 0.012),
            .clear
        ])
        c.drawRadialGradient(
            g,
            center: f.center,
            startRadius: 0,
            endRadius: f.radius * 0.98 * pulse
        )
    }

    func drawOuterAtmosphere(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        for i in 0..<8 {
            let q = CGFloat(i) / 7
            let r = f.radius * (0.64 + q * 0.36)
            let opacity = (1 - q) * (0.010 + f.activity * 0.009)
            drawEllipse(
                c: &c,
                center: f.center,
                radius: r,
                yScale: 0.54 + q * 0.11,
                rotation: CGFloat(f.time) * (0.01 + q * 0.006),
                color: f.color.opacity(opacity),
                width: max(0.35, f.radius * 0.001)
            )
        }
    }

    // MARK: Deep Data Field

    func drawDeepDataField(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        let count = Int(JARVISMath.clamp(f.size / 9, 55, 170))
        for i in 0..<count {
            let seed = CGFloat(i)
            let a = seed * 2.399 + CGFloat(f.time) * (0.004 + CGFloat(i % 5) * 0.001)
            let rr = f.radius * (0.18 + JARVISMath.hash(i * 17) * 0.78)
            let p = JPoint3(
                x: cos(a) * rr / f.radius,
                y: sin(a) * rr / f.radius * 0.64,
                z: JARVISMath.hash(i * 31) * 1.6 - 0.8
            )
            let q = JARVISMath.project(p, radius: f.radius, center: f.center)
            let depthAlpha = JARVISMath.clamp((q.depth + 1) * 0.5)
            let twinkle = 0.45 + 0.55 * CGFloat(sin(f.time * (0.8 + Double(i % 7) * 0.13) + Double(i)))
            let dot = max(0.35, f.radius * (i % 17 == 0 ? 0.004 : 0.0016))
            c.fill(
                Path(ellipseIn: CGRect(
                    x: q.point.x - dot,
                    y: q.point.y - dot,
                    width: dot * 2,
                    height: dot * 2
                )),
                with: .color(f.color.opacity((0.012 + f.activity * 0.018) * depthAlpha * twinkle))
            )
        }
    }

    // MARK: Orrery

    func drawOrreryBackRings(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        let rings: [(CGFloat, CGFloat, CGFloat, CGFloat, Int)] = [
            (0.30, 0.34, 0.090, 0.015, 22),
            (0.40, 0.55, -0.065, -0.018, 30),
            (0.50, 0.78, 0.045, 0.025, 36),
            (0.61, 0.43, -0.031, -0.015, 44),
            (0.72, 0.68, 0.019, 0.010, 52),
            (0.81, 0.31, -0.012, -0.008, 60)
        ]

        for (index, r) in rings.enumerated() {
            let radius = f.radius * r.0
            let phase = CGFloat(f.time) * r.2 + CGFloat(index) * 1.71
            let rotation = JRotation(
                x: 0.10 + r.1,
                y: phase * 0.47,
                z: phase
            )
            drawOrreryRing(
                c: &c,
                f: f,
                radius: radius,
                rotation: rotation,
                yScale: 0.32 + r.1 * 0.45,
                segments: r.4,
                phase: phase,
                strength: 0.35 - CGFloat(index) * 0.035
            )
        }
    }

    func drawOrreryRing(
        c: inout GraphicsContext,
        f: JARVISFrame,
        radius: CGFloat,
        rotation: JRotation,
        yScale: CGFloat,
        segments: Int,
        phase: CGFloat,
        strength: CGFloat
    ) {
        for i in 0..<segments {
            let fi = CGFloat(i)
            let a0 = fi / CGFloat(segments) * JARVISMath.tau + phase
            let a1 = a0 + JARVISMath.tau / CGFloat(segments) * 0.66

            let p0 = JARVISMath.ringPoint(
                angle: a0,
                radius: radius / f.radius,
                rotation: rotation,
                yScale: yScale,
                zWarp: 0.025
            )
            let p1 = JARVISMath.ringPoint(
                angle: a1,
                radius: radius / f.radius,
                rotation: rotation,
                yScale: yScale,
                zWarp: 0.025
            )

            let q0 = JARVISMath.project(p0, radius: f.radius, center: f.center)
            let q1 = JARVISMath.project(p1, radius: f.radius, center: f.center)
            let depth = JARVISMath.clamp((q0.depth + q1.depth) * 0.25 + 0.5)
            let dataPulse = dataPulse(index: i, time: f.time, speed: 2.0)
            let active = 0.55 + f.talkEnergy * 1.8 + dataPulse * 0.22

            let baseOpacity = strength * (0.20 + depth * 0.70) * active
            let width = max(0.55, f.radius * (0.0016 + depth * 0.0010))

            drawGlowSegment(
                c: &c,
                from: q0.point,
                to: q1.point,
                color: f.color,
                opacity: baseOpacity,
                width: width,
                glow: depth > 0.55 && dataPulse > 0.78
            )
        }
    }

    // MARK: Data Belts

    func drawOrbitalDataBelts(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        let beltCount = 9
        for belt in 0..<beltCount {
            let q = CGFloat(belt) / CGFloat(beltCount - 1)
            let radius = f.radius * (0.24 + q * 0.58)
            let direction: CGFloat = belt.isMultiple(of: 2) ? 1 : -1
            let phase = CGFloat(f.time) * (0.13 + q * 0.035) * direction + q * 6.2
            let tilt = JRotation(
                x: 0.22 + q * 0.58,
                y: phase * 0.20,
                z: phase * 0.71
            )

            drawDataBelt(
                c: &c,
                f: f,
                radius: radius,
                rotation: tilt,
                phase: phase,
                beltIndex: belt
            )
        }
    }

    func drawDataBelt(
        c: inout GraphicsContext,
        f: JARVISFrame,
        radius: CGFloat,
        rotation: JRotation,
        phase: CGFloat,
        beltIndex: Int
    ) {
        let blockCount = 34 + beltIndex * 5
        for block in 0..<blockCount {
            let fi = CGFloat(block)
            let a = fi / CGFloat(blockCount) * JARVISMath.tau + phase
            let next = a + JARVISMath.tau / CGFloat(blockCount) * 0.72

            let p0 = JARVISMath.ringPoint(
                angle: a,
                radius: radius / f.radius,
                rotation: rotation,
                yScale: 0.52,
                zWarp: 0.035
            )
            let p1 = JARVISMath.ringPoint(
                angle: next,
                radius: radius / f.radius,
                rotation: rotation,
                yScale: 0.52,
                zWarp: 0.035
            )

            let q0 = JARVISMath.project(p0, radius: f.radius, center: f.center)
            let q1 = JARVISMath.project(p1, radius: f.radius, center: f.center)
            let depth = JARVISMath.clamp((q0.depth + q1.depth) * 0.25 + 0.5)

            let carrier = dataPulse(index: block + beltIndex * 41, time: f.time, speed: 1.2 + Double(beltIndex) * 0.11)
            let audio = f.talkEnergy * (0.5 + carrier)
            let opacity = (0.035 + depth * 0.12) * (0.55 + carrier * 0.85 + audio)

            let width = max(0.5, f.radius * (0.0013 + depth * 0.0014))
            drawGlowSegment(
                c: &c,
                from: q0.point,
                to: q1.point,
                color: beltIndex % 4 == 0 ? JARVISPalette.amber : f.color,
                opacity: opacity,
                width: width,
                glow: carrier > 0.88
            )

            if block % 7 == 0 {
                drawDataBlock(
                    c: &c,
                    at: q0.point,
                    tangentTo: q1.point,
                    scale: width * 4.5,
                    opacity: opacity * 1.7,
                    color: JARVISPalette.gold
                )
            }
        }
    }

    func drawDataBlock(
        c: inout GraphicsContext,
        at p: CGPoint,
        tangentTo q: CGPoint,
        scale: CGFloat,
        opacity: CGFloat,
        color: Color
    ) {
        let dx = q.x - p.x
        let dy = q.y - p.y
        let angle = atan2(dy, dx)
        let w = max(1.0, scale * 2.2)
        let h = max(0.7, scale * 0.65)
        var path = Path()
        let ca = CGFloat(cos(angle))
        let sa = CGFloat(sin(angle))
        let corners = [
            CGPoint(x: -w, y: -h),
            CGPoint(x: w, y: -h),
            CGPoint(x: w, y: h),
            CGPoint(x: -w, y: h)
        ]
        for (i, corner) in corners.enumerated() {
            let x = p.x + corner.x * ca - corner.y * sa
            let y = p.y + corner.x * sa + corner.y * ca
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        c.fill(path, with: .color(color.opacity(opacity * 0.20)))
        c.stroke(path, with: .color(color.opacity(opacity)), lineWidth: max(0.35, scale * 0.20))
    }

    // MARK: Cross Axis

    func drawCrossAxisRings(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        let axes: [(JRotation, CGFloat, CGFloat)] = [
            (JRotation(x: .pi * 0.48, y: 0.08, z: CGFloat(f.time) * 0.03), 0.58, 0.12),
            (JRotation(x: 0.12, y: .pi * 0.50, z: CGFloat(f.time) * -0.021), 0.49, -0.08),
            (JRotation(x: .pi * 0.25, y: .pi * 0.17, z: CGFloat(f.time) * 0.014), 0.76, 0.05),
            (JRotation(x: .pi * 0.68, y: .pi * 0.38, z: CGFloat(f.time) * -0.011), 0.66, -0.04)
        ]

        for (i, item) in axes.enumerated() {
            let rr = f.radius * item.1
            drawOrreryRing(
                c: &c,
                f: f,
                radius: rr,
                rotation: item.0,
                yScale: 0.22 + CGFloat(i) * 0.11,
                segments: 46 + i * 9,
                phase: item.2,
                strength: 0.13
            )
        }
    }

    // MARK: Moving Streams

    func drawMovingDataStreams(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        let streamCount = Int(JARVISMath.clamp(f.size / 24, 16, 44))
        for i in 0..<streamCount {
            let fi = CGFloat(i)
            let base = fi * 1.93
            let speed = 0.10 + CGFloat(i % 7) * 0.018
            let phase = base + CGFloat(f.time) * speed

            var points: [CGPoint] = []
            for step in 0..<17 {
                let u = CGFloat(step) / 16
                let angle = phase + u * (1.0 + CGFloat(i % 5) * 0.22)
                let radius = 0.12 + u * 0.66
                let z = sin(angle * 1.7 + fi) * 0.58
                let p = JPoint3(
                    x: cos(angle) * radius,
                    y: sin(angle) * radius * 0.58,
                    z: z
                )
                points.append(JARVISMath.project(p, radius: f.radius, center: f.center).point)
            }

            var path = Path()
            for (index, point) in points.enumerated() {
                if index == 0 { path.move(to: point) }
                else { path.addLine(to: point) }
            }

            let packet = dataPulse(index: i * 19, time: f.time, speed: 2.4)
            let opacity = 0.018 + f.activity * 0.10 + packet * 0.18
            c.stroke(path, with: .color(f.color.opacity(opacity)), lineWidth: max(0.35, f.radius * 0.0011))

            if packet > 0.72 {
                let maxIdx = points.count - 1
                let packetIdx = min(maxIdx, Int(packet * CGFloat(maxIdx)))
                if let packetPoint = points[safe: packetIdx] {
                    drawSoftDot(
                        c: &c,
                        point: packetPoint,
                        radius: max(0.7, f.radius * 0.004),
                        color: JARVISPalette.hot,
                        opacity: packet * 0.75
                    )
                }
            }
        }
    }

    // MARK: Angular Data Blocks

    func drawAngularDataBlocks(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        let count = Int(JARVISMath.clamp(f.size / 14, 24, 80))
        for i in 0..<count {
            let fi = CGFloat(i)
            let angle = fi * 2.31 + CGFloat(f.time) * (0.018 + CGFloat(i % 5) * 0.003)
            let radius = 0.30 + JARVISMath.hash(i * 29) * 0.50
            let p = JPoint3(
                x: cos(angle) * radius,
                y: sin(angle) * radius * 0.62,
                z: JARVISMath.hash(i * 53) * 1.4 - 0.7
            )
            let q = JARVISMath.project(p, radius: f.radius, center: f.center)
            let pulse = dataPulse(index: i + 700, time: f.time, speed: 0.9)
            let block = max(0.8, f.radius * (0.003 + pulse * 0.003))
            drawMicroBracket(
                c: &c,
                center: q.point,
                radius: block,
                angle: angle,
                color: f.color.opacity(0.035 + pulse * 0.11),
                width: max(0.35, f.radius * 0.001)
            )
        }
    }

    // MARK: Audio / Volume

    func drawRadialEqualizer(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        let samples = Int(JARVISMath.clamp(f.size * 0.72, 128, 300))
        let inner = f.radius * 0.20

        for i in 0..<samples {
            let u = CGFloat(i) / CGFloat(samples)
            let angle = u * JARVISMath.tau + CGFloat(f.time) * 0.018
            let spectral = 0.20 + 0.80 * abs(sin(Double(i) * 0.087 + f.time * 1.3))
            let carrier = 0.42 + 0.58 * JARVISMath.noise(u * 17.0, CGFloat(i % 23))
            let amplitude = f.talkEnergy * spectral * carrier
            let jitter = CGFloat(sin(Double(i) * 0.73 + f.time * 8.0)) * f.talkEnergy * 0.012
            let r0 = inner + jitter * f.radius
            let r1 = r0 + f.radius * (0.012 + amplitude * 0.14)

            let p0 = CGPoint(
                x: f.center.x + cos(angle) * r0,
                y: f.center.y + sin(angle) * r0 * 0.68
            )
            let p1 = CGPoint(
                x: f.center.x + cos(angle) * r1,
                y: f.center.y + sin(angle) * r1 * 0.68
            )

            let alpha = 0.025 + amplitude * 0.52
            drawGlowSegment(
                c: &c,
                from: p0,
                to: p1,
                color: amplitude > 0.55 ? JARVISPalette.gold : f.color,
                opacity: alpha,
                width: max(0.45, f.radius * (0.001 + amplitude * 0.0014)),
                glow: amplitude > 0.65
            )
        }
    }

    func drawVoiceVibration(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        guard f.speaking else { return }

        // The film's JARVIS was explicitly rigged so dialogue waveform activity
        // drove vibration and ring motion. Here we create several independent
        // vibration fields rather than globally scaling the whole hologram.
        for layer in 0..<7 {
            let q = CGFloat(layer) / 6
            let count = 28 + layer * 8
            for i in 0..<count {
                let a = CGFloat(i) / CGFloat(count) * JARVISMath.tau
                let band = 0.5 + 0.5 * CGFloat(sin(Double(i * 13 + layer * 7) + f.time * 12.0))
                let energy = f.level * band
                let rr = f.radius * (0.30 + q * 0.44 + energy * 0.018)
                let wobble = energy * f.radius * 0.028
                let x = f.center.x + cos(a) * (rr + wobble)
                let y = f.center.y + sin(a) * (rr + wobble) * (0.40 + q * 0.05)
                let dot = max(0.4, f.radius * (0.0012 + energy * 0.0024))
                drawSoftDot(
                    c: &c,
                    point: CGPoint(x: x, y: y),
                    radius: dot,
                    color: energy > 0.55 ? JARVISPalette.gold : f.color,
                    opacity: 0.03 + energy * 0.22
                )
            }
        }
    }

    // MARK: Telemetry

    func drawTelemetryTicks(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        for ring in 0..<5 {
            let radius = f.radius * (0.36 + CGFloat(ring) * 0.105)
            let count = 48 + ring * 16
            let phase = CGFloat(f.time) * (ring.isMultiple(of: 2) ? 0.012 : -0.017)

            for i in 0..<count {
                let major = i % (ring + 3) == 0
                let a = CGFloat(i) / CGFloat(count) * JARVISMath.tau + phase
                let len = radius * (major ? 0.018 : 0.007)

                let p0 = CGPoint(
                    x: f.center.x + cos(a) * radius,
                    y: f.center.y + sin(a) * radius * 0.64
                )
                let p1 = CGPoint(
                    x: f.center.x + cos(a) * (radius + len),
                    y: f.center.y + sin(a) * (radius + len) * 0.64
                )

                c.stroke(
                    Path { path in
                        path.move(to: p0)
                        path.addLine(to: p1)
                    },
                    with: .color(f.color.opacity(major ? 0.055 : 0.018)),
                    lineWidth: max(0.3, f.radius * (major ? 0.0012 : 0.00065))
                )
            }
        }
    }

    // MARK: Fine Filaments

    func drawFineFilaments(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        let count = Int(JARVISMath.clamp(f.size / 11, 34, 120))
        for i in 0..<count {
            let seed = CGFloat(i) * 2.17
            let points = 14
            var path = Path()

            for j in 0..<points {
                let u = CGFloat(j) / CGFloat(points - 1)
                let a = seed + CGFloat(f.time) * (0.06 + CGFloat(i % 8) * 0.008) + u * 1.25
                let radius = 0.08 + u * 0.78
                let depth = 0.55 * sin(a * 1.8 + seed)
                let p = JPoint3(
                    x: cos(a) * radius,
                    y: sin(a) * radius * 0.50,
                    z: depth
                )
                let q = JARVISMath.project(p, radius: f.radius, center: f.center).point
                if j == 0 { path.move(to: q) }
                else { path.addLine(to: q) }
            }

            let packet = dataPulse(index: i * 23 + 1000, time: f.time, speed: 1.7)
            c.stroke(
                path,
                with: .color(f.color.opacity(0.012 + f.activity * 0.045 + packet * 0.035)),
                lineWidth: max(0.3, f.radius * 0.00075)
            )
        }
    }

    // MARK: Nodes

    func drawDataNodes(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        let count = Int(JARVISMath.clamp(f.size / 17, 26, 72))
        for i in 0..<count {
            let seed = CGFloat(i)
            let angle = seed * 2.399 + CGFloat(f.time) * (0.018 + CGFloat(i % 5) * 0.005)
            let radius = 0.18 + JARVISMath.hash(i * 73) * 0.68
            let point = JPoint3(
                x: cos(angle) * radius,
                y: sin(angle) * radius * 0.62,
                z: JARVISMath.hash(i * 19) * 1.6 - 0.8
            )
            let projected = JARVISMath.project(point, radius: f.radius, center: f.center)
            let pulse = dataPulse(index: i * 47, time: f.time, speed: 1.1)
            let r = max(0.45, f.radius * (0.0017 + pulse * 0.0025))
            drawSoftDot(
                c: &c,
                point: projected.point,
                radius: r,
                color: pulse > 0.88 ? JARVISPalette.gold : f.color,
                opacity: 0.025 + pulse * 0.15 + f.activity * 0.03
            )
        }
    }

    // MARK: Central Heart

    func drawCentralHeart(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        let pulse = 1
            + CGFloat(sin(f.time * 1.65)) * 0.025
            + f.level * 0.055
            + f.bass * 0.025
        let r = f.radius * 0.125 * pulse

        for layer in stride(from: 9, through: 1, by: -1) {
            let q = CGFloat(layer) / 9
            let rr = r * (0.45 + q * 1.9)
            let g = Gradient(colors: [
                JARVISPalette.gold.opacity(0.008 + 0.020 * q + f.level * 0.006),
                f.color.opacity(0.010 + 0.015 * q),
                .clear
            ])
            c.drawRadialGradient(g, center: f.center, startRadius: 0, endRadius: rr)
        }

        // Central heart: deliberately geometric, small and extremely bright.
        let sides = 12
        for layer in 0..<5 {
            let q = CGFloat(layer) / 4
            let rr = r * (0.54 + q * 0.44)
            let rotation = CGFloat(f.time) * (layer.isMultiple(of: 2) ? 0.12 : -0.16)
            drawPolygon(
                c: &c,
                center: f.center,
                radius: rr,
                yScale: 0.55 + q * 0.18,
                sides: sides,
                rotation: rotation,
                color: layer == 0 ? JARVISPalette.hot : f.color.opacity(0.14 + f.level * 0.16),
                width: max(0.5, f.radius * (0.0015 + (1 - q) * 0.001))
            )
        }

        drawSoftDot(
            c: &c,
            point: f.center,
            radius: max(1.2, r * 0.17),
            color: JARVISPalette.hot,
            opacity: 0.95
        )
    }

    func drawHeartRays(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        let count = 48
        let inner = f.radius * 0.055
        for i in 0..<count {
            let a = CGFloat(i) / CGFloat(count) * JARVISMath.tau + CGFloat(f.time) * 0.05
            let spectral = 0.35 + 0.65 * abs(sin(Double(i) * 0.91 + f.time * 1.8))
            let energy = f.level * spectral
            let outer = inner + f.radius * (0.015 + energy * 0.07)

            let p0 = CGPoint(
                x: f.center.x + cos(a) * inner,
                y: f.center.y + sin(a) * inner * 0.55
            )
            let p1 = CGPoint(
                x: f.center.x + cos(a) * outer,
                y: f.center.y + sin(a) * outer * 0.55
            )

            c.stroke(
                Path { path in
                    path.move(to: p0)
                    path.addLine(to: p1)
                },
                with: .color(f.color.opacity(0.10 + energy * 0.25)),
                lineWidth: max(0.45, f.radius * 0.001)
            )
        }
    }

}
