//
//  JarvisHologramVisualizer.swift
//  Agent Speak
//
//  Cinematic 3D Holographic AI Visualizer — J.A.R.V.I.S. "Arc Reactor Matrix"
//  Engineered for macOS 14+ (Sonoma & Sequoia)
//  100% Native SwiftUI using Canvas API & GraphicsContext with Metal GPU acceleration.
//  Cinematically matched to Tony Stark's Lab Holo-Projector (Avengers: Age of Ultron).
//

import SwiftUI
import CoreGraphics
import Foundation

// MARK: - Jarvis Hologram Visualizer View
public struct GoogleAI_JarvisView: View {
    // MARK: Input Data Contract
    public var isSpeaking: Bool
    public var isPlayingMusic: Bool
    public var size: CGFloat
    public var themeColor: Color
    public var audioLevel: CGFloat       // 0.0 ... 1.0
    public var audioBass: CGFloat        // 0.0 ... 1.0
    public var customWidth: CGFloat?
    
    // Default initializers for drop-in flexibility
    public init(
        isSpeaking: Bool = false,
        isPlayingMusic: Bool = false,
        size: CGFloat = 400,
        customWidth: CGFloat? = nil,
        themeColor: Color = Color(red: 1.0, green: 0.70, blue: 0.12), // Stark Golden Amber
        audioLevel: CGFloat = 0.0,
        audioBass: CGFloat = 0.0
    ) {
        self.isSpeaking = isSpeaking
        self.isPlayingMusic = isPlayingMusic
        self.size = size
        self.customWidth = customWidth
        self.themeColor = themeColor
        self.audioLevel = max(0.0, min(1.0, audioLevel))
        self.audioBass = max(0.0, min(1.0, audioBass))
    }
    
    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 120.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            Canvas { context, canvasSize in
                let lifecycle = HologramLifecycleState(time: time)
                guard lifecycle.power > 0.01 else { return }
                
                let center = CGPoint(x: canvasSize.width / 2.0, y: canvasSize.height / 2.0)
                let baseRadius = min(canvasSize.width, canvasSize.height) * 0.28
                let scale = max(0.40, baseRadius / 150.0)
                
                // Dynamic energy & audio processing
                let speechFactor: CGFloat = isSpeaking ? (0.35 + audioLevel * 0.65) : (isPlayingMusic ? 0.22 + audioBass * 0.38 : 0.08)
                let bassPunch: CGFloat = audioBass * (isSpeaking || isPlayingMusic ? 1.0 : 0.25)
                let respiration = sin(time * (isSpeaking ? 4.2 : 1.4)) * 0.025 + (bassPunch * 0.06)
                let activeRadius = baseRadius * (1.0 + respiration)
                
                // Set additive Metal blending mode
                context.blendMode = HologramManager.shared.currentBlendMode.graphicsBlendMode
                
                // LAYER 0: Volumetric Glass Ambient Bloom & Spherical Atmospheric Haze
                drawVolumetricBloom(context: &context, center: center, radius: activeRadius, time: time, factor: speechFactor, lifecycle: lifecycle)
                
                // LAYER 1: Spherical Depth Grid (Latitude & Longitude Foreshortened Ribs)
                drawSphericalDepthRibs(context: &context, center: center, radius: activeRadius, time: time, factor: speechFactor, scale: scale, lifecycle: lifecycle)
                
                // LAYER 2: Broken Concentric Reactor Rings (6-Tier Broken Gimbal Tracks)
                drawBrokenReactorRings(context: &context, center: center, radius: activeRadius, time: time, factor: speechFactor, bass: bassPunch, scale: scale, lifecycle: lifecycle)
                
                // LAYER 3: Dense Cybernetic Circuit Fragments (Orthogonal Stepped Traces)
                drawCircuitFragments(context: &context, center: center, radius: activeRadius, time: time, factor: speechFactor, scale: scale, lifecycle: lifecycle)
                
                // LAYER 4: Fragmented Outer Shell Shards (Right-Angle Stepped Outer Perimeter)
                drawFragmentedShell(context: &context, center: center, radius: activeRadius, time: time, factor: speechFactor, scale: scale, lifecycle: lifecycle)
                
                // LAYER 5: Taut Radial Filament Strings (Core-to-Gimbal Tension Spokes & Traveling Photons)
                drawRadialFilamentStrings(context: &context, center: center, radius: activeRadius, time: time, factor: speechFactor, scale: scale, lifecycle: lifecycle)
                
                // LAYER 6: Radial Acoustic Equalizer Burst Needles & High-Frequency Sparks
                drawVoiceEqualizerBursts(context: &context, center: center, radius: activeRadius, time: time, factor: speechFactor, bass: bassPunch, scale: scale, lifecycle: lifecycle)
                
                // LAYER 7: 3D Swarm of Orbiting Plasma Photon Particles
                if lifecycle.power > 0.15 {
                    drawPlasmaParticles(context: &context, center: center, radius: activeRadius, time: time, factor: speechFactor, scale: scale, lifecycle: lifecycle)
                }
                
                // LAYER 8: Luminous Core Knot & Solar Torus Nucleus (Intertwined Spiral Filaments)
                drawCoreKnot(context: &context, center: center, radius: activeRadius, time: time, factor: speechFactor, respiration: respiration, scale: scale, lifecycle: lifecycle)
                
                // LAYER 9: HUD Telemetry Ticks, Degree Reticles & Lab Calibration Frame
                drawHUDTelemetry(context: &context, center: center, radius: activeRadius, time: time, scale: scale, lifecycle: lifecycle)
            }
            .drawingGroup(opaque: false, colorMode: .extendedLinear)
        }
        .frame(width: customWidth ?? size, height: size)
        .accessibilityLabel(isSpeaking ? "Jarvis hologram speaking" : "Jarvis hologram active")
    }
    
    // MARK: - Layer 0: Volumetric Glass Ambient Bloom & Atmospheric Glow
    private func drawVolumetricBloom(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, time: TimeInterval, factor: CGFloat, lifecycle: HologramLifecycleState) {
        let sphere = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        let warmGlow = Path(ellipseIn: sphere.insetBy(dx: -radius * 0.20, dy: -radius * 0.20))
        
        var blurred = context
        blurred.addFilter(.blur(radius: radius * (0.24 + factor * 0.12)))
        let powerFade = Double(lifecycle.power)
        
        // Deep warm amber atmosphere
        blurred.fill(warmGlow, with: .radialGradient(
            Gradient(colors: [
                themeColor.opacity((0.35 + factor * 0.25) * powerFade),
                Color(red: 0.95, green: 0.45, blue: 0.05).opacity((0.18 + factor * 0.12) * powerFade),
                Color.clear
            ]),
            center: center,
            startRadius: radius * 0.05,
            endRadius: radius * 1.35
        ))
        
        // Inner glass sphere optical refraction
        context.fill(Path(ellipseIn: sphere), with: .radialGradient(
            Gradient(colors: [
                themeColor.opacity((0.08 + factor * 0.06) * powerFade),
                Color.clear
            ]),
            center: center,
            startRadius: radius * 0.10,
            endRadius: radius
        ))
        
        // Drifting optical lens flare arc
        let lensOffset = radius * 0.15 * sin(time * 0.45)
        let lensRect = CGRect(
            x: center.x - radius * 0.85 + lensOffset,
            y: center.y - radius * 0.92,
            width: radius * 1.50,
            height: radius * 1.84
        )
        context.stroke(
            Path(ellipseIn: lensRect),
            with: .color(themeColor.opacity((0.16 + factor * 0.10) * powerFade)),
            lineWidth: max(0.5, radius * 0.007)
        )
    }
    
    // MARK: - Layer 1: Spherical Depth Ribs (Latitude & Longitude 3D Curvature)
    private func drawSphericalDepthRibs(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, time: TimeInterval, factor: CGFloat, scale: CGFloat, lifecycle: HologramLifecycleState) {
        let deploy = lifecycle.ringProgress(index: 1, total: 6)
        guard deploy > 0.05 else { return }
        
        let latCount = 6
        let tilt: CGFloat = 0.38
        
        for i in 1...latCount {
            let frac = CGFloat(i) / CGFloat(latCount + 1)
            let latY = (frac * 2.0 - 1.0) * (radius * 0.86) * deploy
            let latW = sqrt(max(0.0, radius * radius - latY * latY)) * 2.0 * deploy
            let latH = latW * tilt
            
            let rect = CGRect(x: center.x - latW / 2.0, y: center.y + latY - latH / 2.0, width: latW, height: latH)
            let path = Path(ellipseIn: rect)
            
            let alpha = (0.10 + factor * 0.15) * (1.0 - abs(latY) / radius * 0.4) * Double(deploy)
            context.stroke(
                path,
                with: .color(themeColor.opacity(alpha)),
                style: StrokeStyle(lineWidth: max(0.4, scale * 0.75 * deploy), lineCap: .round, dash: [4, 8], dashPhase: CGFloat(time * 6.0) + CGFloat(i * 3))
            )
        }
    }
    
    // MARK: - Layer 2: Broken Concentric Reactor Rings (6-Tier Broken Gimbal Tracks)
    private func drawBrokenReactorRings(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval,
        factor: CGFloat,
        bass: CGFloat,
        scale: CGFloat,
        lifecycle: HologramLifecycleState
    ) {
        // (radiusFraction, segmentCount, sweepFraction, widthFraction, rotSpeed)
        let rings: [(CGFloat, Int, CGFloat, CGFloat, Double)] = [
            (0.24, 7, 0.22, 0.014, 1.45),
            (0.38, 11, 0.18, 0.010, -0.92),
            (0.52, 15, 0.13, 0.008, 0.65),
            (0.66, 19, 0.10, 0.006, -0.45),
            (0.80, 24, 0.08, 0.005, 0.32),
            (0.95, 30, 0.055, 0.004, -0.20)
        ]
        
        for (ringIndex, ringInfo) in rings.enumerated() {
            let deploy = lifecycle.ringProgress(index: ringIndex, total: rings.count)
            guard deploy > 0.02 else { continue }
            
            let ringR = radius * (ringInfo.0 + bass * 0.035 + factor * 0.02) * deploy
            let count = ringInfo.1
            let rotation = time * ringInfo.4 * (1.0 + Double(factor) * 1.5) * Double(lifecycle.spinVelocityMultiplier)
            let width = max(0.5, radius * ringInfo.3 * deploy)
            
            for seg in 0..<count {
                let missing = pseudoRandom(seg, ringIndex, 19)
                guard missing > (ringIndex < 2 ? 0.15 : 0.40) else { continue }
                
                let baseAngle = CGFloat(seg) / CGFloat(count) * .pi * 2.0
                let jitter = (pseudoRandom(seg, ringIndex, 2) - 0.5) * 0.10
                let start = baseAngle + CGFloat(rotation) + jitter
                let sweep = (.pi * ringInfo.2) * (0.45 + pseudoRandom(seg, ringIndex, 5) * 0.85)
                let flicker = 0.50 + 0.50 * sin(CGFloat(time) * (1.8 + pseudoRandom(seg, 4, ringIndex) * 5.5) + baseAngle * 4.0)
                let alpha = (0.15 + flicker * 0.30 + factor * 0.35) * (ringIndex == 0 ? 1.25 : 1.0) * Double(deploy)
                
                let squash = 0.74 + pseudoRandom(seg, ringIndex, 41) * 0.20
                let offset = CGPoint(
                    x: center.x - radius * (0.05 + pseudoRandom(seg, ringIndex, 43) * 0.08),
                    y: center.y + radius * (pseudoRandom(seg, ringIndex, 47) - 0.5) * 0.06
                )
                
                let path = ellipticalArcWithWobble(
                    center: offset,
                    radiusX: ringR + radius * 0.010 * sin(baseAngle * 6.0 + CGFloat(time)),
                    radiusY: ringR * squash,
                    start: start,
                    sweep: sweep,
                    wobble: radius * (0.004 + factor * 0.018) * deploy,
                    time: time,
                    seed: CGFloat(seg + ringIndex * 31)
                )
                
                let color = seg % 11 == 0 ? Color.white.opacity(alpha * 0.80) : themeColor.opacity(alpha)
                
                // Pass 1: Blurred optical aura
                var glow = context
                glow.addFilter(.blur(radius: max(0.8, scale * 1.4)))
                glow.stroke(path, with: .color(color.opacity(0.65)), style: StrokeStyle(lineWidth: width * 2.5, lineCap: .round))
                
                // Pass 2: Sharp laser core
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
        }
    }
    
    // MARK: - Layer 3: Dense Cybernetic Circuit Fragments (Orthogonal Stepped Motherboard Traces)
    private func drawCircuitFragments(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, time: TimeInterval, factor: CGFloat, scale: CGFloat, lifecycle: HologramLifecycleState) {
        let deploy = lifecycle.ringProgress(index: 3, total: 6)
        guard deploy > 0.05 else { return }
        
        let count = size < 200 ? 95 : 260
        
        for i in 0..<count {
            let angle = pseudoRandom(i, 1, 3) * .pi * 2.0 + CGFloat(time * 0.08) * (pseudoRandom(i, 8, 4) > 0.5 ? 1.0 : -1.0)
            let radialBias = pow(pseudoRandom(i, 5, 9), 0.45)
            let fragRadius = radius * (0.18 + radialBias * 0.82) * deploy
            let depth = 0.38 + pseudoRandom(i, 7, 2) * 1.02
            let x = center.x + cos(angle) * fragRadius * depth
            let y = center.y + sin(angle) * fragRadius * (0.72 + pseudoRandom(i, 13, 2) * 0.34)
            
            let tangent = angle + .pi / 2.0
            let radial = angle
            let lenA = radius * (0.012 + pseudoRandom(i, 2, 1) * 0.085) * (0.75 + factor * 0.70) * deploy
            let lenB = radius * (0.010 + pseudoRandom(i, 3, 8) * 0.065) * (0.75 + factor * 0.70) * deploy
            let bend = pseudoRandom(i, 11, 7) > 0.52 ? tangent : radial
            let second = pseudoRandom(i, 17, 7) > 0.54 ? radial : tangent
            
            let phase = CGFloat(time) * (1.3 + pseudoRandom(i, 31, 4) * 4.2) + angle * 2.0
            let flicker = 0.40 + 0.60 * max(0.0, sin(phase))
            let alpha = (0.10 + flicker * 0.32 + factor * 0.28) * (1.0 - radialBias * 0.15) * Double(deploy)
            
            var trace = Path()
            trace.move(to: CGPoint(x: x, y: y))
            let p1 = CGPoint(x: x + cos(bend) * lenA, y: y + sin(bend) * lenA)
            let p2 = CGPoint(x: p1.x + cos(second) * lenB, y: p1.y + sin(second) * lenB)
            trace.addLine(to: p1)
            trace.addLine(to: p2)
            
            // Branch terminal node
            if i % 6 == 0 {
                let branch = CGPoint(
                    x: p1.x + cos(second + .pi / 2.0) * lenB * 0.55,
                    y: p1.y + sin(second + .pi / 2.0) * lenB * 0.55
                )
                trace.move(to: p1)
                trace.addLine(to: branch)
            }
            
            let lineWidth = max(0.24, scale * (0.26 + pseudoRandom(i, 29, 2) * 0.45) * deploy)
            let color = i % 10 == 0 ? Color.white.opacity(alpha * 0.85) : themeColor.opacity(alpha)
            context.stroke(trace, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }
    
    // MARK: - Layer 4: Fragmented Outer Shell Shards (Stepped Right-Angle Polygonal Shards)
    private func drawFragmentedShell(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, time: TimeInterval, factor: CGFloat, scale: CGFloat, lifecycle: HologramLifecycleState) {
        let deploy = lifecycle.ringProgress(index: 4, total: 6)
        guard deploy > 0.05 else { return }
        
        let shellCount = size < 200 ? 38 : 118
        
        for i in 0..<shellCount {
            let seed = pseudoRandom(i, 401, 17)
            let baseAngle = seed * .pi * 2.0
            let slowDrift = CGFloat(time) * (0.04 + pseudoRandom(i, 409, 11) * 0.14) * lifecycle.spinVelocityMultiplier
            let angle = baseAngle + slowDrift
            let shellR = radius * (0.68 + pseudoRandom(i, 419, 5) * 0.44 + factor * 0.04) * deploy
            let side = pseudoRandom(i, 421, 8) > 0.5 ? CGFloat(1.0) : CGFloat(-1.0)
            let steps = 2 + Int(pseudoRandom(i, 431, 3) * 4.0)
            
            var path = Path()
            var cursor = CGPoint(
                x: center.x + cos(angle) * shellR,
                y: center.y + sin(angle) * shellR * (0.75 + pseudoRandom(i, 433, 13) * 0.26)
            )
            path.move(to: cursor)
            
            for step in 0..<steps {
                let stepAngle = angle + (step % 2 == 0 ? .pi / 2.0 : 0.0) * side
                let length = radius * (0.018 + pseudoRandom(i, step + 439, 2) * 0.068) * deploy
                cursor = CGPoint(
                    x: cursor.x + cos(stepAngle) * length,
                    y: cursor.y + sin(stepAngle) * length
                )
                path.addLine(to: cursor)
            }
            
            let phase = CGFloat(time) * (1.2 + pseudoRandom(i, 443, 6) * 5.2) + baseAngle * 2.5
            let flicker = 0.25 + 0.75 * max(0.0, sin(phase))
            let alpha = (0.12 + flicker * 0.32 + factor * 0.35) * Double(deploy)
            let lineWidth = max(0.24, scale * (0.22 + pseudoRandom(i, 449, 4) * 0.55))
            
            if i % 8 == 0 {
                var glow = context
                glow.addFilter(.blur(radius: max(0.5, scale * 1.2)))
                glow.stroke(path, with: .color(themeColor.opacity(alpha * 0.40)), style: StrokeStyle(lineWidth: lineWidth * 3.2, lineCap: .round, lineJoin: .round))
            }
            context.stroke(path, with: .color(themeColor.opacity(alpha)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }
    
    // MARK: - Layer 5: Taut Radial Filament Strings & Traveling Photon Energy Packets (Film Close-up)
    private func drawRadialFilamentStrings(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, time: TimeInterval, factor: CGFloat, scale: CGFloat, lifecycle: HologramLifecycleState) {
        let deploy = lifecycle.ringProgress(index: 2, total: 6)
        guard deploy > 0.05 else { return }
        
        let stringCount = 28
        let innerR = radius * 0.15
        let outerR = radius * 0.82 * deploy
        
        for i in 0..<stringCount {
            let angle = (CGFloat(i) / CGFloat(stringCount)) * .pi * 2.0 + CGFloat(time * 0.10)
            let tension = isSpeaking ? sin(angle * 5.0 + CGFloat(time * 28.0)) * (factor * 3.0) : 0.0
            
            let p1 = CGPoint(x: center.x + cos(angle) * innerR, y: center.y + sin(angle) * innerR)
            let p2 = CGPoint(x: center.x + cos(angle + tension * 0.015) * outerR, y: center.y + sin(angle + tension * 0.015) * outerR)
            
            var line = Path()
            line.move(to: p1)
            line.addLine(to: p2)
            
            let alpha = (0.20 + (CGFloat(i % 3) * 0.12) + factor * 0.35) * Double(deploy)
            let width = max(0.4, scale * (0.5 + CGFloat(i % 2) * 0.4))
            
            context.stroke(line, with: .color(themeColor.opacity(alpha)), style: StrokeStyle(lineWidth: width, lineCap: .round))
            
            // Traveling photon packet node along filament
            let packetProgress = fmod((time * 0.65 + Double(i) * 0.22), 1.0)
            let packetPos = CGPoint(
                x: p1.x + (p2.x - p1.x) * CGFloat(packetProgress),
                y: p1.y + (p2.y - p1.y) * CGFloat(packetProgress)
            )
            let dotRadius = max(1.0, scale * 1.8 * deploy)
            let dotRect = CGRect(x: packetPos.x - dotRadius, y: packetPos.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
            
            context.fill(Path(ellipseIn: dotRect), with: .color(Color.white.opacity((0.85 + factor * 0.15) * Double(deploy))))
        }
    }
    
    // MARK: - Layer 6: Radial Acoustic Equalizer Burst Needles & High-Frequency Sparks
    private func drawVoiceEqualizerBursts(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, time: TimeInterval, factor: CGFloat, bass: CGFloat, scale: CGFloat, lifecycle: HologramLifecycleState) {
        let deploy = lifecycle.ringProgress(index: 5, total: 6)
        guard deploy > 0.05 else { return }
        
        let bandCount = size < 200 ? 24 : 52
        let activeEnergy = (0.28 + factor * 1.35 + bass * 0.85) * deploy
        
        for i in 0..<bandCount {
            let t = CGFloat(i) / CGFloat(max(1, bandCount - 1))
            let angle = CGFloat.pi * (0.80 + t * 0.90) + CGFloat(time) * 0.045
            let beat = 0.32 + 0.68 * max(0.0, sin(CGFloat(time) * (3.2 + pseudoRandom(i, 601, 3) * 7.8) + t * 9.5))
            let outer = radius * (0.78 + beat * 0.22 * activeEnergy + pseudoRandom(i, 607, 2) * 0.14) * deploy
            let inner = radius * (0.42 + pseudoRandom(i, 613, 4) * 0.18) * deploy
            
            var bar = Path()
            bar.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner * 0.76))
            bar.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer * 0.76))
            
            let alpha = (0.10 + beat * 0.40 + factor * 0.42) * Double(deploy)
            let width = max(0.3, scale * (0.32 + beat * 1.1))
            context.stroke(bar, with: .color(Color.white.opacity(alpha * 0.65)), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }
    }
    
    // MARK: - Layer 7: Swarm of 3D Orbiting Plasma Photon Particles
    private func drawPlasmaParticles(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, time: TimeInterval, factor: CGFloat, scale: CGFloat, lifecycle: HologramLifecycleState) {
        guard lifecycle.power > 0.10 else { return }
        let count = size < 200 ? 120 : 380
        
        for i in 0..<count {
            let seedAngle = pseudoRandom(i, 211, 17) * .pi * 2.0
            let orbit = CGFloat(time) * (0.05 + pseudoRandom(i, 223, 19) * 0.30) * lifecycle.spinVelocityMultiplier
            let angle = seedAngle + orbit
            let r = radius * pow(pseudoRandom(i, 227, 23), 0.46) * (0.98 + factor * 0.08) * lifecycle.power
            let ellipse = 0.70 + pseudoRandom(i, 229, 29) * 0.34
            let px = center.x + cos(angle) * r
            let py = center.y + sin(angle) * r * ellipse
            let twinkle = 0.30 + 0.70 * max(0.0, sin(CGFloat(time) * (1.9 + pseudoRandom(i, 233, 31) * 6.2) + seedAngle * 5.0))
            let alpha = (0.12 + twinkle * 0.42 + factor * 0.32) * Double(lifecycle.power)
            let dotSize = max(0.35, scale * (0.35 + pseudoRandom(i, 239, 37) * 1.4) * (i % 21 == 0 ? 2.2 : 1.0))
            let rect = CGRect(x: px - dotSize / 2.0, y: py - dotSize / 2.0, width: dotSize, height: dotSize)
            
            if i % 17 == 0 {
                var glow = context
                glow.addFilter(.blur(radius: dotSize * 1.8))
                glow.fill(Path(ellipseIn: rect.insetBy(dx: -dotSize * 1.3, dy: -dotSize * 1.3)), with: .color(Color.white.opacity(alpha * 0.30)))
            }
            context.fill(Path(ellipseIn: rect), with: .color(themeColor.opacity(alpha)))
        }
    }
    
    // MARK: - Layer 8: Luminous Core Knot & Solar Torus Nucleus (Intertwined Spiral Filaments)
    private func drawCoreKnot(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, time: TimeInterval, factor: CGFloat, respiration: CGFloat, scale: CGFloat, lifecycle: HologramLifecycleState) {
        let burst = 1.0 + lifecycle.coreBurst * 1.5
        let coreRadius = radius * (0.065 + factor * 0.035 + respiration * 0.01) * burst
        let coreRect = CGRect(x: center.x - coreRadius, y: center.y - coreRadius, width: coreRadius * 2, height: coreRadius * 2)
        
        // Deep core aura bloom
        var coreGlow = context
        coreGlow.addFilter(.blur(radius: max(1.5, scale * 2.2)))
        coreGlow.fill(Path(ellipseIn: coreRect.insetBy(dx: -coreRadius * 0.4, dy: -coreRadius * 0.4)), with: .radialGradient(
            Gradient(colors: [
                Color.white.opacity(min(1.0, (0.50 + factor * 0.25) * Double(burst))),
                themeColor.opacity(0.35),
                Color.clear
            ]),
            center: center,
            startRadius: 0,
            endRadius: coreRadius * 1.6
        ))
        
        // Solar white-hot center aperture
        context.fill(Path(ellipseIn: coreRect), with: .radialGradient(
            Gradient(colors: [
                Color.white.opacity(min(1.0, (0.75 + factor * 0.20) * Double(burst))),
                themeColor.opacity(0.45),
                Color.clear
            ]),
            center: center,
            startRadius: 0,
            endRadius: coreRadius
        ))
        
        // Intertwined mathematical spiral knot
        let filamentCount = size < 200 ? 5 : 9
        for i in 0..<filamentCount {
            var filament = Path()
            let phase = CGFloat(time) * (0.92 + CGFloat(i) * 0.18) * lifecycle.spinVelocityMultiplier + pseudoRandom(i, 307, 2) * .pi * 2.0
            let turns = 44
            
            for step in 0...turns {
                let t = CGFloat(step) / CGFloat(turns)
                let angle = phase + t * .pi * 2.15 + sin(t * .pi * 4.0 + phase) * 0.35
                let spiral = coreRadius * (0.32 + t * (2.45 + factor * 1.1))
                let wobble = radius * 0.025 * sin(CGFloat(time) * 2.8 + t * 18.0 + CGFloat(i))
                let pt = CGPoint(
                    x: center.x + cos(angle) * (spiral + wobble),
                    y: center.y + sin(angle) * (spiral * 0.64 + wobble)
                )
                
                if step == 0 {
                    filament.move(to: pt)
                } else {
                    filament.addLine(to: pt)
                }
            }
            
            let alpha = min(1.0, (0.38 + factor * 0.38) * Double(1.0 + lifecycle.coreBurst))
            var glow = context
            glow.addFilter(.blur(radius: max(0.8, scale * 1.5)))
            glow.stroke(filament, with: .color(themeColor.opacity(alpha * 0.52)), style: StrokeStyle(lineWidth: max(0.7, scale * 1.7), lineCap: .round, lineJoin: .round))
            context.stroke(filament, with: .color(Color.white.opacity(alpha)), style: StrokeStyle(lineWidth: max(0.35, scale * 0.7), lineCap: .round, lineJoin: .round))
        }
    }
    
    // MARK: - Layer 9: HUD Telemetry Ticks & Calibration Framing
    private func drawHUDTelemetry(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, time: TimeInterval, scale: CGFloat, lifecycle: HologramLifecycleState) {
        let deploy = lifecycle.ringProgress(index: 5, total: 6)
        guard deploy > 0.05 else { return }
        
        let tickCount = 48
        let tickR = radius * 1.06 * deploy
        let hudAlpha = 0.22 * Double(deploy)
        
        for i in 0..<tickCount {
            let angle = (CGFloat(i) / CGFloat(tickCount)) * .pi * 2.0 + CGFloat(time * 0.02)
            let isMajor = i % 6 == 0
            let length = (isMajor ? radius * 0.045 : radius * 0.02) * deploy
            
            var tick = Path()
            tick.move(to: CGPoint(x: center.x + cos(angle) * tickR, y: center.y + sin(angle) * tickR))
            tick.addLine(to: CGPoint(x: center.x + cos(angle) * (tickR + length), y: center.y + sin(angle) * (tickR + length)))
            
            context.stroke(
                tick,
                with: .color(isMajor ? Color.white.opacity(hudAlpha * 1.4) : themeColor.opacity(hudAlpha)),
                style: StrokeStyle(lineWidth: max(0.4, scale * (isMajor ? 0.9 : 0.5)), lineCap: .butt)
            )
        }
    }
    
    // MARK: - Mathematical Helper Utilities
    private func pseudoRandom(_ a: Int, _ b: Int, _ c: Int) -> CGFloat {
        let v = sin(Double(a * 12_989 + b * 78_233 + c * 37_719)) * 43_758.5453
        return CGFloat(v - floor(v))
    }
    
    private func ellipticalArcWithWobble(
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
        let steps = max(6, Int(abs(sweep) / (.pi * 2.0) * 85.0))
        
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let angle = start + sweep * t
            let rough = sin(angle * 9.0 + CGFloat(time) * 2.4 + seed) * wobble
                + sin(angle * 23.0 - CGFloat(time) * 1.5 + seed * 0.37) * wobble * 0.48
            let pt = CGPoint(
                x: center.x + cos(angle) * (radiusX + rough),
                y: center.y + sin(angle) * (radiusY + rough)
            )
            
            if step == 0 {
                path.move(to: pt)
            } else {
                path.addLine(to: pt)
            }
        }
        
        return path
    }
}

// MARK: - Xcode Interactive Preview Host
#if DEBUG
struct JarvisHologramVisualizer_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            JarvisHologramVisualizer(
                isSpeaking: true,
                isPlayingMusic: false,
                size: 420,
                themeColor: Color(red: 1.0, green: 0.70, blue: 0.12),
                audioLevel: 0.65,
                audioBass: 0.40
            )
        }
    }
}
#endif
