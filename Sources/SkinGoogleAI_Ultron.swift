//
//  UltronHologramVisualizer.swift
//  Agent Speak
//
//  Cinematic 3D Holographic AI Visualizer — U.L.T.R.O.N. "Fractured Neural Core"
//  Engineered for macOS 14+ (Sonoma & Sequoia)
//  100% Native SwiftUI using Canvas API & GraphicsContext with Metal GPU acceleration.
//  Cinematically matched to the Scepter Neural AI & Ultron Awakening (Avengers: Age of Ultron).
//

import SwiftUI
import CoreGraphics
import Foundation

// MARK: - Ultron Hologram Visualizer View
public struct GoogleAI_UltronView: View {
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
        themeColor: Color = Color(red: 1.0, green: 0.10, blue: 0.16), // Searing Blood Crimson
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
                
                // Sinister Idle Breathing / Heartbeat Respiration
                let beatCycle = fmod(time * 1.15, 1.0)
                let heartbeat = beatCycle < 0.16 ? sin(beatCycle / 0.16 * .pi) * 0.08 : 0.0
                let speechPulse = isSpeaking ? (audioLevel * 0.16) : 0.0
                let bassShock = audioBass * (isSpeaking || isPlayingMusic ? 0.22 : 0.06)
                let activeRadius = baseRadius * (1.0 + heartbeat + speechPulse + bassShock)
                
                let agitation: CGFloat = isSpeaking ? (0.35 + audioLevel * 0.65) : (isPlayingMusic ? 0.25 + audioBass * 0.40 : 0.08)
                
                // Set additive Metal blending mode
                context.blendMode = HologramManager.shared.currentBlendMode.graphicsBlendMode
                
                // LAYER 0: Menacing Atmospheric Nebula & Bio-Plasma Core Bloom
                drawAtmosphericNebula(context: &context, center: center, radius: activeRadius, time: time, agitation: agitation, lifecycle: lifecycle)
                
                // LAYER 1: Synaptic 3D Neural Lattice & Drifting Axon Nodes
                drawSynapticNeuralLattice(context: &context, center: center, radius: activeRadius, time: time, agitation: agitation, scale: scale, lifecycle: lifecycle)
                
                // LAYER 2: Chaotic Branching Lightning Tendrils & Electrical Discharges
                if lifecycle.power > 0.20 {
                    drawChaoticLightningArcs(context: &context, center: center, radius: activeRadius, time: time, agitation: agitation, bass: bassShock, scale: scale, lifecycle: lifecycle)
                }
                
                // LAYER 3: Aggressive Serrated Saw-Tooth Frequency Waveform
                drawSawtoothEqualizer(context: &context, center: center, radius: activeRadius, time: time, agitation: agitation, scale: scale, lifecycle: lifecycle)
                
                // LAYER 4: Fractured Polygonal Geometric Iris Core (Contracting Shards)
                drawFracturedOpticCore(context: &context, center: center, radius: activeRadius, time: time, agitation: agitation, scale: scale, lifecycle: lifecycle)
                
                // LAYER 5: Blinding White-Laser Optical Eye & Visor Aperture Slit
                drawPupilAperture(context: &context, center: center, radius: activeRadius, time: time, agitation: agitation, scale: scale, lifecycle: lifecycle)
                
                // LAYER 6: Swarm of Drifting Neurotransmitter Sparks & Ash Embers
                drawNeuralSparks(context: &context, center: center, radius: activeRadius, time: time, agitation: agitation, scale: scale, lifecycle: lifecycle)
            }
            .drawingGroup(opaque: false, colorMode: .extendedLinear)
        }
        .frame(width: customWidth ?? size, height: size)
        .accessibilityLabel(isSpeaking ? "Ultron neural core speaking" : "Ultron neural core active")
    }
    
    // MARK: - Layer 0: Menacing Atmospheric Nebula & Bio-Plasma Core Bloom
    private func drawAtmosphericNebula(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, time: TimeInterval, agitation: CGFloat, lifecycle: HologramLifecycleState) {
        let sphere = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        let nebulaBounds = sphere.insetBy(dx: -radius * 0.25, dy: -radius * 0.25)
        
        var blurred = context
        blurred.addFilter(.blur(radius: radius * (0.28 + agitation * 0.15)))
        
        let secondaryColor = Color(red: 1.0, green: 0.35, blue: 0.05) // Hot infrared orange
        let powerFade = Double(lifecycle.power)
        
        blurred.fill(
            Path(ellipseIn: nebulaBounds),
            with: .radialGradient(
                Gradient(colors: [
                    themeColor.opacity((0.40 + agitation * 0.30) * powerFade),
                    secondaryColor.opacity((0.18 + agitation * 0.14) * powerFade),
                    Color.clear
                ]),
                center: center,
                startRadius: radius * 0.05,
                endRadius: radius * 1.35
            )
        )
    }
    
    // MARK: - Layer 1: Synaptic 3D Neural Lattice & Drifting Axon Nodes
    private func drawSynapticNeuralLattice(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, time: TimeInterval, agitation: CGFloat, scale: CGFloat, lifecycle: HologramLifecycleState) {
        let nodeCount = size < 200 ? 28 : 52
        var nodes: [CGPoint] = []
        var growths: [CGFloat] = []
        nodes.reserveCapacity(nodeCount)
        growths.reserveCapacity(nodeCount)
        
        for i in 0..<nodeCount {
            let baseAngle = (CGFloat(i) / CGFloat(nodeCount)) * .pi * 2.0
            let rFrac = 0.25 + pseudoRandom(i, 89, 7) * 0.65
            let growth = lifecycle.axonGrowth(normalizedDist: rFrac)
            let driftX = sin(CGFloat(time) * 1.3 + CGFloat(i * 13)) * (radius * 0.04) * growth
            let driftY = cos(CGFloat(time) * 1.1 + CGFloat(i * 17)) * (radius * 0.04) * growth
            
            let pt = CGPoint(
                x: center.x + cos(baseAngle) * (radius * rFrac * growth) + driftX,
                y: center.y + sin(baseAngle) * (radius * rFrac * 0.85 * growth) + driftY
            )
            nodes.append(pt)
            growths.append(growth)
        }
        
        // Draw axon filament interconnections
        let maxDist = radius * 0.42
        for i in 0..<nodeCount {
            let p1 = nodes[i]
            let g1 = growths[i]
            guard g1 > 0.05 else { continue }
            
            for j in (i + 1)..<min(nodeCount, i + 7) {
                let p2 = nodes[j]
                let g2 = growths[j]
                guard g2 > 0.05 else { continue }
                
                let dx = p2.x - p1.x
                let dy = p2.y - p1.y
                let dist = sqrt(dx * dx + dy * dy)
                
                if dist < maxDist {
                    let minG = min(g1, g2)
                    let proximity = 1.0 - (dist / maxDist)
                    let alpha = proximity * (0.15 + agitation * 0.45) * Double(minG)
                    
                    var axon = Path()
                    axon.move(to: p1)
                    axon.addLine(to: p2)
                    
                    context.stroke(
                        axon,
                        with: .color(themeColor.opacity(alpha)),
                        style: StrokeStyle(lineWidth: max(0.35, scale * (0.4 + proximity * 0.6) * minG), lineCap: .round)
                    )
                    
                    // Traveling action potential electrical impulse
                    let pulsePhase = fmod(time * 1.4 + Double(i * 5 + j), 1.0)
                    let pulsePos = CGPoint(x: p1.x + dx * CGFloat(pulsePhase), y: p1.y + dy * CGFloat(pulsePhase))
                    let pulseRadius = max(0.8, scale * 1.5 * minG)
                    let pulseRect = CGRect(x: pulsePos.x - pulseRadius, y: pulsePos.y - pulseRadius, width: pulseRadius * 2, height: pulseRadius * 2)
                    context.fill(Path(ellipseIn: pulseRect), with: .color(Color.white.opacity(alpha * 1.4)))
                }
            }
        }
        
        // Draw synaptic neuron node bodies
        for (i, node) in nodes.enumerated() {
            let g = growths[i]
            guard g > 0.05 else { continue }
            let pulse = 0.5 + 0.5 * sin(CGFloat(time) * 4.0 + CGFloat(i * 7))
            let nodeRadius = max(1.2, scale * (1.6 + pulse * 1.4 + agitation * 1.2) * g)
            let rect = CGRect(x: node.x - nodeRadius, y: node.y - nodeRadius, width: nodeRadius * 2, height: nodeRadius * 2)
            
            // Synaptic flash
            if i % 5 == 0 {
                var flash = context
                flash.addFilter(.blur(radius: nodeRadius * 1.8))
                flash.fill(Path(ellipseIn: rect.insetBy(dx: -nodeRadius, dy: -nodeRadius)), with: .color(Color.white.opacity(0.45 * Double(g))))
            }
            
            context.fill(Path(ellipseIn: rect), with: .color(i % 3 == 0 ? Color.white : themeColor.opacity(Double(g))))
        }
    }
    
    // MARK: - Layer 2: Chaotic Branching Lightning Tendrils & Electrical Discharges
    private func drawChaoticLightningArcs(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, time: TimeInterval, agitation: CGFloat, bass: CGFloat, scale: CGFloat, lifecycle: HologramLifecycleState) {
        let arcCount = (isSpeaking || isPlayingMusic || bass > 0.05) ? (size < 200 ? 4 : 7) : 2
        
        for a in 0..<arcCount {
            let angle = (CGFloat(a) / CGFloat(arcCount)) * .pi * 2.0 + CGFloat(time * 0.8) + pseudoRandom(a, 91, 3) * 0.5
            let startR = radius * 0.12 * lifecycle.power
            let endR = radius * (0.85 + agitation * 0.25) * lifecycle.power
            
            var current = CGPoint(x: center.x + cos(angle) * startR, y: center.y + sin(angle) * startR)
            var lightning = Path()
            lightning.move(to: current)
            
            let segments = 10
            for s in 1...segments {
                let frac = CGFloat(s) / CGFloat(segments)
                let targetR = startR + (endR - startR) * frac
                let jitterAngle = angle + (pseudoRandom(s, a, Int(time * 12.0) % 50) - 0.5) * (0.35 + agitation * 0.4)
                let nextPt = CGPoint(x: center.x + cos(jitterAngle) * targetR, y: center.y + sin(jitterAngle) * targetR)
                
                lightning.addLine(to: nextPt)
                
                // Fork branching tendril
                if s == 5 && agitation > 0.25 {
                    var fork = Path()
                    fork.move(to: nextPt)
                    let forkAngle = jitterAngle + 0.4
                    let forkEnd = CGPoint(x: center.x + cos(forkAngle) * (targetR + radius * 0.18), y: center.y + sin(forkAngle) * (targetR + radius * 0.18))
                    fork.addLine(to: forkEnd)
                    context.stroke(fork, with: .color(Color.white.opacity(0.65 * Double(lifecycle.power))), style: StrokeStyle(lineWidth: max(0.4, scale * 0.7), lineCap: .round))
                }
                
                current = nextPt
            }
            
            let alpha = (0.45 + agitation * 0.50) * Double(lifecycle.power)
            
            // Pass 1: Blurred electric aura
            var glow = context
            glow.addFilter(.blur(radius: max(1.0, scale * 1.8)))
            glow.stroke(lightning, with: .color(themeColor.opacity(alpha * 0.75)), style: StrokeStyle(lineWidth: max(1.2, scale * 2.2), lineCap: .round))
            
            // Pass 2: Laser white core
            context.stroke(lightning, with: .color(Color.white.opacity(alpha)), style: StrokeStyle(lineWidth: max(0.5, scale * 0.8), lineCap: .round))
        }
    }
    
    // MARK: - Layer 3: Aggressive Serrated Saw-Tooth Frequency Waveform
    private func drawSawtoothEqualizer(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, time: TimeInterval, agitation: CGFloat, scale: CGFloat, lifecycle: HologramLifecycleState) {
        let deploy = lifecycle.ringProgress(index: 2, total: 3)
        guard deploy > 0.05 else { return }
        
        let spikeCount = size < 200 ? 44 : 76
        let perimeterR = radius * 0.82 * deploy
        var path = Path()
        
        for i in 0...spikeCount {
            let angle = (CGFloat(i) / CGFloat(spikeCount)) * .pi * 2.0
            let phase = angle * 8.0 + CGFloat(time * 16.0)
            let rawWave = sin(phase) + (sin(phase * 3.0) * 0.33)
            let spike = abs(rawWave) * (radius * 0.14) * agitation * deploy
            let r = perimeterR + (i % 2 == 0 ? spike : -spike * 0.4)
            
            let pt = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * (r * 0.88))
            if i == 0 {
                path.move(to: pt)
            } else {
                path.addLine(to: pt)
            }
        }
        path.closeSubpath()
        
        let alpha = (0.25 + agitation * 0.50) * Double(deploy)
        var glow = context
        glow.addFilter(.blur(radius: max(0.8, scale * 1.5)))
        glow.stroke(path, with: .color(themeColor.opacity(alpha * 0.6)), style: StrokeStyle(lineWidth: max(0.8, scale * 1.6), lineCap: .round, lineJoin: .round))
        
        context.stroke(path, with: .color(Color.white.opacity(alpha * 0.8)), style: StrokeStyle(lineWidth: max(0.4, scale * 0.8), lineCap: .round, lineJoin: .round))
    }
    
    // MARK: - Layer 4: Fractured Polygonal Geometric Iris Core (Contracting Shards)
    private func drawFracturedOpticCore(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, time: TimeInterval, agitation: CGFloat, scale: CGFloat, lifecycle: HologramLifecycleState) {
        let burst = 1.0 + lifecycle.coreBurst * 1.5
        let coreR = radius * (0.16 + agitation * 0.08) * burst
        let shardTiers = [
            (sides: 6, rMult: CGFloat(1.0), rotSpeed: 1.2),
            (sides: 8, rMult: CGFloat(1.4), rotSpeed: -0.9),
            (sides: 5, rMult: CGFloat(1.8), rotSpeed: 0.6)
        ]
        
        for tier in shardTiers {
            var poly = Path()
            let r = coreR * tier.rMult
            let rotation = CGFloat(time * tier.rotSpeed) * lifecycle.spinVelocityMultiplier
            
            for s in 0..<tier.sides {
                let angle = (CGFloat(s) / CGFloat(tier.sides)) * .pi * 2.0 + rotation
                let jitter = sin(angle * 3.0 + CGFloat(time * 8.0)) * (radius * 0.015 * agitation)
                let pt = CGPoint(x: center.x + cos(angle) * (r + jitter), y: center.y + sin(angle) * (r + jitter))
                if s == 0 {
                    poly.move(to: pt)
                } else {
                    poly.addLine(to: pt)
                }
            }
            poly.closeSubpath()
            
            let alpha = min(1.0, (0.30 + agitation * 0.45) * Double(1.0 + lifecycle.coreBurst))
            context.stroke(poly, with: .color(themeColor.opacity(alpha)), style: StrokeStyle(lineWidth: max(0.5, scale * 1.0), lineCap: .round))
        }
    }
    
    // MARK: - Layer 5: Blinding White-Laser Optical Eye & Visor Aperture Slit
    private func drawPupilAperture(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, time: TimeInterval, agitation: CGFloat, scale: CGFloat, lifecycle: HologramLifecycleState) {
        let burst = 1.0 + lifecycle.coreBurst * 2.0
        let pupilWidth = radius * (0.18 + agitation * 0.12) * burst
        let pupilHeight = max(2.0, radius * (0.025 + agitation * 0.04) * burst)
        let pupilRect = CGRect(x: center.x - pupilWidth / 2.0, y: center.y - pupilHeight / 2.0, width: pupilWidth, height: pupilHeight)
        
        var pupilGlow = context
        pupilGlow.addFilter(.blur(radius: max(1.8, scale * 2.8)))
        pupilGlow.fill(Path(ellipseIn: pupilRect.insetBy(dx: -pupilWidth * 0.3, dy: -pupilHeight * 1.5)), with: .color(Color.white.opacity(min(1.0, (0.75 + agitation * 0.25) * Double(burst)))))
        
        context.fill(Path(ellipseIn: pupilRect), with: .color(Color.white))
    }
    
    // MARK: - Layer 6: Swarm of Drifting Neurotransmitter Sparks & Ash Embers
    private func drawNeuralSparks(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, time: TimeInterval, agitation: CGFloat, scale: CGFloat, lifecycle: HologramLifecycleState) {
        guard lifecycle.power > 0.10 else { return }
        let sparkCount = size < 200 ? 60 : 180
        
        for i in 0..<sparkCount {
            let seedAngle = pseudoRandom(i, 311, 13) * .pi * 2.0
            let r = radius * pow(pseudoRandom(i, 313, 19), 0.5) * (0.95 + agitation * 0.15) * lifecycle.power
            let orbit = CGFloat(time) * (0.08 + pseudoRandom(i, 317, 23) * 0.25) * lifecycle.spinVelocityMultiplier
            let angle = seedAngle + orbit
            
            let px = center.x + cos(angle) * r
            let py = center.y + sin(angle) * (r * 0.85)
            
            let twinkle = 0.30 + 0.70 * max(0.0, sin(CGFloat(time) * 3.5 + seedAngle * 4.0))
            let alpha = (0.15 + twinkle * 0.45 + agitation * 0.30) * Double(lifecycle.power)
            let dotSize = max(0.4, scale * (0.4 + pseudoRandom(i, 321, 29) * 1.5))
            let rect = CGRect(x: px - dotSize / 2.0, y: py - dotSize / 2.0, width: dotSize, height: dotSize)
            
            context.fill(Path(ellipseIn: rect), with: .color(i % 7 == 0 ? Color.white : themeColor.opacity(alpha)))
        }
    }
    
    // MARK: - Mathematical Helper Utilities
    private func pseudoRandom(_ a: Int, _ b: Int, _ c: Int) -> CGFloat {
        let v = sin(Double(a * 12_989 + b * 78_233 + c * 37_719)) * 43_758.5453
        return CGFloat(v - floor(v))
    }
}

// MARK: - Xcode Interactive Preview Host
#if DEBUG
struct UltronHologramVisualizer_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            UltronHologramVisualizer(
                isSpeaking: true,
                isPlayingMusic: false,
                size: 420,
                themeColor: Color(red: 1.0, green: 0.10, blue: 0.16),
                audioLevel: 0.70,
                audioBass: 0.55
            )
        }
    }
}
#endif
