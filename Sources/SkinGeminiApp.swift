import SwiftUI
import CoreGraphics
import Foundation

// =============================================================================
// MARK: - HOLOGRAPHIC COLOR PALETTES
// =============================================================================

public enum HologramSkin: String, CaseIterable, Identifiable {
    case jarvis = "JARVIS (Spherical Circuit Matrix)"
    case ultron = "ULTRON (Mind Stone Synaptic Brain)"
    
    public var id: String { rawValue }
}

public struct HolographicColorSuite {
    public let coreWhite: Color
    public let hotAmber: Color
    public let deepGold: Color
    public let circuitTrace: Color
    public let outerHaze: Color
    
    public static let jarvisGold = HolographicColorSuite(
        coreWhite: Color(red: 1.0, green: 0.98, blue: 0.88),
        hotAmber: Color(red: 1.0, green: 0.72, blue: 0.10),
        deepGold: Color(red: 0.90, green: 0.45, blue: 0.04),
        circuitTrace: Color(red: 0.75, green: 0.35, blue: 0.02),
        outerHaze: Color(red: 0.95, green: 0.40, blue: 0.0).opacity(0.20)
    )
    
    public static let ultronCyan = HolographicColorSuite(
        coreWhite: Color(red: 0.96, green: 1.0, blue: 1.0),
        hotAmber: Color(red: 0.05, green: 0.90, blue: 1.0),
        deepGold: Color(red: 0.02, green: 0.50, blue: 0.98),
        circuitTrace: Color(red: 0.08, green: 0.30, blue: 0.85),
        outerHaze: Color(red: 0.0, green: 0.50, blue: 1.0).opacity(0.22)
    )
    
    public static let ultronCrimson = HolographicColorSuite(
        coreWhite: Color(red: 1.0, green: 0.94, blue: 0.80),
        hotAmber: Color(red: 1.0, green: 0.22, blue: 0.05),
        deepGold: Color(red: 0.82, green: 0.04, blue: 0.04),
        circuitTrace: Color(red: 0.55, green: 0.02, blue: 0.02),
        outerHaze: Color(red: 0.75, green: 0.0, blue: 0.05).opacity(0.25)
    )
}

// =============================================================================
// MARK: - 3D VECTOR & PROJECTION ENGINE
// =============================================================================

public struct Vec3D {
    public var x: CGFloat
    public var y: CGFloat
    public var z: CGFloat
    
    public init(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    public func rotatedX(_ a: CGFloat) -> Vec3D {
        let c = cos(a), s = sin(a)
        return Vec3D(x, y * c - z * s, y * s + z * c)
    }
    
    public func rotatedY(_ a: CGFloat) -> Vec3D {
        let c = cos(a), s = sin(a)
        return Vec3D(x * c + z * s, y, -x * s + z * c)
    }
    
    public func rotatedZ(_ a: CGFloat) -> Vec3D {
        let c = cos(a), s = sin(a)
        return Vec3D(x * c - y * s, x * s + y * c, z)
    }
    
    public func project(center: CGPoint, focal: CGFloat, cameraDist: CGFloat) -> (pt: CGPoint, scale: CGFloat, depthZ: CGFloat) {
        let dist = cameraDist + z
        guard dist > 1.0 else { return (CGPoint(x: center.x + x, y: center.y + y), 1.0, z) }
        let s = focal / dist
        return (CGPoint(x: center.x + x * s, y: center.y + y * s), s, z)
    }
}

// =============================================================================
// MARK: - PROCEDURAL PRECOMPUTED GEOMETRY
// =============================================================================


private struct JarvisSpokeLine {
    let theta: CGFloat
    let phi: CGFloat
    let packetSpeed: CGFloat
    let packetPhase: CGFloat
}

private struct CircuitTraceDef {
    let baseTheta: CGFloat
    let basePhi: CGFloat
    let steps: [(dTheta: CGFloat, dPhi: CGFloat)]
}

private struct UltronAxonNode {
    let position: Vec3D
    let branchTargets: [Int]
    let isTerminal: Bool
}

private final class HologramGeometryBank {
    static let shared = HologramGeometryBank()
    
    let jarvisSpokes: [JarvisSpokeLine]
    let circuitTraces: [CircuitTraceDef]
    let ultronAxonTree: [UltronAxonNode]
    let dustParticles: [Vec3D]
    
    init() {
        // 1. JARVIS Radial Spoke Bus Lines
        var spokes: [JarvisSpokeLine] = []
        let spokeCount = 18
        for i in 0..<spokeCount {
            let t = (CGFloat(i) / CGFloat(spokeCount)) * 2.0 * .pi
            let p = CGFloat.pi * 0.5 + CGFloat(sin(Double(i) * 2.4)) * 0.45
            spokes.append(JarvisSpokeLine(
                theta: t,
                phi: p,
                packetSpeed: 0.8 + CGFloat((i % 4)) * 0.3,
                packetPhase: CGFloat(i) * 0.47
            ))
        }
        self.jarvisSpokes = spokes
        
        // 2. JARVIS 90-Degree Orthogonal Circuit Pathways
        var traces: [CircuitTraceDef] = []
        for i in 0..<28 {
            let bt = CGFloat(i) * (2.0 * .pi / 28.0)
            let bp = CGFloat.pi * 0.25 + CGFloat((i % 6)) * 0.18
            let steps: [(CGFloat, CGFloat)] = [
                (0.08, 0.0),
                (0.08, 0.12),
                (0.20, 0.12),
                (0.20, -0.06),
                (0.32, -0.06)
            ]
            traces.append(CircuitTraceDef(baseTheta: bt, basePhi: bp, steps: steps))
        }
        self.circuitTraces = traces
        
        // 3. ULTRON 3D Synaptic Brain Axon Tree
        var nodes: [UltronAxonNode] = []
        nodes.append(UltronAxonNode(position: Vec3D(0, 0, 0), branchTargets: [1, 2, 3, 4, 5, 6], isTerminal: false))
        
        let primaryCount = 6
        for p in 0..<primaryCount {
            let pAngle = (CGFloat(p) / CGFloat(primaryCount)) * 2.0 * .pi
            let primaryPos = Vec3D(cos(pAngle) * 0.42, sin(pAngle) * 0.38, CGFloat(sin(Double(p))) * 0.25)
            let pIdx = nodes.count
            
            // Secondary branches
            var secIndices: [Int] = []
            for s in 0..<3 {
                let sTheta = pAngle + CGFloat(s - 1) * 0.42
                let sPhi = CGFloat(s) * 0.35 - 0.3
                let secPos = Vec3D(
                    primaryPos.x + cos(sTheta) * 0.35,
                    primaryPos.y + sin(sTheta) * 0.35,
                    primaryPos.z + sin(sPhi) * 0.30
                )
                let sIdx = pIdx + 1 + s
                secIndices.append(sIdx)
                nodes.append(UltronAxonNode(position: secPos, branchTargets: [], isTerminal: true))
            }
            nodes.insert(UltronAxonNode(position: primaryPos, branchTargets: secIndices, isTerminal: false), at: pIdx)
        }
        self.ultronAxonTree = nodes
        
        // 4. Volumetric Holographic Dust
        var dust: [Vec3D] = []
        for d in 0..<64 {
            let u = Double(d) / 64.0
            let th = u * 2.0 * .pi * 5.0
            let ph = acos(1.0 - 2.0 * u)
            let r = 0.3 + 0.7 * CGFloat((d % 7)) / 7.0
            dust.append(Vec3D(r * sin(ph) * cos(th), r * sin(ph) * sin(th), r * cos(ph)))
        }
        self.dustParticles = dust
    }
}

// =============================================================================
// MARK: - MAIN COMPONENT
// =============================================================================

public struct GeminiApp_HologramView: View {
    public var skin: HologramSkin
    public var isSpeaking: Bool
    public var isPlayingMusic: Bool
    public var size: CGFloat
    public var themeColor: Color?
    public var audioLevel: CGFloat
    public var audioBass: CGFloat
    public var customWidth: CGFloat?
    
    public init(
        skin: HologramSkin = .jarvis,
        isSpeaking: Bool = true,
        isPlayingMusic: Bool = false,
        size: CGFloat = 460,
        customWidth: CGFloat? = nil,
        themeColor: Color? = nil,
        audioLevel: CGFloat = 0.65,
        audioBass: CGFloat = 0.50
    ) {
        self.skin = skin
        self.isSpeaking = isSpeaking
        self.isPlayingMusic = isPlayingMusic
        self.size = size
        self.customWidth = customWidth
        self.themeColor = themeColor
        self.audioLevel = min(max(audioLevel, 0.0), 1.0)
        self.audioBass = min(max(audioBass, 0.0), 1.0)
    }
    
    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 120.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            
            Canvas(rendersAsynchronously: true) { context, canvasSize in
                let center = CGPoint(x: canvasSize.width * 0.5, y: canvasSize.height * 0.5)
                let baseRadius = min(canvasSize.width, canvasSize.height) * 0.28
                
                switch skin {
                case .jarvis:
                    renderJarvisReplica(context: &context, center: center, radius: baseRadius, time: elapsed)
                case .ultron:
                    renderUltronReplica(context: &context, center: center, radius: baseRadius, time: elapsed)
                }
            }
            .frame(width: customWidth ?? size, height: size)
        }
    }
    
    private var resolvedPalette: HolographicColorSuite {
        if let custom = themeColor {
            return HolographicColorSuite(
                coreWhite: .white,
                hotAmber: custom,
                deepGold: custom.opacity(0.7),
                circuitTrace: custom.opacity(0.4),
                outerHaze: custom.opacity(0.2)
            )
        }
        return skin == .jarvis ? .jarvisGold : .ultronCyan
    }

    // =========================================================================
    // MARK: - JARVIS RENDERING PIPELINE
    // =========================================================================

    private func renderJarvisReplica(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval
    ) {
        let lifecycle = HologramLifecycleState(time: time)
        guard lifecycle.power > 0.01 else { return }

        let palette = resolvedPalette
        let focal = radius * 3.4
        let camDist = radius * 3.2
        
        let speechPulse = isSpeaking ? (audioLevel * 0.18 + sin(time * 6.0) * 0.02) : 0.0
        let r = radius * (1.0 + speechPulse)
        
        context.blendMode = HologramManager.shared.currentBlendMode.graphicsBlendMode
        
        // 1. Atmospheric Volumetric Glow
        drawVolumetricHaze(context: &context, center: center, radius: r * 1.25 * lifecycle.power, color: palette.outerHaze)
        
        // 2. Radiating Structural Bus Lines with Flowing Data Packets
        drawJarvisBusSpokes(context: &context, center: center, radius: r, time: time, palette: palette, focal: focal, camDist: camDist, lifecycle: lifecycle)
        
        // 3. Nested Concentric Spherical Tracks & Azimuth Calibration Ticks
        drawJarvisTrackBands(context: &context, center: center, radius: r, time: time, palette: palette, focal: focal, camDist: camDist, lifecycle: lifecycle)
        
        // 4. Stepped 90° Orthogonal Circuit Traces & Active Solder Nodes
        drawJarvisCircuitTraces(context: &context, center: center, radius: r, time: time, palette: palette, focal: focal, camDist: camDist, lifecycle: lifecycle)
        
        // 5. Outer Segmented Curved Armor Plates
        drawJarvisSegmentedShell(context: &context, center: center, radius: r, time: time, palette: palette, focal: focal, camDist: camDist, lifecycle: lifecycle)
        
        // 6. Central Torus Core Aperture
        drawJarvisCoreAperture(context: &context, center: center, radius: r * 0.22, time: time, palette: palette, lifecycle: lifecycle)
        
        // 7. Ambient Orbiting Micro-Dust
        if lifecycle.power > 0.2 {
            drawAmbientDust(context: &context, center: center, radius: r, time: time, color: palette.hotAmber, focal: focal, camDist: camDist)
        }
    }

    private func drawJarvisBusSpokes(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval,
        palette: HolographicColorSuite,
        focal: CGFloat,
        camDist: CGFloat,
        lifecycle: HologramLifecycleState
    ) {
        let deploy = lifecycle.ringProgress(index: 2, total: 4)
        guard deploy > 0.02 else { return }
        let spokes = HologramGeometryBank.shared.jarvisSpokes
        let rotY = CGFloat(time * 0.22) * lifecycle.spinVelocityMultiplier
        let rotX = CGFloat(sin(time * 0.12) * 0.18 + 0.22)
        
        for sp in spokes {
            let startV = Vec3D(
                radius * 0.22 * sin(sp.phi) * cos(sp.theta),
                radius * 0.22 * cos(sp.phi),
                radius * 0.22 * sin(sp.phi) * sin(sp.theta)
            ).rotatedY(rotY).rotatedX(rotX)
            
            let endV = Vec3D(
                radius * 0.95 * deploy * sin(sp.phi) * cos(sp.theta),
                radius * 0.95 * deploy * cos(sp.phi),
                radius * 0.95 * deploy * sin(sp.phi) * sin(sp.theta)
            ).rotatedY(rotY).rotatedX(rotX)
            
            let pStart = startV.project(center: center, focal: focal, cameraDist: camDist)
            let pEnd = endV.project(center: center, focal: focal, cameraDist: camDist)
            
            var line = Path()
            line.move(to: pStart.pt)
            line.addLine(to: pEnd.pt)
            
            let alpha = (0.35 + Double(audioLevel * 0.4)) * Double(deploy)
            context.stroke(line, with: .color(palette.deepGold.opacity(alpha)), style: StrokeStyle(lineWidth: 1.0, dash: [4, 6]))
            
            // Flowing Data Packet Bead along Spoke
            let packetT = CGFloat((time * Double(sp.packetSpeed) + Double(sp.packetPhase)).truncatingRemainder(dividingBy: 1.0))
            let packetPos = CGPoint(
                x: pStart.pt.x + (pEnd.pt.x - pStart.pt.x) * packetT,
                y: pStart.pt.y + (pEnd.pt.y - pStart.pt.y) * packetT
            )
            let pSize: CGFloat = 2.4 * (1.0 + audioLevel * 0.6) * deploy
            let dotRect = CGRect(x: packetPos.x - pSize * 0.5, y: packetPos.y - pSize * 0.5, width: pSize, height: pSize)
            context.fill(Path(ellipseIn: dotRect), with: .color(palette.coreWhite))
        }
    }

    private func drawJarvisTrackBands(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval,
        palette: HolographicColorSuite,
        focal: CGFloat,
        camDist: CGFloat,
        lifecycle: HologramLifecycleState
    ) {
        let rings: [(rRatio: CGFloat, incX: CGFloat, incY: CGFloat, speed: CGFloat, dash: [CGFloat], width: CGFloat)] = [
            (0.96, 0.42, 0.15, 0.18, [24, 8, 8, 8], 1.5),
            (0.82, -0.35, 0.25, -0.24, [16, 12], 1.2),
            (0.68, 0.12, -0.45, 0.32, [40, 6], 1.8),
            (0.52, -0.55, -0.15, -0.42, [6, 6], 1.0),
            (0.38, 0.65, 0.35, 0.55, [], 1.4)
        ]
        
        for (idx, ring) in rings.enumerated() {
            let deploy = lifecycle.ringProgress(index: idx, total: rings.count)
            guard deploy > 0.02 else { continue }
            
            let segCount = 64
            var pts: [CGPoint] = []
            pts.reserveCapacity(segCount + 1)
            let currentRot = CGFloat(time) * ring.speed * lifecycle.spinVelocityMultiplier
            let curR = radius * ring.rRatio * deploy
            
            for i in 0...segCount {
                let th = (CGFloat(i) / CGFloat(segCount)) * 2.0 * .pi
                var v = Vec3D(curR * cos(th), curR * sin(th), 0)
                v = v.rotatedZ(currentRot)
                v = v.rotatedX(ring.incX)
                v = v.rotatedY(ring.incY)
                let proj = v.project(center: center, focal: focal, cameraDist: camDist)
                pts.append(proj.pt)
            }
            
            var p = Path()
            for (idx, pt) in pts.enumerated() {
                if idx == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
            
            context.stroke(
                p,
                with: .color(palette.hotAmber.opacity(0.7 * Double(deploy))),
                style: StrokeStyle(lineWidth: ring.width, dash: ring.dash)
            )
        }
    }

    private func drawJarvisCircuitTraces(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval,
        palette: HolographicColorSuite,
        focal: CGFloat,
        camDist: CGFloat,
        lifecycle: HologramLifecycleState
    ) {
        let deploy = lifecycle.ringProgress(index: 3, total: 5)
        guard deploy > 0.02 else { return }
        let traces = HologramGeometryBank.shared.circuitTraces
        let rotY = CGFloat(time * 0.16) * lifecycle.spinVelocityMultiplier
        let rotX = CGFloat(0.28)
        let curR = radius * 0.88 * deploy
        
        for tr in traces {
            var currTheta = tr.baseTheta
            var currPhi = tr.basePhi
            var path = Path()
            
            let v0 = Vec3D(
                curR * sin(currPhi) * cos(currTheta),
                curR * cos(currPhi),
                curR * sin(currPhi) * sin(currTheta)
            ).rotatedY(rotY).rotatedX(rotX)
            let p0 = v0.project(center: center, focal: focal, cameraDist: camDist)
            path.move(to: p0.pt)
            
            for step in tr.steps {
                currTheta += step.dTheta
                let vH = Vec3D(
                    curR * sin(currPhi) * cos(currTheta),
                    curR * cos(currPhi),
                    curR * sin(currPhi) * sin(currTheta)
                ).rotatedY(rotY).rotatedX(rotX)
                let pH = vH.project(center: center, focal: focal, cameraDist: camDist)
                path.addLine(to: pH.pt)
                
                currPhi += step.dPhi
                let vV = Vec3D(
                    curR * sin(currPhi) * cos(currTheta),
                    curR * cos(currPhi),
                    curR * sin(currPhi) * sin(currTheta)
                ).rotatedY(rotY).rotatedX(rotX)
                let pV = vV.project(center: center, focal: focal, cameraDist: camDist)
                path.addLine(to: pV.pt)
                
                // Active Solder Node Dot at corner
                if audioLevel > 0.4 && deploy > 0.5 {
                    let dotRect = CGRect(x: pV.pt.x - 1.2, y: pV.pt.y - 1.2, width: 2.4, height: 2.4)
                    context.fill(Path(ellipseIn: dotRect), with: .color(palette.coreWhite))
                }
            }
            
            context.stroke(path, with: .color(palette.circuitTrace.opacity(0.65 * Double(deploy))), style: StrokeStyle(lineWidth: 1.1))
        }
    }

    private func drawJarvisSegmentedShell(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval,
        palette: HolographicColorSuite,
        focal: CGFloat,
        camDist: CGFloat,
        lifecycle: HologramLifecycleState
    ) {
        let deploy = lifecycle.ringProgress(index: 3, total: 4)
        guard deploy > 0.02 else { return }
        let plateCount = 6
        let arcSpan = (2.0 * CGFloat.pi) / CGFloat(plateCount)
        let rotY = -CGFloat(time * 0.08) * lifecycle.spinVelocityMultiplier
        let curR = radius * 0.98 * deploy
        
        for p in 0..<plateCount {
            let startTh = CGFloat(p) * arcSpan + rotY
            let endTh = startTh + arcSpan * 0.65
            let phi: CGFloat = .pi * 0.5
            
            var platePath = Path()
            let subSegments = 16
            for s in 0...subSegments {
                let t = startTh + (endTh - startTh) * (CGFloat(s) / CGFloat(subSegments))
                let v = Vec3D(
                    curR * sin(phi) * cos(t),
                    curR * cos(phi) + CGFloat(sin(Double(s) * 0.4)) * 8.0,
                    curR * sin(phi) * sin(t)
                ).rotatedY(rotY).rotatedX(0.20)
                let proj = v.project(center: center, focal: focal, cameraDist: camDist)
                if s == 0 { platePath.move(to: proj.pt) } else { platePath.addLine(to: proj.pt) }
            }
            
            context.stroke(
                platePath,
                with: .color(palette.hotAmber.opacity(0.85 * Double(deploy))),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .butt)
            )
        }
    }

    private func drawJarvisCoreAperture(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval,
        palette: HolographicColorSuite,
        lifecycle: HologramLifecycleState
    ) {
        let burst = 1.0 + lifecycle.coreBurst
        let pulse = radius * (1.0 + audioLevel * 0.35 + sin(time * 5.0) * 0.05) * burst
        let coreGrad = Gradient(stops: [
            .init(color: palette.coreWhite.opacity(min(1.0, 1.0 + Double(lifecycle.coreBurst) * 0.5)), location: 0.0),
            .init(color: palette.hotAmber, location: 0.4),
            .init(color: palette.deepGold.opacity(0.3), location: 0.85),
            .init(color: .clear, location: 1.0)
        ])
        
        let rect = CGRect(x: center.x - pulse, y: center.y - pulse, width: pulse * 2, height: pulse * 2)
        context.fill(Path(ellipseIn: rect), with: .radialGradient(coreGrad, center: center, startRadius: 0, endRadius: pulse))
        
        // Inner Aperture Rings
        let innerR = pulse * 0.45
        let ringRect = CGRect(x: center.x - innerR, y: center.y - innerR, width: innerR * 2, height: innerR * 2)
        context.stroke(Path(ellipseIn: ringRect), with: .color(palette.coreWhite.opacity(0.9)), style: StrokeStyle(lineWidth: 1.6))
    }

    // =========================================================================
    // MARK: - ULTRON RENDERING PIPELINE
    // =========================================================================

    private func renderUltronReplica(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval
    ) {
        let lifecycle = HologramLifecycleState(time: time)
        guard lifecycle.power > 0.01 else { return }

        let palette = resolvedPalette
        let focal = radius * 3.2
        let camDist = radius * 3.0
        
        // Organic undulating breathing pulse
        let breath = sin(time * 2.0) * 0.04 + cos(time * 3.7) * 0.02
        let speechScale = isSpeaking ? (1.0 + audioLevel * 0.32 + breath) : (1.0 + breath)
        let r = radius * speechScale
        
        context.blendMode = HologramManager.shared.currentBlendMode.graphicsBlendMode
        
        // 1. Deep Atmospheric Synaptic Fog
        drawVolumetricHaze(context: &context, center: center, radius: r * 1.35 * lifecycle.power, color: palette.outerHaze)
        
        // 2. 3D Branching Dendrite Axon Tree with Action Potentials (Living growth and retraction!)
        drawUltronDendriteTree(context: &context, center: center, radius: r, time: time, palette: palette, focal: focal, camDist: camDist, lifecycle: lifecycle)
        
        // 3. Chaotic Tesla-Coil Lightning Arcs
        if (audioBass > 0.15 || isSpeaking) && lifecycle.power > 0.30 {
            drawTeslaDischarges(context: &context, center: center, radius: r, time: time, palette: palette, lifecycle: lifecycle)
        }
        
        // 4. White-Hot Singular Energy Core
        drawUltronSynapticCore(context: &context, center: center, radius: r * 0.28, time: time, palette: palette, lifecycle: lifecycle)
        
        // 5. Synaptic Dust Cloud
        if lifecycle.power > 0.2 {
            drawAmbientDust(context: &context, center: center, radius: r * 1.15, time: time, color: palette.hotAmber, focal: focal, camDist: camDist)
        }
    }

    private func drawUltronDendriteTree(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval,
        palette: HolographicColorSuite,
        focal: CGFloat,
        camDist: CGFloat,
        lifecycle: HologramLifecycleState
    ) {
        let tree = HologramGeometryBank.shared.ultronAxonTree
        let rotY = CGFloat(time * 0.30) * lifecycle.spinVelocityMultiplier
        let rotX = CGFloat(0.24 + sin(time * 0.2) * 0.12)
        
        // Project all nodes with physical growth displacement from center
        var projected: [(pt: CGPoint, depthZ: CGFloat, growth: CGFloat)] = []
        projected.reserveCapacity(tree.count)
        
        for node in tree {
            let dist = sqrt(node.position.x * node.position.x + node.position.y * node.position.y + node.position.z * node.position.z)
            let growth = lifecycle.axonGrowth(normalizedDist: dist)
            let effectiveDist = radius * growth
            
            let world = Vec3D(
                node.position.x * effectiveDist,
                node.position.y * effectiveDist,
                node.position.z * effectiveDist
            ).rotatedY(rotY).rotatedX(rotX)
            
            let p = world.project(center: center, focal: focal, cameraDist: camDist)
            projected.append((p.pt, p.depthZ, growth))
        }
        
        // Render Axons (Curved Bezier Connections)
        for (idx, node) in tree.enumerated() {
            let p1 = projected[idx]
            guard p1.growth > 0.04 else { continue }
            
            for targetIdx in node.branchTargets {
                guard targetIdx < projected.count else { continue }
                let p2 = projected[targetIdx]
                guard p2.growth > 0.04 else { continue }
                
                var axonPath = Path()
                axonPath.move(to: p1.pt)
                
                let midX = (p1.pt.x + p2.pt.x) * 0.5 + CGFloat(sin(Double(idx + targetIdx) + time * 4.0)) * 6.0
                let midY = (p1.pt.y + p2.pt.y) * 0.5 + CGFloat(cos(Double(idx * targetIdx) + time * 4.0)) * 6.0
                axonPath.addQuadCurve(to: p2.pt, control: CGPoint(x: midX, y: midY))
                
                let minGrowth = min(p1.growth, p2.growth)
                let alpha = (0.45 + Double(audioLevel * 0.4)) * Double(minGrowth)
                context.stroke(axonPath, with: .color(palette.hotAmber.opacity(alpha)), style: StrokeStyle(lineWidth: 1.4 * minGrowth))
                
                // Action Potential Pulse Bead racing down the growing axon!
                let pulseT = CGFloat((time * 2.2 + Double(idx)).truncatingRemainder(dividingBy: 1.0))
                let bX = p1.pt.x + (p2.pt.x - p1.pt.x) * pulseT
                let bY = p1.pt.y + (p2.pt.y - p1.pt.y) * pulseT
                let bSize: CGFloat = 3.2 * minGrowth
                let bRect = CGRect(x: bX - bSize * 0.5, y: bY - bSize * 0.5, width: bSize, height: bSize)
                context.fill(Path(ellipseIn: bRect), with: .color(palette.coreWhite.opacity(Double(minGrowth))))
            }
            
            // Terminal Synapse Node
            if p1.growth > 0.20 {
                let nSize: CGFloat = (node.isTerminal ? 4.0 : 2.5) * (1.0 + audioLevel * 0.5) * p1.growth
                let nRect = CGRect(x: p1.pt.x - nSize * 0.5, y: p1.pt.y - nSize * 0.5, width: nSize, height: nSize)
                context.fill(Path(ellipseIn: nRect), with: .color(palette.coreWhite.opacity(Double(p1.growth))))
            }
        }
    }

    private func drawTeslaDischarges(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval,
        palette: HolographicColorSuite,
        lifecycle: HologramLifecycleState
    ) {
        let boltCount = Int(4 + audioBass * 6)
        
        for b in 0..<boltCount {
            let seed = Double(b) * 73.12 + time * 18.0
            let angle = (CGFloat(b) / CGFloat(boltCount)) * 2.0 * .pi + CGFloat(sin(seed))
            var curr = center
            var bolt = Path()
            bolt.move(to: curr)
            
            let segments = 8
            let reach = radius * (0.75 + audioBass * 0.4) * lifecycle.power
            let segLen = reach / CGFloat(segments)
            
            for s in 1...segments {
                let jitter = angle + CGFloat(sin(seed + Double(s * 7))) * 0.65
                let rStep = CGFloat(s) * segLen
                let next = CGPoint(
                    x: center.x + rStep * cos(jitter) + CGFloat(cos(seed * Double(s))) * 10.0,
                    y: center.y + rStep * sin(jitter) + CGFloat(sin(seed * Double(s))) * 10.0
                )
                bolt.addLine(to: next)
                curr = next
            }
            
            let alpha = Double(0.6 + audioBass * 0.4) * Double(lifecycle.power)
            context.stroke(bolt, with: .color(palette.coreWhite.opacity(alpha)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .bevel))
            context.stroke(bolt, with: .color(palette.hotAmber.opacity(alpha * 0.7)), style: StrokeStyle(lineWidth: 4.0, lineCap: .round, lineJoin: .bevel))
        }
    }

    private func drawUltronSynapticCore(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval,
        palette: HolographicColorSuite,
        lifecycle: HologramLifecycleState
    ) {
        let burst = 1.0 + lifecycle.coreBurst
        let pulse = radius * (1.0 + audioLevel * 0.45 + sin(time * 7.0) * 0.08) * burst
        let coreGrad = Gradient(stops: [
            .init(color: palette.coreWhite.opacity(min(1.0, 1.0 + Double(lifecycle.coreBurst) * 0.5)), location: 0.0),
            .init(color: palette.hotAmber, location: 0.35),
            .init(color: palette.deepGold.opacity(0.35), location: 0.75),
            .init(color: .clear, location: 1.0)
        ])
        
        let rect = CGRect(x: center.x - pulse, y: center.y - pulse, width: pulse * 2, height: pulse * 2)
        context.fill(Path(ellipseIn: rect), with: .radialGradient(coreGrad, center: center, startRadius: 0, endRadius: pulse))
    }

    // =========================================================================
    // MARK: - SHARED VOLUMETRIC HELPERS
    // =========================================================================

    private func drawVolumetricHaze(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        color: Color
    ) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        let grad = Gradient(stops: [
            .init(color: color, location: 0.0),
            .init(color: color.opacity(0.4), location: 0.5),
            .init(color: .clear, location: 1.0)
        ])
        context.fill(Path(ellipseIn: rect), with: .radialGradient(grad, center: center, startRadius: 0, endRadius: radius))
    }

    private func drawAmbientDust(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval,
        color: Color,
        focal: CGFloat,
        camDist: CGFloat
    ) {
        let dust = HologramGeometryBank.shared.dustParticles
        let rotY = CGFloat(time * 0.14)
        
        for d in dust {
            let world = Vec3D(d.x * radius, d.y * radius, d.z * radius).rotatedY(rotY)
            let p = world.project(center: center, focal: focal, cameraDist: camDist)
            let dSize: CGFloat = 1.6
            let r = CGRect(x: p.pt.x - dSize * 0.5, y: p.pt.y - dSize * 0.5, width: dSize, height: dSize)
            context.fill(Path(ellipseIn: r), with: .color(color.opacity(0.65)))
        }
    }
}

// =============================================================================
// MARK: - PREVIEW TEST BENCH
// =============================================================================

