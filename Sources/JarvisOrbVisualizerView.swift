import SwiftUI
import AVFoundation

/// Shared, smoothed audio-energy signal for the dashboard and compact notch visualizer.
public final class JarvisAudioLevelMeter: ObservableObject {
    public static let shared = JarvisAudioLevelMeter()

    @Published public private(set) var level: CGFloat = 0
    @Published public private(set) var bass: CGFloat = 0

    private weak var player: AVAudioPlayer?
    private var timer: Timer?
    private var smoothedLevel: CGFloat = 0
    private var smoothedBass: CGFloat = 0

    private init() {
        startTimerIfNeeded()
    }

    public func beginMonitoring(_ player: AVAudioPlayer?) {
        self.player = player
        player?.isMeteringEnabled = true
        startTimerIfNeeded()
    }

    public func endMonitoring() {
        player = nil
        withAnimation(.easeOut(duration: 0.28)) {
            level = 0
            bass = 0
        }
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.sample()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func sample() {
        if let player, player.isPlaying {
            player.updateMeters()
            let average = CGFloat(player.averagePower(forChannel: 0))
            let peak = CGFloat(player.peakPower(forChannel: 0))
            let averageNormalized = max(0, min(1, (average + 52) / 52))
            let peakNormalized = max(0, min(1, (peak + 48) / 48))
            let target = max(averageNormalized * 0.72, peakNormalized * 0.50)

            smoothedLevel += (target - smoothedLevel) * (target > smoothedLevel ? 0.42 : 0.12)
            smoothedBass += ((peakNormalized - smoothedBass) * 0.18)
            level = smoothedLevel
            bass = smoothedBass
        } else {
            let queueLevel = CGFloat(AudioLevelMeter.shared.level)
            if queueLevel > 0.01 {
                smoothedLevel += (queueLevel - smoothedLevel) * 0.35
                smoothedBass += (queueLevel * 0.85 - smoothedBass) * 0.20
            } else {
                smoothedLevel *= 0.82
                smoothedBass *= 0.86
            }
            level = smoothedLevel
            bass = smoothedBass
        }
    }
}

/// A scalable, native SwiftUI Jarvis-style holographic reactor driven by `JarvisAudioLevelMeter.shared`.
public struct JarvisOrbVisualizerView: View {
    @ObservedObject private var meter = JarvisAudioLevelMeter.shared
    @ObservedObject private var hologram = HologramManager.shared

    public var isSpeaking: Bool
    public var isPlayingMusic: Bool
    public var size: CGFloat
    public var theme: HologramTheme?

    public init(isSpeaking: Bool = false, isPlayingMusic: Bool = false, size: CGFloat = 68, theme: HologramTheme? = nil) {
        self.isSpeaking = isSpeaking
        self.isPlayingMusic = isPlayingMusic
        self.size = size
        self.theme = theme
    }

    private var activeTheme: HologramTheme {
        theme ?? hologram.currentTheme
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 120.0, paused: false)) { timeline in
            Canvas { context, canvasSize in
                draw(in: &context, canvasSize: canvasSize, time: timeline.date.timeIntervalSinceReferenceDate)
            }
            .drawingGroup(opaque: false, colorMode: .extendedLinear)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(isSpeaking ? "Jarvis hologram speaking" : "Jarvis hologram ready")
    }

    private func draw(in context: inout GraphicsContext, canvasSize: CGSize, time: TimeInterval) {
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let baseEnergy = meter.level
        let musicEnergy = isPlayingMusic ? max(0.16, CGFloat(meter.bass) * 0.32) : 0.0
        let energy = max(baseEnergy, isSpeaking ? 0.18 : musicEnergy)
        let bass = isPlayingMusic ? max(meter.bass, 0.18) : 0
        let radius = min(canvasSize.width, canvasSize.height) * 0.31
        let scale = max(0.42, radius / 68.0)
        let breathing = 0.5 + 0.5 * sin(time * (isSpeaking ? 4.8 : (isPlayingMusic ? 2.4 : 1.35)))
        let hologramCenter = CGPoint(
            x: center.x + radius * (0.035 + energy * 0.018),
            y: center.y - radius * 0.018
        )

        context.blendMode = .plusLighter
        drawGlassVolume(&context, center: hologramCenter, radius: radius, energy: energy, time: time)
        drawLeftHologramLayer(&context, center: hologramCenter, radius: radius, energy: energy, time: time, scale: scale)
        drawBrokenReactorRings(&context, center: hologramCenter, radius: radius, energy: energy, bass: bass, time: time, scale: scale)
        drawCircuitFragments(&context, center: hologramCenter, radius: radius, energy: energy, time: time, scale: scale)
        drawFragmentedShell(&context, center: hologramCenter, radius: radius, energy: energy, time: time, scale: scale)
        drawVoiceEqualizerBursts(&context, center: hologramCenter, radius: radius, energy: energy, bass: bass, time: time, scale: scale)
        drawRadialDataBursts(&context, center: hologramCenter, radius: radius, energy: energy, time: time, scale: scale)
        drawPlasmaParticles(&context, center: hologramCenter, radius: radius, energy: energy, time: time, scale: scale)
        drawCoreKnot(&context, center: hologramCenter, radius: radius, energy: energy, breathing: breathing, time: time, scale: scale)
    }

    private func drawGlassVolume(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat, energy: CGFloat, time: TimeInterval) {
        let sphere = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        let warmGlow = Path(ellipseIn: sphere.insetBy(dx: -radius * 0.08, dy: -radius * 0.08))

        // Outer soft warm amber bloom
        var blurred = context
        blurred.addFilter(.blur(radius: radius * (0.20 + energy * 0.10)))
        blurred.fill(warmGlow, with: .radialGradient(
            Gradient(colors: [
                activeTheme.amber.opacity(0.30 + energy * 0.20),
                activeTheme.deepAmber.opacity(0.14 + energy * 0.10),
                .clear
            ]),
            center: center,
            startRadius: radius * 0.06,
            endRadius: radius * 1.15
        ))

        context.fill(Path(ellipseIn: sphere), with: .radialGradient(
            Gradient(colors: [
                activeTheme.amber.opacity(0.06 + energy * 0.04),
                activeTheme.deepAmber.opacity(0.04),
                .clear
            ]),
            center: center,
            startRadius: radius * 0.10,
            endRadius: radius
        ))

        let lensOffset = radius * 0.14 * sin(time * 0.55)
        let lens = CGRect(
            x: center.x - radius * 0.83 + lensOffset,
            y: center.y - radius * 0.92,
            width: radius * 1.46,
            height: radius * 1.84
        )
        context.stroke(Path(ellipseIn: lens), with: .color(activeTheme.lensAmber.opacity(0.14 + energy * 0.08)), lineWidth: max(0.45, radius * 0.006))
    }

    private func drawBrokenReactorRings(
        _ context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        energy: CGFloat,
        bass: CGFloat,
        time: TimeInterval,
        scale: CGFloat
    ) {
        let rings: [(CGFloat, Int, CGFloat, CGFloat, Double)] = [
            (0.24, 7, 0.24, 0.014, 1.55),
            (0.37, 11, 0.18, 0.009, -0.95),
            (0.50, 15, 0.13, 0.007, 0.64),
            (0.64, 19, 0.10, 0.005, -0.43),
            (0.78, 24, 0.08, 0.004, 0.31),
            (0.94, 30, 0.055, 0.0035, -0.18)
        ]

        for (ringIndex, ringInfo) in rings.enumerated() {
            let ringRadius = radius * (ringInfo.0 + bass * 0.035 + energy * 0.018)
            let count = ringInfo.1
            let rotation = time * ringInfo.4 * (1.0 + Double(energy) * 1.8)
            let width = max(0.42, radius * ringInfo.3)

            for segmentIndex in 0..<count {
                let missing = random(segmentIndex, ringIndex, 19)
                guard missing > (ringIndex < 2 ? 0.12 : 0.44) else { continue }

                let base = CGFloat(segmentIndex) / CGFloat(count) * .pi * 2
                let jitter = (random(segmentIndex, ringIndex, 2) - 0.5) * 0.11
                let start = base + CGFloat(rotation) + jitter
                let sweep = (.pi * ringInfo.2) * (0.42 + random(segmentIndex, ringIndex, 5) * 0.82)
                let flicker = 0.55 + 0.45 * sin(CGFloat(time) * (1.6 + random(segmentIndex, 4, ringIndex) * 5.7) + base * 4)
                let alpha = (0.13 + flicker * 0.25 + energy * 0.28) * (ringIndex == 0 ? 1.20 : 1.0)
                let color = segmentIndex % 13 == 0 ? activeTheme.hotWhite.opacity(alpha * 0.72) : activeTheme.amber.opacity(alpha)

                let squash = 0.72 + random(segmentIndex, ringIndex, 41) * 0.22
                let offset = CGPoint(
                    x: center.x - radius * (0.06 + random(segmentIndex, ringIndex, 43) * 0.10),
                    y: center.y + radius * (random(segmentIndex, ringIndex, 47) - 0.5) * 0.075
                )
                let path = ellipticalArcPath(
                    center: offset,
                    radiusX: ringRadius + radius * 0.010 * sin(base * 7 + CGFloat(time)),
                    radiusY: ringRadius * squash,
                    start: start,
                    sweep: sweep,
                    wobble: radius * (0.003 + energy * 0.018),
                    time: time,
                    seed: CGFloat(segmentIndex + ringIndex * 31)
                )

                var glow = context
                glow.addFilter(.blur(radius: max(0.7, scale * 1.25)))
                glow.stroke(path, with: .color(color.opacity(0.72)), style: StrokeStyle(lineWidth: width * 2.4, lineCap: .round))
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
        }
    }

    private func drawLeftHologramLayer(
        _ context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        energy: CGFloat,
        time: TimeInterval,
        scale: CGFloat
    ) {
        let layerCenter = CGPoint(x: center.x - radius * 0.38, y: center.y - radius * 0.02)
        let leftEnergy = 0.72 + energy * 1.15

        for index in 0..<(size < 42 ? 10 : 28) {
            let start = CGFloat.pi * (0.64 + random(index, 503, 7) * 0.28)
            let sweep = CGFloat.pi * (0.34 + random(index, 509, 2) * 0.62)
            let rx = radius * (0.52 + random(index, 521, 4) * 0.36 + energy * 0.07)
            let ry = radius * (0.42 + random(index, 523, 8) * 0.25)
            let spin = CGFloat(time) * (0.08 + random(index, 541, 2) * 0.18)
            let path = ellipticalArcPath(
                center: layerCenter,
                radiusX: rx,
                radiusY: ry,
                start: start + spin,
                sweep: sweep,
                wobble: radius * (0.012 + energy * 0.032),
                time: time,
                seed: CGFloat(index * 5)
            )
            let alpha = (0.08 + random(index, 547, 4) * 0.23 + energy * 0.30) * leftEnergy
            let lineWidth = max(0.24, scale * (0.25 + random(index, 557, 4) * 0.70))

            if index % 5 == 0 {
                var glow = context
                glow.addFilter(.blur(radius: max(0.7, scale * 1.6)))
                glow.stroke(path, with: .color(activeTheme.amber.opacity(alpha * 0.38)), style: StrokeStyle(lineWidth: lineWidth * 4.2, lineCap: .round, lineJoin: .round))
            }
            context.stroke(path, with: .color(activeTheme.amber.opacity(alpha)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }

        for index in 0..<(size < 42 ? 14 : 54) {
            let angle = CGFloat.pi * (0.73 + random(index, 563, 7) * 0.54)
            let inner = radius * (0.34 + random(index, 569, 3) * 0.32)
            let outer = radius * (0.78 + random(index, 571, 6) * 0.34 + energy * 0.15)
            let ySkew = 0.72 + random(index, 577, 2) * 0.34
            var trace = Path()
            let start = CGPoint(x: layerCenter.x + cos(angle) * inner, y: layerCenter.y + sin(angle) * inner * ySkew)
            let end = CGPoint(x: layerCenter.x + cos(angle) * outer, y: layerCenter.y + sin(angle) * outer * ySkew)
            trace.move(to: start)
            trace.addLine(to: end)

            if index % 3 == 0 {
                let hook = CGPoint(
                    x: end.x + cos(angle + .pi / 2) * radius * (0.025 + random(index, 581, 2) * 0.075),
                    y: end.y + sin(angle + .pi / 2) * radius * (0.025 + random(index, 587, 2) * 0.075)
                )
                trace.addLine(to: hook)
            }

            let flicker = 0.35 + 0.65 * max(0, sin(CGFloat(time) * (2.5 + random(index, 593, 5) * 7.0) + angle))
            let alpha = 0.12 + flicker * 0.35 + energy * 0.40
            context.stroke(trace, with: .color(activeTheme.hotWhite.opacity(alpha * 0.54)), style: StrokeStyle(lineWidth: max(0.22, scale * 0.46), lineCap: .round, lineJoin: .round))
        }
    }

    private func drawCircuitFragments(
        _ context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        energy: CGFloat,
        time: TimeInterval,
        scale: CGFloat
    ) {
        let fragmentCount = size < 42 ? 88 : 285

        for index in 0..<fragmentCount {
            let angle = random(index, 1, 3) * .pi * 2 + CGFloat(time * 0.09) * (random(index, 8, 4) > 0.5 ? 1 : -1)
            let radialBias = pow(random(index, 5, 9), 0.46)
            let fragmentRadius = radius * (0.18 + radialBias * 0.82)
            let depth = 0.36 + random(index, 7, 2) * 1.05
            let localEnergy = 0.72 + energy * 0.75
            let x = center.x + cos(angle) * fragmentRadius * depth
            let y = center.y + sin(angle) * fragmentRadius * (0.72 + random(index, 13, 2) * 0.36)

            let tangent = angle + .pi / 2
            let radial = angle
            let lengthA = radius * (0.010 + random(index, 2, 1) * 0.092) * localEnergy
            let lengthB = radius * (0.008 + random(index, 3, 8) * 0.066) * localEnergy
            let bend = random(index, 11, 7) > 0.54 ? tangent : radial
            let second = random(index, 17, 7) > 0.56 ? radial : tangent
            let phase = CGFloat(time) * (1.2 + random(index, 31, 4) * 4.3) + angle * 2
            let flicker = 0.42 + 0.58 * max(0, sin(phase))
            let alpha = (0.08 + flicker * 0.33 + energy * 0.25) * (1.0 - radialBias * 0.16)

            var trace = Path()
            trace.move(to: CGPoint(x: x, y: y))
            let p1 = CGPoint(x: x + cos(bend) * lengthA, y: y + sin(bend) * lengthA)
            let p2 = CGPoint(x: p1.x + cos(second) * lengthB, y: p1.y + sin(second) * lengthB)
            trace.addLine(to: p1)
            trace.addLine(to: p2)

            if index % 5 == 0 {
                let branch = CGPoint(
                    x: p1.x + cos(second + .pi / 2) * lengthB * 0.55,
                    y: p1.y + sin(second + .pi / 2) * lengthB * 0.55
                )
                trace.move(to: p1)
                trace.addLine(to: branch)
            }

            let lineWidth = max(0.22, scale * (0.24 + random(index, 29, 2) * 0.46))
            let color = index % 11 == 0 ? activeTheme.hotWhite.opacity(alpha * 0.78) : activeTheme.amber.opacity(alpha)
            context.stroke(trace, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }

    private func drawFragmentedShell(
        _ context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        energy: CGFloat,
        time: TimeInterval,
        scale: CGFloat
    ) {
        let shellCount = size < 42 ? 34 : 132

        for index in 0..<shellCount {
            let seed = random(index, 401, 17)
            let baseAngle = seed * .pi * 2
            let slowDrift = CGFloat(time) * (0.035 + random(index, 409, 11) * 0.15)
            let angle = baseAngle + slowDrift
            let shellRadius = radius * (0.66 + random(index, 419, 5) * 0.46 + energy * 0.035)
            let side = random(index, 421, 8) > 0.5 ? CGFloat(1) : CGFloat(-1)
            let steps = 2 + Int(random(index, 431, 3) * 5)

            var path = Path()
            var cursor = CGPoint(
                x: center.x + cos(angle) * shellRadius,
                y: center.y + sin(angle) * shellRadius * (0.74 + random(index, 433, 13) * 0.28)
            )
            path.move(to: cursor)

            for step in 0..<steps {
                let stepAngle = angle + (step % 2 == 0 ? .pi / 2 : 0) * side
                let length = radius * (0.018 + random(index, step + 439, 2) * 0.072)
                cursor = CGPoint(
                    x: cursor.x + cos(stepAngle) * length,
                    y: cursor.y + sin(stepAngle) * length
                )
                path.addLine(to: cursor)
            }

            let phase = CGFloat(time) * (1.1 + random(index, 443, 6) * 5.5) + baseAngle * 2.4
            let flicker = 0.20 + 0.80 * max(0, sin(phase))
            let alpha = 0.10 + flicker * 0.30 + energy * 0.36
            let lineWidth = max(0.22, scale * (0.20 + random(index, 449, 4) * 0.56))

            if index % 9 == 0 {
                var glow = context
                glow.addFilter(.blur(radius: max(0.45, scale * 1.15)))
                glow.stroke(path, with: .color(activeTheme.amber.opacity(alpha * 0.35)), style: StrokeStyle(lineWidth: lineWidth * 3.4, lineCap: .round, lineJoin: .round))
            }
            context.stroke(path, with: .color(activeTheme.amber.opacity(alpha)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }

        for index in 0..<(size < 42 ? 18 : 72) {
            guard random(index, 461, 3) > 0.35 else { continue }
            let angle = random(index, 463, 7) * .pi * 2 + CGFloat(time) * 0.06
            let shellRadius = radius * (0.82 + random(index, 467, 5) * 0.22 + energy * 0.05)
            let sweep = CGFloat.pi * (0.018 + random(index, 479, 2) * 0.055)
            var shard = Path()
            shard.addArc(
                center: center,
                radius: shellRadius,
                startAngle: .radians(Double(angle)),
                endAngle: .radians(Double(angle + sweep)),
                clockwise: false
            )
            context.stroke(shard, with: .color(activeTheme.hotWhite.opacity(0.15 + energy * 0.32)), style: StrokeStyle(lineWidth: max(0.22, scale * 0.42), lineCap: .butt))
        }
    }

    private func drawRadialDataBursts(
        _ context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        energy: CGFloat,
        time: TimeInterval,
        scale: CGFloat
    ) {
        let burstCount = size < 42 ? 24 : 86

        for index in 0..<burstCount {
            let baseAngle = random(index, 101, 5) * .pi * 2
            let spin = CGFloat(time) * (0.12 + random(index, 109, 8) * 0.26)
            let angle = baseAngle + spin
            let inner = radius * (0.35 + random(index, 103, 4) * 0.48)
            let surge = energy * radius * (0.05 + random(index, 107, 1) * 0.12)
            let outer = min(radius * 1.05, inner + radius * (0.05 + random(index, 113, 9) * 0.34) + surge)
            let phase = CGFloat(time) * (2.2 + random(index, 127, 9) * 7.0) + baseAngle
            let flicker = 0.24 + 0.76 * max(0, sin(phase))
            let alpha = 0.09 + flicker * 0.34 + energy * 0.36

            var ray = Path()
            ray.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
            ray.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))

            let width = max(0.28, scale * (0.34 + random(index, 131, 2) * 0.85))
            if index % 6 == 0 {
                var glow = context
                glow.addFilter(.blur(radius: max(0.8, scale * 1.4)))
                glow.stroke(ray, with: .color(activeTheme.amber.opacity(alpha * 0.42)), style: StrokeStyle(lineWidth: width * 3, lineCap: .round))
            }
            context.stroke(ray, with: .color(activeTheme.hotWhite.opacity(alpha * 0.55)), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }
    }

    private func drawVoiceEqualizerBursts(
        _ context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        energy: CGFloat,
        bass: CGFloat,
        time: TimeInterval,
        scale: CGFloat
    ) {
        let bandCount = size < 42 ? 18 : 46
        let activeEnergy = 0.25 + energy * 1.35 + bass * 0.8

        for index in 0..<bandCount {
            let t = CGFloat(index) / CGFloat(max(1, bandCount - 1))
            let angle = CGFloat.pi * (0.82 + t * 0.88) + CGFloat(time) * 0.045
            let beat = 0.35 + 0.65 * max(0, sin(CGFloat(time) * (3.0 + random(index, 601, 3) * 8.0) + t * 9))
            let outer = radius * (0.77 + beat * 0.20 * activeEnergy + random(index, 607, 2) * 0.15)
            let inner = radius * (0.44 + random(index, 613, 4) * 0.20)
            var bar = Path()
            bar.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner * 0.76))
            bar.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer * 0.76))

            let alpha = 0.08 + beat * 0.38 + energy * 0.42
            let width = max(0.25, scale * (0.28 + beat * 1.1))
            context.stroke(bar, with: .color(activeTheme.hotWhite.opacity(alpha * 0.58)), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }

        for index in 0..<(size < 42 ? 8 : 24) {
            let angle = CGFloat.pi * (1.02 + random(index, 617, 5) * 0.52)
            let base = radius * (0.90 + random(index, 619, 7) * 0.18)
            let jitter = radius * energy * (0.02 + random(index, 631, 2) * 0.10)
            var spark = Path()
            spark.move(to: CGPoint(x: center.x + cos(angle) * base, y: center.y + sin(angle) * base * 0.76))
            spark.addLine(to: CGPoint(x: center.x + cos(angle) * (base + jitter + radius * 0.12), y: center.y + sin(angle) * (base + jitter + radius * 0.12) * 0.76))
            context.stroke(spark, with: .color(activeTheme.hotWhite.opacity(0.16 + energy * 0.55)), style: StrokeStyle(lineWidth: max(0.28, scale * 0.55), lineCap: .round))
        }
    }

    private func drawPlasmaParticles(
        _ context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        energy: CGFloat,
        time: TimeInterval,
        scale: CGFloat
    ) {
        let particleCount = size < 42 ? 120 : 430

        for index in 0..<particleCount {
            let seedAngle = random(index, 211, 17) * .pi * 2
            let orbit = CGFloat(time) * (0.05 + random(index, 223, 19) * 0.32)
            let angle = seedAngle + orbit
            let r = radius * pow(random(index, 227, 23), 0.46) * (0.98 + energy * 0.08)
            let ellipse = 0.70 + random(index, 229, 29) * 0.34
            let px = center.x + cos(angle) * r
            let py = center.y + sin(angle) * r * ellipse
            let twinkle = 0.30 + 0.70 * max(0, sin(CGFloat(time) * (1.8 + random(index, 233, 31) * 6.5) + seedAngle * 5))
            let alpha = 0.10 + twinkle * 0.42 + energy * 0.30
            let dotSize = max(0.28, scale * (0.28 + random(index, 239, 37) * 1.45) * (index % 23 == 0 ? 2.0 : 1.0))
            let rect = CGRect(x: px - dotSize / 2, y: py - dotSize / 2, width: dotSize, height: dotSize)

            if index % 19 == 0 {
                var glow = context
                glow.addFilter(.blur(radius: dotSize * 1.7))
                glow.fill(Path(ellipseIn: rect.insetBy(dx: -dotSize * 1.2, dy: -dotSize * 1.2)), with: .color(activeTheme.hotWhite.opacity(alpha * 0.28)))
            }
            context.fill(Path(ellipseIn: rect), with: .color(activeTheme.amber.opacity(alpha)))
        }
    }

    private func drawCoreKnot(
        _ context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        energy: CGFloat,
        breathing: CGFloat,
        time: TimeInterval,
        scale: CGFloat
    ) {
        let coreRadius = radius * (0.060 + energy * 0.030 + breathing * 0.008)
        let coreRect = CGRect(x: center.x - coreRadius, y: center.y - coreRadius, width: coreRadius * 2, height: coreRadius * 2)

        var coreGlow = context
        coreGlow.addFilter(.blur(radius: max(1.2, scale * 2.0)))
        coreGlow.fill(Path(ellipseIn: coreRect.insetBy(dx: -coreRadius * 0.35, dy: -coreRadius * 0.35)), with: .radialGradient(
            Gradient(colors: [
                activeTheme.glint.opacity(0.40 + energy * 0.22),
                activeTheme.amber.opacity(0.30),
                .clear
            ]),
            center: center,
            startRadius: 0,
            endRadius: coreRadius * 1.5
        ))

        context.fill(Path(ellipseIn: coreRect), with: .radialGradient(
            Gradient(colors: [
                activeTheme.glint.opacity(0.65 + energy * 0.15),
                activeTheme.amber.opacity(0.40),
                .clear
            ]),
            center: center,
            startRadius: 0,
            endRadius: coreRadius
        ))

        let filaments = size < 42 ? 5 : 9
        for index in 0..<filaments {
            var filament = Path()
            let phase = CGFloat(time) * (0.9 + CGFloat(index) * 0.18) + random(index, 307, 2) * .pi * 2
            let turns = 44

            for step in 0...turns {
                let t = CGFloat(step) / CGFloat(turns)
                let angle = phase + t * .pi * 2.15 + sin(t * .pi * 4 + phase) * 0.35
                let spiral = coreRadius * (0.30 + t * (2.45 + energy * 1.0))
                let wobble = radius * 0.025 * sin(CGFloat(time) * 2.7 + t * 17 + CGFloat(index))
                let point = CGPoint(
                    x: center.x + cos(angle) * (spiral + wobble),
                    y: center.y + sin(angle) * (spiral * 0.62 + wobble)
                )

                if step == 0 {
                    filament.move(to: point)
                } else {
                    filament.addLine(to: point)
                }
            }

            let alpha = 0.34 + energy * 0.35
            var glow = context
            glow.addFilter(.blur(radius: max(0.7, scale * 1.4)))
            glow.stroke(filament, with: .color(activeTheme.amber.opacity(alpha * 0.50)), style: StrokeStyle(lineWidth: max(0.65, scale * 1.6), lineCap: .round, lineJoin: .round))
            context.stroke(filament, with: .color(activeTheme.glint.opacity(alpha)), style: StrokeStyle(lineWidth: max(0.34, scale * 0.65), lineCap: .round, lineJoin: .round))
        }
    }

    private func ring(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat, start: TimeInterval, sweep: CGFloat, color: Color, width: CGFloat) {
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: .radians(start), endAngle: .radians(start + TimeInterval(sweep)), clockwise: false)
        context.stroke(path, with: .color(color), lineWidth: width)
    }

    private func random(_ a: Int, _ b: Int, _ c: Int) -> CGFloat {
        let value = sin(Double(a * 12_989 + b * 78_233 + c * 37_719)) * 43_758.5453
        return CGFloat(value - floor(value))
    }

    private func ellipticalArcPath(
        center: CGPoint,
        radiusX: CGFloat,
        radiusY: CGFloat,
        start: CGFloat,
        sweep: CGFloat,
        wobble: CGFloat,
        time: TimeInterval,
        seed: CGFloat
    ) -> Path {
        var path = Path()
        let steps = max(5, Int(abs(sweep) / (.pi * 2) * 88))

        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let angle = start + sweep * t
            let rough = sin(angle * 9 + CGFloat(time) * 2.4 + seed) * wobble
                + sin(angle * 23 - CGFloat(time) * 1.5 + seed * 0.37) * wobble * 0.48
            let point = CGPoint(
                x: center.x + cos(angle) * (radiusX + rough),
                y: center.y + sin(angle) * (radiusY + rough)
            )

            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }
}
