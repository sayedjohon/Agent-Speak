import SwiftUI
import CoreGraphics
import Foundation

extension JARVISRenderer {
    // MARK: Foreground

    func drawForegroundRings(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        let rings = [
            (0.33, 0.82, 0.18, 0.10),
            (0.46, 0.35, -0.13, 0.08),
            (0.58, 0.62, 0.09, 0.065)
        ]

        for (index, item) in rings.enumerated() {
            let rotation = JRotation(
                x: item.1,
                y: CGFloat(f.time) * item.2,
                z: CGFloat(f.time) * item.3
            )
            drawOrreryRing(
                c: &c,
                f: f,
                radius: f.radius * item.0,
                rotation: rotation,
                yScale: 0.28 + CGFloat(index) * 0.11,
                segments: 52 + index * 10,
                phase: CGFloat(f.time) * item.2,
                strength: 0.19
            )
        }
    }

    // MARK: Glints

    func drawTransientGlints(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        for i in 0..<9 {
            let p = dataPulse(index: i * 97 + 400, time: f.time, speed: 0.55)
            guard p > 0.91 else { continue }

            let a = CGFloat(i) * 2.71 + CGFloat(f.time) * 0.04
            let radius = f.radius * (0.22 + CGFloat(i % 6) * 0.095)
            let point = CGPoint(
                x: f.center.x + cos(a) * radius,
                y: f.center.y + sin(a) * radius * 0.58
            )
            drawSoftDot(
                c: &c,
                point: point,
                radius: max(0.9, f.radius * 0.006),
                color: JARVISPalette.hot,
                opacity: (p - 0.91) * 9
            )
        }
    }

    func drawScanPlane(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        let travel = CGFloat(f.time.truncatingRemainder(dividingBy: 6.0)) / 6.0
        let y = f.center.y + (travel - 0.5) * f.radius * 1.55
        var path = Path()
        path.move(to: CGPoint(x: f.center.x - f.radius * 0.82, y: y))
        path.addLine(to: CGPoint(x: f.center.x + f.radius * 0.82, y: y))
        c.stroke(path, with: .color(JARVISPalette.gold.opacity(0.010)), lineWidth: max(0.35, f.radius * 0.001))
    }


    // MARK: Advanced Data Ribbon

    func drawDataRibbon(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        // A narrow stream wraps around the spherical data volume like magnetic
        // tape. It is deliberately irregular and only intermittently visible.
        for ribbon in 0..<6 {
            let seed = CGFloat(ribbon) * 1.37
            let direction: CGFloat = ribbon.isMultiple(of: 2) ? 1 : -1
            var path = Path()

            for step in 0...34 {
                let u = CGFloat(step) / 34
                let a = seed
                    + CGFloat(f.time) * (0.11 + CGFloat(ribbon) * 0.013) * direction
                    + u * (2.0 + CGFloat(ribbon) * 0.17)

                let radius = 0.25 + 0.48 * u
                let vertical = CGFloat(0.43 + 0.10 * Darwin.sin(Double(ribbon) * 1.7))
                let depth = CGFloat(0.44 * Darwin.sin(Double(a) * 1.8 + seed))

                let p = JPoint3(
                    x: CGFloat(Darwin.cos(Double(a))) * radius,
                    y: CGFloat(Darwin.sin(Double(a))) * radius * vertical,
                    z: depth
                )
                let q = JARVISMath.project(p, radius: f.radius, center: f.center).point

                if step == 0 { path.move(to: q) }
                else { path.addLine(to: q) }
            }

            let packet = dataPulse(index: ribbon * 331, time: f.time, speed: 1.35)
            drawGlowPath(
                c: &c,
                path: path,
                color: ribbon.isMultiple(of: 3) ? JARVISPalette.gold : f.color,
                opacity: 0.010 + f.activity * 0.035 + packet * 0.035,
                width: max(0.3, f.radius * 0.0007)
            )
        }
    }

    // MARK: Axis / Degree Markers

    func drawAxisMarkers(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        let rings = [0.29, 0.43, 0.57, 0.71]
        for ring in 0..<rings.count {
            let radius = f.radius * rings[ring]
            let count = 36 + ring * 12
            let phase = CGFloat(f.time) * (ring.isMultiple(of: 2) ? 0.015 : -0.019)

            for i in 0..<count {
                let major = i % 9 == 0
                let a = CGFloat(i) / CGFloat(count) * JARVISMath.tau + phase
                let radial = major ? radius * 0.026 : radius * 0.010

                let x0 = f.center.x + cos(a) * radius
                let y0 = f.center.y + sin(a) * radius * 0.62
                let x1 = f.center.x + cos(a) * (radius + radial)
                let y1 = f.center.y + sin(a) * (radius + radial) * 0.62

                c.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x0, y: y0))
                        path.addLine(to: CGPoint(x: x1, y: y1))
                    },
                    with: .color((major ? JARVISPalette.gold : f.color).opacity(
                        major ? 0.065 + f.activity * 0.03 : 0.014
                    )),
                    lineWidth: max(0.3, f.radius * (major ? 0.0011 : 0.0006))
                )
            }
        }
    }

    // MARK: Dialogue-Driven Ring Deformation

    func drawRingDeformation(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        guard f.speaking else { return }

        for ring in 0..<8 {
            let q = CGFloat(ring) / 7
            let base = f.radius * (0.25 + q * 0.55)
            let samples = 72

            var path = Path()
            for i in 0...samples {
                let u = CGFloat(i) / CGFloat(samples)
                let a = u * JARVISMath.tau + CGFloat(f.time) * (0.03 + q * 0.02)

                let waveform =
                    sin(Double(i) * (0.38 + Double(ring) * 0.07) + f.time * 12.0)
                    * Double(f.level)
                let secondary =
                    sin(Double(i) * 0.91 - f.time * 8.0)
                    * Double(f.level) * 0.35

                let radius = base + f.radius * CGFloat(waveform + secondary) * 0.020
                let yScale = 0.34 + q * 0.34

                let p = CGPoint(
                    x: f.center.x + cos(a) * radius,
                    y: f.center.y + sin(a) * radius * yScale
                )

                if i == 0 { path.move(to: p) }
                else { path.addLine(to: p) }
            }

            c.stroke(
                path,
                with: .color(f.color.opacity(0.018 + f.level * 0.055)),
                lineWidth: max(0.35, f.radius * 0.00085)
            )
        }
    }

    // MARK: Central Cage

    func drawCoreCage(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        let radius = f.radius * 0.175

        for axis in 0..<4 {
            let phase = CGFloat(f.time) * (axis.isMultiple(of: 2) ? 0.09 : -0.12)
            let rotation = CGFloat(axis) * .pi * 0.25 + phase

            var path = Path()
            for i in 0...32 {
                let u = CGFloat(i) / 32
                let a = u * JARVISMath.tau + rotation
                let rr = radius * CGFloat(0.74 + 0.18 * Darwin.sin(Double(i * 3 + axis) + f.time * 2.0))
                let p = CGPoint(
                    x: f.center.x + CGFloat(Darwin.cos(Double(a))) * rr,
                    y: f.center.y + CGFloat(Darwin.sin(Double(a))) * rr * 0.45
                )
                if i == 0 { path.move(to: p) }
                else { path.addLine(to: p) }
            }

            c.stroke(
                path,
                with: .color(JARVISPalette.gold.opacity(0.025 + f.level * 0.08)),
                lineWidth: max(0.4, f.radius * 0.001)
            )
        }

        for i in 0..<12 {
            let a = CGFloat(i) / 12 * JARVISMath.tau + CGFloat(f.time) * 0.18
            let p = CGPoint(
                x: f.center.x + cos(a) * radius * 0.95,
                y: f.center.y + sin(a) * radius * 0.43
            )
            drawSoftDot(
                c: &c,
                point: p,
                radius: max(0.45, f.radius * 0.0024),
                color: JARVISPalette.hot,
                opacity: 0.025 + f.level * 0.08
            )
        }
    }

    // MARK: Particle Trails

    func drawParticleTrails(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        let count = Int(JARVISMath.clamp(f.size / 18, 20, 58))

        for i in 0..<count {
            let packet = dataPulse(index: i * 131 + 5000, time: f.time, speed: 0.72)
            guard packet > 0.56 else { continue }

            let a = CGFloat(i) * 2.17 + CGFloat(f.time) * 0.12
            let radius = f.radius * (0.18 + CGFloat(i % 7) * 0.085)
            let trail = f.radius * (0.018 + packet * 0.035)

            let p1 = CGPoint(
                x: f.center.x + cos(a) * radius,
                y: f.center.y + sin(a) * radius * 0.57
            )
            let p2 = CGPoint(
                x: f.center.x + cos(a - 0.13) * (radius - trail),
                y: f.center.y + sin(a - 0.13) * (radius - trail) * 0.57
            )

            drawGlowSegment(
                c: &c,
                from: p2,
                to: p1,
                color: JARVISPalette.gold,
                opacity: packet * 0.23,
                width: max(0.45, f.radius * 0.001),
                glow: packet > 0.78
            )
        }
    }

    // MARK: Depth Flares

    func drawDepthFlares(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        for i in 0..<7 {
            let depth = CGFloat(i) / 6
            let a = CGFloat(i) * 2.91 + CGFloat(f.time) * 0.027
            let radius = f.radius * (0.31 + depth * 0.47)

            let p = JPoint3(
                x: cos(a) * radius / f.radius,
                y: sin(a) * radius / f.radius * 0.58,
                z: depth * 1.4 - 0.7
            )

            let q = JARVISMath.project(p, radius: f.radius, center: f.center)
            let size = max(0.7, f.radius * (0.003 + depth * 0.003))

            drawSoftDot(
                c: &c,
                point: q.point,
                radius: size,
                color: depth > 0.55 ? JARVISPalette.gold : f.color,
                opacity: 0.015 + depth * 0.045
            )
        }
    }



    // MARK: Hard-Drive / Reel Data

    func drawHardDrivePlatterData(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        for platter in 0..<5 {
            let q = CGFloat(platter) / 4
            let radius = f.radius * (0.35 + q * 0.43)
            let direction: CGFloat = platter.isMultiple(of: 2) ? 1 : -1
            let phase = CGFloat(f.time) * (0.035 + q * 0.018) * direction

            for block in 0..<48 {
                if (block + platter * 3) % 5 != 0 { continue }

                let a0 = CGFloat(block) / 48 * JARVISMath.tau + phase
                let a1 = a0 + (0.018 + q * 0.012)

                let p0 = CGPoint(
                    x: f.center.x + cos(a0) * radius,
                    y: f.center.y + sin(a0) * radius * (0.28 + q * 0.14)
                )
                let p1 = CGPoint(
                    x: f.center.x + cos(a1) * radius,
                    y: f.center.y + sin(a1) * radius * (0.28 + q * 0.14)
                )

                let packet = dataPulse(index: block + platter * 71 + 8000, time: f.time, speed: 1.8)
                drawGlowSegment(
                    c: &c,
                    from: p0,
                    to: p1,
                    color: packet > 0.86 ? JARVISPalette.gold : f.color,
                    opacity: 0.018 + packet * 0.13 + f.talkEnergy * 0.025,
                    width: max(0.35, f.radius * 0.001),
                    glow: packet > 0.90
                )
            }
        }
    }

    // MARK: Meridian Bands

    func drawMeridianBands(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        for band in 0..<7 {
            let q = CGFloat(band) / 6
            let rotation = CGFloat(f.time) * (band.isMultiple(of: 2) ? 0.017 : -0.023) + q * 1.2
            let radius = f.radius * (0.28 + q * 0.56)

            drawEllipse(
                c: &c,
                center: f.center,
                radius: radius,
                yScale: 0.14 + q * 0.08,
                rotation: rotation,
                color: f.color.opacity(0.010 + f.activity * 0.016),
                width: max(0.3, f.radius * 0.00065)
            )
        }
    }

    // MARK: Peripheral Packets

    func drawPeripheralPackets(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        for i in 0..<22 {
            let packet = dataPulse(index: i * 173 + 9100, time: f.time, speed: 0.82)
            guard packet > 0.63 else { continue }

            let angle = CGFloat(i) * 1.97 + CGFloat(f.time) * 0.055
            let radius = f.radius * (0.62 + CGFloat(i % 5) * 0.055)
            let p = CGPoint(
                x: f.center.x + cos(angle) * radius,
                y: f.center.y + sin(angle) * radius * 0.57
            )

            drawSoftDot(
                c: &c,
                point: p,
                radius: max(0.45, f.radius * (0.0015 + packet * 0.002)),
                color: packet > 0.86 ? JARVISPalette.hot : JARVISPalette.gold,
                opacity: packet * 0.18
            )
        }
    }

    // MARK: Micro Data Clusters

    func drawMicroDataClusters(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        let clusterCount = Int(JARVISMath.clamp(f.size / 36, 8, 22))

        for cluster in 0..<clusterCount {
            let a = CGFloat(cluster) * 2.77 + CGFloat(f.time) * 0.013
            let radius = f.radius * (0.24 + JARVISMath.hash(cluster * 47) * 0.58)
            let center = CGPoint(
                x: f.center.x + cos(a) * radius,
                y: f.center.y + sin(a) * radius * 0.60
            )

            for member in 0..<6 {
                let local = CGFloat(member)
                let offset = f.radius * 0.006 * (local - 2.5)
                let y = center.y + offset
                let width = f.radius * (0.008 + JARVISMath.hash(cluster * 19 + member) * 0.018)

                var path = Path()
                path.move(to: CGPoint(x: center.x - width, y: y))
                path.addLine(to: CGPoint(x: center.x + width, y: y))

                let packet = dataPulse(index: cluster * 19 + member + 9500, time: f.time, speed: 1.0)
                c.stroke(
                    path,
                    with: .color((packet > 0.88 ? JARVISPalette.gold : f.color).opacity(
                        0.008 + packet * 0.055
                    )),
                    lineWidth: max(0.3, f.radius * 0.00065)
                )
            }
        }
    }

    // MARK: Audio Halo

    func drawAudioHalo(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        guard f.speaking || f.music else { return }

        for layer in 0..<4 {
            let q = CGFloat(layer) / 3
            let radius = f.radius * (0.18 + q * 0.17 + f.talkEnergy * 0.018)
            let alpha = (0.014 + f.talkEnergy * 0.035) * (1 - q * 0.45)

            drawEllipse(
                c: &c,
                center: f.center,
                radius: radius,
                yScale: 0.67,
                rotation: CGFloat(f.time) * (0.05 + q * 0.02),
                color: JARVISPalette.gold.opacity(alpha),
                width: max(0.4, f.radius * 0.001)
            )
        }
    }

    // MARK: Calibration Arcs

    func drawCalibrationArcs(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        for arc in 0..<6 {
            let radius = f.radius * (0.48 + CGFloat(arc % 3) * 0.12)
            let phase = CGFloat(f.time) * (arc.isMultiple(of: 2) ? 0.014 : -0.019) + CGFloat(arc)
            let span = CGFloat.pi * (0.14 + CGFloat(arc % 3) * 0.05)

            var path = Path()
            for i in 0...18 {
                let a = phase - span * 0.5 + span * CGFloat(i) / 18
                let p = CGPoint(
                    x: f.center.x + cos(a) * radius,
                    y: f.center.y + sin(a) * radius * 0.60
                )
                if i == 0 { path.move(to: p) }
                else { path.addLine(to: p) }
            }

            c.stroke(
                path,
                with: .color(JARVISPalette.gold.opacity(0.025 + f.activity * 0.025)),
                lineWidth: max(0.35, f.radius * 0.00075)
            )
        }
    }



    // MARK: Final Optical Pass

    func drawOpticalEdgePass(_ c: inout GraphicsContext, _ f: JARVISFrame) {
        let count = 12
        for i in 0..<count {
            let q = CGFloat(i) / CGFloat(count)
            let a = CGFloat(i) * 2.41 + CGFloat(f.time) * 0.021
            let radius = f.radius * (0.40 + q * 0.47)
            let p0 = CGPoint(
                x: f.center.x + cos(a) * radius,
                y: f.center.y + sin(a) * radius * 0.57
            )
            let p1 = CGPoint(
                x: f.center.x + cos(a + 0.055) * (radius + f.radius * 0.018),
                y: f.center.y + sin(a + 0.055) * (radius + f.radius * 0.018) * 0.57
            )
            let packet = dataPulse(index: i * 311 + 10000, time: f.time, speed: 0.7)
            drawGlowSegment(
                c: &c,
                from: p0,
                to: p1,
                color: JARVISPalette.hot,
                opacity: packet * 0.14 + f.talkEnergy * 0.018,
                width: max(0.35, f.radius * 0.0008),
                glow: packet > 0.9
            )
        }
    }


    // MARK: Primitives

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
            let a = CGFloat(i) / 96 * JARVISMath.tau
            let x0 = cos(a) * radius
            let y0 = sin(a) * radius * yScale
            let x = center.x + x0 * cos(rotation) - y0 * sin(rotation)
            let y = center.y + x0 * sin(rotation) + y0 * cos(rotation)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        c.stroke(path, with: .color(color), lineWidth: width)
    }

    func drawPolygon(
        c: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        yScale: CGFloat,
        sides: Int,
        rotation: CGFloat,
        color: Color,
        width: CGFloat
    ) {
        var path = Path()
        for i in 0...sides {
            let a = CGFloat(i) / CGFloat(sides) * JARVISMath.tau + rotation
            let p = CGPoint(
                x: center.x + cos(a) * radius,
                y: center.y + sin(a) * radius * yScale
            )
            if i == 0 { path.move(to: p) }
            else { path.addLine(to: p) }
        }
        c.stroke(path, with: .color(color), lineWidth: width)
    }

    func drawMicroBracket(
        c: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        angle: CGFloat,
        color: Color,
        width: CGFloat
    ) {
        let a0 = angle - 0.34
        let a1 = angle + 0.34
        var path = Path()
        path.move(to: CGPoint(
            x: center.x + cos(a0) * radius,
            y: center.y + sin(a0) * radius * 0.7
        ))
        path.addLine(to: CGPoint(
            x: center.x + cos(angle) * radius * 1.16,
            y: center.y + sin(angle) * radius * 0.7 * 1.16
        ))
        path.addLine(to: CGPoint(
            x: center.x + cos(a1) * radius,
            y: center.y + sin(a1) * radius * 0.7
        ))
        c.stroke(path, with: .color(color), lineWidth: width)
    }

    
    func drawGlowPath(c: inout GraphicsContext, path: Path, color: Color, opacity: CGFloat, width: CGFloat, glow: Bool = true) {
        if glow {
            c.stroke(path, with: .color(color.opacity(opacity * 0.13)), lineWidth: width * 5.0)
            c.stroke(path, with: .color(color.opacity(opacity * 0.25)), lineWidth: width * 2.2)
        }
        c.stroke(path, with: .color(color.opacity(opacity)), lineWidth: width)
    }

    func drawGlowSegment(
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
                with: .color(color.opacity(opacity * 0.13)),
                lineWidth: width * 5.0
            )
            c.stroke(
                Path { path in
                    path.move(to: p0)
                    path.addLine(to: p1)
                },
                with: .color(color.opacity(opacity * 0.25)),
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

    func drawSoftDot(
        c: inout GraphicsContext,
        point: CGPoint,
        radius: CGFloat,
        color: Color,
        opacity: CGFloat
    ) {
        let gradient = Gradient(colors: [
            color.opacity(opacity),
            color.opacity(opacity * 0.18),
            .clear
        ])
        c.drawRadialGradient(
            gradient,
            center: point,
            startRadius: 0,
            endRadius: radius * 4.5
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

    func dataPulse(index: Int, time: Double, speed: Double) -> CGFloat {
        let phase = JARVISMath.hash(index * 17) * JARVISMath.tau
        let x = 0.5 + 0.5 * sin(time * speed + Double(phase))
        return CGFloat(pow(Double(x), 7.0))
    }
}

// MARK: - Safe Collection Access


