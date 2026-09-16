//
//  UltronHologramView.swift
//  Agent Speak — ULTRON "Neural Core" skin
//
//  NOT a red JARVIS. Different grammar: fractured, asymmetric, predatory, unstable.
//
//  Layer stack (back → front):
//   0. Crimson atmospheric volume (breathes with bass + idle heartbeat)
//   1. Broken orbital rings   — arcs with missing chunks, wobbled by noise + bass
//   2. Telemetry tick ring    — irregular, incomplete, dim
//   3. Neural lattice         — left-weighted node network; energy packets travel edges
//   4. Filaments              — jagged branching threads that flicker and dead-end
//   5. Audio spikes           — jagged saw-tooth lashes in two tiers (NEVER smooth rings)
//   6. Electrical arcs        — rare jagged lightning: deep red → red → orange → white core
//   7. Core                   — hexagonal optic iris, radial blades, white-hot nucleus
//   8. Fragments              — shards/brackets drifting, flickering, appearing/disappearing
//   9. Shockwave              — expanding ring on strong peaks ("electrical thought pulse")
//  10. Glitch pass            — rare dropout/scanline instability (cinematic, not CRT noise)
//
//  Audio mapping:  audioLevel → spike length/brightness, lattice activity, arc probability,
//                              iris contraction, filament speed.
//                  audioBass  → structural wobble, lattice flash, atmosphere pulse, arc triggers.
//                  Idle       → eerie heartbeat respiration; never fully still.
//

import SwiftUI
import Foundation

// MARK: - Public drop-in view

struct GLM_UltronView: View {
    var isSpeaking: Bool = false
    var isPlayingMusic: Bool = false
    var size: CGFloat = 420
    var customWidth: CGFloat? = nil
    var themeColor: Color = Color(red: 1.00, green: 0.16, blue: 0.12) // blood crimson
    var audioLevel: CGFloat = 0
    var audioBass: CGFloat = 0

    @State private var engine = UltronEngine()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 120.0)) { timeline in
            Canvas { ctx, cs in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let lifecycle = HologramLifecycleState(time: time)
                guard lifecycle.power > 0.01 else { return }
                engine.render(&ctx, canvasSize: cs,
                              time: time,
                              speaking: isSpeaking, music: isPlayingMusic,
                              size: size, color: themeColor,
                              level: Double(audioLevel), bass: Double(audioBass),
                              lifecycle: lifecycle)
            }
        }
        .frame(width: customWidth ?? size, height: size)
    }
}

// MARK: - Math kit (file-private)

private struct V3 { var x = 0.0, y = 0.0, z = 0.0 }
private extension V3 {
    func rotX(_ a: Double) -> V3 { V3(x: x, y: y*cos(a) - z*sin(a), z: y*sin(a) + z*cos(a)) }
    func rotY(_ a: Double) -> V3 { V3(x: x*cos(a) + z*sin(a), y: y, z: z*cos(a) - x*sin(a)) }
}
private let UTAU = Double.pi * 2
private let UORANGE = Color(red: 1.0, green: 0.45, blue: 0.10)   // "high energy" accent
@inline(__always) private func ufr(_ v: Double) -> Double { v - v.rounded(.down) }
@inline(__always) private func uh1(_ n: Double) -> Double { ufr(sin(n * 127.1) * 43758.5453) }
@inline(__always) private func uh2(_ a: Double, _ b: Double) -> Double { ufr(sin(a * 127.1 + b * 311.7) * 43758.5453) }
@inline(__always) private func cg(_ v: Double) -> CGFloat { CGFloat(v) }

private struct UPen {
    var g: GraphicsContext
    var c: CGPoint, cx: Double, cy: Double
    var R: Double, t: Double, lvl: Double, bass: Double
    var speak: Bool, music: Bool
    var color: Color
    var detail: Double
    var peak: Double       // decaying peak envelope (0...1)
    var glitch: Bool
    var twitch: Double
    var lifecycle: HologramLifecycleState
    var pj: (V3) -> (CGPoint, Double)
}

private struct UArc { var t0: Double, seed: Double }

// MARK: - Engine

private final class UltronEngine {

    private var sLvl = 0.0, sBass = 0.0, lastT = 0.0
    private var peakT = -10.0, twitch = 0.0
    private var arcs: [UArc] = [], nextArc = -1.0, glitchUntil = 0.0

    private var rings: [(r: Double, speed: Double, arcs: [(a: Double, len: Double)], seed: Double)] = []
    private var tickRing: [(a: Double, len: Double)] = []
    private var nodes: [(p: V3, cls: Double, ph: Double, act: Double)] = []
    private var edges: [(Int, Int)] = []
    private var filaments: [(lat: Double, lon: Double, legs: [(dLat: Double, dLon: Double)], speed: Double, off: Double, seed: Double)] = []
    private var fragments: [(p: V3, kind: Int, s: Double, seed: Double, spin: Double)] = []

    init() { build() }

    private func build() {
        let radii = [0.86, 0.66, 0.47], speeds = [0.11, -0.16, 0.24]
        for (i, r) in radii.enumerated() {
            var arcs: [(Double, Double)] = []
            var a = uh1(Double(i) * 3.3) * UTAU
            let end = a + UTAU
            while a < end {                                   // broken arcs, unequal, misaligned
                let r1 = uh2(Double(i) * 7.7, a), len = 0.18 + 0.85 * r1 * r1
                arcs.append((a, len))
                a += len + 0.10 + 0.55 * uh2(Double(i) * 2.9, a * 3.0)
            }
            rings.append((r, speeds[i], arcs, Double(i)))
        }
        var a = 0.0                                           // irregular telemetry ticks, missing regions
        while a < UTAU {
            let r1 = uh1(a * 3.1)
            if r1 > 0.35 { tickRing.append((a, r1 > 0.9 ? 0.05 : 0.018)) }
            a += 0.045 + 0.16 * uh1(a * 7.7)
        }
        var guardN = 0                                        // lattice nodes — deliberately left-weighted
        while nodes.count < 26 && guardN < 300 {
            guardN += 1
            let x = (uh1(Double(guardN) * 5.1) - 0.64) * 1.5
            let y = (uh1(Double(guardN) * 9.7 + 2.0) - 0.5) * 1.4
            let z = (uh1(Double(guardN) * 3.7 + 5.0) - 0.5) * 0.9
            if (x*x + y*y + z*z) > 0.90 { continue }
            nodes.append((V3(x: x, y: y, z: z), uh1(Double(guardN) * 1.9),
                          uh1(Double(guardN) * 8.3), 0.12 + 0.3 * uh1(Double(guardN) * 4.4)))
        }
        for i in 0..<nodes.count {                            // near-node edges, max 3 per node
            var links = 0
            for j in (i + 1)..<nodes.count where links < 3 && edges.count < 46 {
                let d = nodes[i].p, e = nodes[j].p
                let dx = d.x - e.x, dy = d.y - e.y, dz = d.z - e.z
                if (dx*dx + dy*dy + dz*dz) < 0.18 && uh2(Double(i), Double(j)) > 0.25 {
                    edges.append((i, j)); links += 1
                }
            }
        }
        for f in 0..<9 {                                      // jagged filaments
            var legs: [(Double, Double)] = []
            for l in 0..<4 {
                let r = uh2(Double(f) * 3.7, Double(l) * 7.1)
                legs.append(l % 2 == 0 ? (0, (r - 0.5) * 1.8) : ((r - 0.5) * 1.2, 0))
            }
            filaments.append(((uh1(Double(f) * 8.8) - 0.5) * 2.4, uh1(Double(f) * 5.5) * UTAU,
                              legs, 0.08 + 0.16 * uh1(Double(f) * 2.4), uh1(Double(f) * 9.9), Double(f)))
        }
        for f in 0..<16 {                                     // debris fragments
            fragments.append((V3(x: (uh1(Double(f) * 7.3) - 0.55) * 1.7, y: (uh1(Double(f) * 3.1 + 1) - 0.5) * 1.6,
                                 z: (uh1(Double(f) * 9.9 + 4) - 0.5) * 1.0),
                              Int(uh1(Double(f) * 2.2) * 3) % 3, 0.02 + 0.05 * uh1(Double(f) * 6.6),
                              Double(f), (uh1(Double(f) * 1.3) - 0.5) * 0.6))
        }
    }

    // MARK: frame

    func render(_ g: inout GraphicsContext, canvasSize: CGSize, time: Double,
                speaking: Bool, music: Bool, size: CGFloat, color: Color,
                level: Double, bass: Double, lifecycle: HologramLifecycleState) {
        let dt = lastT == 0 ? (1.0 / 120.0) : min(0.1, max(0.0005, time - lastT))
        lastT = time
        let t = time - 1_704_000_000
        approach(&sLvl, level, atk: 28, rel: 5.0, dt: dt)
        approach(&sBass, bass, atk: 30, rel: 6.0, dt: dt)

        // strong-peak detection → iris snap + twitch + shockwave
        if sLvl > 0.55 && (t - peakT) > 0.30 {
            peakT = t
            twitch = (uh1((t * 57).rounded(.down)) - 0.5) * 0.5
        }
        twitch *= exp(-6 * dt)
        let peak = t > peakT ? exp(-(t - peakT) * 5.5) : 0

        // electrical arc scheduler — rare, special
        if t > nextArc && lifecycle.power > 0.20 {
            let chance = (speaking ? 0.70 : (music ? 0.30 : 0.15)) + sBass * 0.5 + peak * 0.4
            if uh1((t * 13.7).rounded(.down)) < chance && arcs.count < 3 {
                arcs.append(UArc(t0: t, seed: ufr(t * 31.7) * 97.0))
            }
            nextArc = t + 0.40 + 1.1 * uh1(ufr(t) * 91.3)
        }
        arcs.removeAll { t - $0.t0 > 0.22 }

        if t > glitchUntil && uh1((t * 17.0).rounded(.down)) < 0.02 + 0.05 * sBass { glitchUntil = t + 0.06 }

        let c = CGPoint(x: canvasSize.width * 0.5, y: canvasSize.height * 0.5)
        let R = Double(min(canvasSize.width, canvasSize.height)) * 0.30
        let detail = min(1.0, max(0.35, Double(size) / 420.0))
        let tilt = 0.10 + 0.03 * sin(t * 0.21) + twitch * 0.1
        let spin = t * 0.06 * Double(lifecycle.spinVelocityMultiplier)
        func pj(_ v: V3) -> (CGPoint, Double) {
            let dist = sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
            let growth = Double(lifecycle.axonGrowth(normalizedDist: CGFloat(dist)))
            let vScaled = V3(x: v.x * growth, y: v.y * growth, z: v.z * growth)
            let r = vScaled.rotY(spin).rotX(tilt)
            let d = 3.0 / (3.0 + r.z)
            return (CGPoint(x: c.x + cg(r.x * R * d), y: c.y + cg(r.y * R * d)), d)
        }
        let pen = UPen(g: g, c: c, cx: Double(c.x), cy: Double(c.y), R: R, t: t,
                       lvl: sLvl, bass: sBass, speak: speaking, music: music,
                       color: color, detail: detail, peak: peak, glitch: t < glitchUntil,
                       twitch: twitch, lifecycle: lifecycle, pj: pj)

        drawAtmosphere(pen)
        drawBrokenRings(pen)
        drawLattice(pen)
        if detail > 0.5 { drawFilaments(pen) }
        drawSpikes(pen)
        drawArcs(pen)
        drawCore(pen)
        drawFragments(pen)
        drawShockwave(pen)
        if pen.glitch { drawGlitch(pen) }
    }

    private func approach(_ v: inout Double, _ target: Double, atk: Double, rel: Double, dt: Double) {
        let r = target > v ? atk : rel
        v += (target - v) * (1 - exp(-r * dt))
    }

    private func line(_ p: UPen, _ path: Path, color: Color, alpha: Double, width: Double, glow: Bool = true) {
        guard alpha > 0.004 else { return }
        var g = p.g
        if glow {
            g.blendMode = .plusLighter
            g.stroke(path, with: .color(color.opacity(alpha * 0.10)), lineWidth: max(1, cg(width * 6)))
            g.stroke(path, with: .color(color.opacity(alpha * 0.22)), lineWidth: max(0.6, cg(width * 2.6)))
        }
        g.stroke(path, with: .color(color.opacity(alpha)), lineWidth: max(0.4, cg(width)))
    }

    private func dot(_ p: UPen, at pt: CGPoint, r: Double, color: Color, alpha: Double, halo: Bool = true) {
        guard alpha > 0.004, r > 0.3 else { return }
        var g = p.g
        g.blendMode = .plusLighter
        if halo {
            g.fill(Path(ellipseIn: CGRect(x: pt.x - cg(r*3), y: pt.y - cg(r*3), width: cg(r*6), height: cg(r*6))),
                   with: .color(color.opacity(alpha * 0.16)))
        }
        g.fill(Path(ellipseIn: CGRect(x: pt.x - cg(r), y: pt.y - cg(r), width: cg(r*2), height: cg(r*2))),
               with: .color(color.opacity(alpha)))
    }

    // MARK: Layer 0 — crimson atmosphere

    private func drawAtmosphere(_ p: UPen) {
        let hb = pow(max(0, sin(p.t * 1.35)), 8)              // idle heartbeat
        let a = (0.045 + p.bass * 0.10 + p.lvl * 0.05 + hb * 0.02) * Double(p.lifecycle.power)
        p.g.fill(Path(ellipseIn: CGRect(x: p.c.x - cg(p.R*1.2), y: p.c.y - cg(p.R*1.2), width: cg(p.R*2.4), height: cg(p.R*2.4))),
                 with: .radialGradient(Gradient(colors: [p.color.opacity(a), p.color.opacity(a * 0.3), .clear]),
                                       center: p.c, startRadius: cg(p.R * 0.1), endRadius: cg(p.R * 1.2)))
        p.g.fill(Path(ellipseIn: CGRect(x: p.c.x - cg(p.R*0.55), y: p.c.y - cg(p.R*0.55), width: cg(p.R*1.1), height: cg(p.R*1.1))),
                 with: .radialGradient(Gradient(colors: [p.color.opacity((0.08 + 0.06 * p.bass) * Double(p.lifecycle.power)), .clear]),
                                       center: p.c, startRadius: 0, endRadius: cg(p.R * 0.55)))
    }

    // MARK: Layer 1+2 — broken rings & telemetry ticks

    private func drawBrokenRings(_ p: UPen) {
        for (i, ring) in rings.enumerated() {
            if p.glitch && ring.seed == 1 { continue }         // glitch dropout
            let deploy = Double(p.lifecycle.ringProgress(index: i, total: rings.count))
            guard deploy > 0.02 else { continue }
            var path = Path()
            let spin = p.t * ring.speed * Double(p.lifecycle.spinVelocityMultiplier)
            for arc in ring.arcs {
                var penDown = false
                let steps = 10
                for s in 0...steps {
                    let a = arc.a + spin + arc.len * Double(s) / Double(steps)
                    let wob = 0.028 * sin(a * 3.0 + ring.seed * 2.0) + p.bass * 0.045 * sin(a * 5.0 + p.t * 2.0)
                    let r = p.R * (ring.r + wob) * deploy
                    let pt = CGPoint(x: p.c.x + cg(cos(a) * r), y: p.c.y + cg(sin(a) * r))
                    if penDown { path.addLine(to: pt) } else { path.move(to: pt); penDown = true }
                }
            }
            line(p, path, color: p.color, alpha: (0.16 + 0.20 * p.bass + 0.15 * p.peak) * deploy,
                 width: max(0.6, p.R * 0.0035 * deploy), glow: false)
        }
        let tkDeploy = Double(p.lifecycle.ringProgress(index: 2, total: 3))
        if tkDeploy > 0.05 {
            var ticks = Path()
            for tk in tickRing {
                let a = tk.a + p.t * 0.05
                let r0 = p.R * 0.93 * tkDeploy, r1 = p.R * (0.93 + tk.len) * tkDeploy
                ticks.move(to: CGPoint(x: p.c.x + cg(cos(a) * r0), y: p.c.y + cg(sin(a) * r0)))
                ticks.addLine(to: CGPoint(x: p.c.x + cg(cos(a) * r1), y: p.c.y + cg(sin(a) * r1)))
            }
            line(p, ticks, color: p.color, alpha: (0.10 + 0.08 * p.bass) * tkDeploy, width: 1, glow: false)
        }
    }

    // MARK: Layer 3 — neural lattice + nervous nodes (energy visibly travels)

    private func drawLattice(_ p: UPen) {
        var pts: [CGPoint] = [], dpts: [Double] = []
        for nd in nodes {
            let (pt, d) = p.pj(nd.p)
            pts.append(pt); dpts.append(min(1, max(0, (d - 0.75) / 0.75)))
        }
        var dim = Path(), lit = Path()
        for (i, j) in edges {
            let e = Double(i) * 0.37 + Double(j) * 0.61
            let cycle = ufr(p.t * 0.10 + uh1(e))
            let window = p.speak ? 0.22 + p.lvl * 0.25 : 0.10
            if cycle < window { lit.move(to: pts[i]); lit.addLine(to: pts[j]) }
            else { dim.move(to: pts[i]); dim.addLine(to: pts[j]) }
        }
        line(p, dim, color: p.color, alpha: 0.10, width: max(0.5, p.R * 0.0026), glow: false)
        line(p, lit, color: p.color, alpha: min(1, 0.34 * (1 + 2 * p.peak)), width: max(0.6, p.R * 0.0032), glow: true)
        var g = p.g
        g.blendMode = .plusLighter
        let pr = max(1.2, p.R * 0.005)
        for (i, j) in edges {                                  // orange-hot packets with white micro-cores
            let e = Double(i) * 0.37 + Double(j) * 0.61
            let cycle = ufr(p.t * 0.10 + uh1(e))
            let window = p.speak ? 0.22 + p.lvl * 0.25 : 0.10
            guard cycle < window else { continue }
            let f = cycle / window
            let px = pts[i].x + (pts[j].x - pts[i].x) * cg(f)
            let py = pts[i].y + (pts[j].y - pts[i].y) * cg(f)
            g.fill(Path(ellipseIn: CGRect(x: px - cg(pr), y: py - cg(pr), width: cg(pr*2), height: cg(pr*2))),
                   with: .color(UORANGE.opacity(0.7 * dpts[i] + 0.2)))
            g.fill(Path(ellipseIn: CGRect(x: px - cg(pr*0.5), y: py - cg(pr*0.5), width: cg(pr), height: cg(pr))),
                   with: .color(.white.opacity(0.8 * dpts[i] + 0.15)))
        }
        for (idx, nd) in nodes.enumerated() {                  // nervous activation flashes
            if p.detail < 0.6 && nd.cls < 0.3 { continue }
            let flash = pow(max(0, sin(UTAU * ufr(p.t * nd.act + nd.ph))), 14)
            let base = nd.cls < 0.75 ? 0.10 : (nd.cls < 0.93 ? 0.28 : 0.5)
            var a = (base + flash * 0.6) * (0.3 + 0.7 * dpts[idx]) * (1 + p.peak * 1.2)
            if p.speak { a += p.lvl * 0.25 * dpts[idx] }
            if p.glitch && idx % 7 == 0 {                       // glitch node doubling
                dot(p, at: CGPoint(x: pts[idx].x + 1, y: pts[idx].y), r: max(1, p.R * 0.005),
                    color: p.color, alpha: 0.3, halo: false)
            }
            dot(p, at: pts[idx], r: max(1.0, p.R * 0.005) * (flash > 0.5 ? 1.6 : 1.0),
                color: flash > 0.5 ? UORANGE : p.color, alpha: min(1, a), halo: flash > 0.4)
        }
    }

    // MARK: Layer 4 — jagged filaments (digital nervous system threads)

    private func drawFilaments(_ p: UPen) {
        for fl in filaments {
            var pts: [CGPoint] = []
            var lat = fl.lat, lon = fl.lon
            func emit(_ v: V3) { pts.append(p.pj(v).0) }
            emit(V3(x: cos(lat)*cos(lon), y: sin(lat), z: cos(lat)*sin(lon)))
            for leg in fl.legs {
                let steps = 5
                for s in 1...steps {
                    let f = Double(s) / Double(steps)
                    if leg.dLon != 0 { emit(V3(x: cos(lat)*cos(lon + leg.dLon*f), y: sin(lat), z: cos(lat)*sin(lon + leg.dLon*f))) }
                    else { emit(V3(x: cos(lat + leg.dLat*f)*cos(lon), y: sin(lat + leg.dLat*f), z: cos(lat + leg.dLat*f)*sin(lon))) }
                }
                lat += leg.dLat; lon += leg.dLon
            }
            var path = Path()
            for (i, pt) in pts.enumerated() { if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) } }
            let flick = uh2(fl.seed, (p.t * 8).rounded(.down)) > 0.18 ? 1.0 : 0.35
            line(p, path, color: p.color, alpha: (0.07 + 0.10 * p.lvl) * flick * (1 + p.peak),
                 width: max(0.5, p.R * 0.0026), glow: false)
            let total = Double(pts.count - 1)                   // traveling ember
            let pos = ufr(p.t * fl.speed * (1 + p.lvl) + fl.off) * total
            let i = min(pts.count - 2, Int(pos)), f = pos - Double(i)
            dot(p, at: CGPoint(x: pts[i].x + (pts[i+1].x - pts[i].x) * cg(f),
                               y: pts[i].y + (pts[i+1].y - pts[i].y) * cg(f)),
                r: max(0.9, p.R * 0.005), color: UORANGE, alpha: 0.45 * flick + 0.25 * p.lvl, halo: true)
        }
    }

    // MARK: Layer 5 — aggressive saw-tooth audio spikes (two tiers, never smooth)

    private func drawSpikes(_ p: UPen) {
        let act = p.speak ? p.lvl : (p.music ? p.bass * 0.35 : 0)
        let hb = pow(max(0, sin(p.t * 1.35)), 8)               // eerie idle respiration
        let inner = Int(44 * max(0.55, p.detail))
        let bucket = (p.t * 12).rounded(.down)
        var base = Path(), long = Path()
        for i in 0..<inner {
            let a = Double(i) / Double(inner) * UTAU
            let jag = 0.35 + 0.65 * uh2(Double(i) * 1.31, bucket)
            let gate = uh2(Double(i) * 2.7, bucket)
            var len = p.R * (0.028 + hb * 0.05) + act * p.R * (0.09 + 0.26 * uh2(Double(i) * 3.7, bucket)) * jag
            if gate > 0.82 { len += act * p.R * 0.22 }          // occasional long lash
            let r0 = p.R * 0.30
            let p0 = CGPoint(x: p.c.x + cg(cos(a) * r0), y: p.c.y + cg(sin(a) * r0))
            let p1 = CGPoint(x: p.c.x + cg(cos(a) * (r0 + len)), y: p.c.y + cg(sin(a) * (r0 + len)))
            if gate > 0.82 { long.move(to: p0); long.addLine(to: p1) } else { base.move(to: p0); base.addLine(to: p1) }
        }
        line(p, base, color: p.color, alpha: 0.30 + 0.45 * act + 0.25 * p.peak,
             width: max(0.6, p.R * 0.004), glow: false)
        line(p, long, color: UORANGE, alpha: 0.25 + 0.5 * act, width: max(0.6, p.R * 0.0035), glow: true)
        if act > 0.45 {                                        // white-hot tips on the longest lashes
            for i in 0..<inner where uh2(Double(i) * 2.7, bucket) > 0.9 {
                let a = Double(i) / Double(inner) * UTAU, r1 = p.R * 0.30 + act * p.R * 0.42
                dot(p, at: CGPoint(x: p.c.x + cg(cos(a) * r1), y: p.c.y + cg(sin(a) * r1)),
                    r: max(1, p.R * 0.006), color: .white, alpha: 0.8, halo: true)
            }
        }
    }

    // MARK: Layer 6 — chaotic electrical arcs (rare, layered red→orange→white)

    private func drawArcs(_ p: UPen) {
        guard !arcs.isEmpty else { return }
        var g = p.g
        g.blendMode = .plusLighter
        for arc in arcs {
            let env = sin(min(1, (p.t - arc.t0) / 0.22) * .pi)
            let a0 = uh1(arc.seed) * UTAU
            let a1 = a0 + (uh1(arc.seed + 1.0) - 0.5) * 2.4
            let r0 = p.R * 0.30, r1 = p.R * (0.55 + 0.35 * uh1(arc.seed + 2.0))
            let n = 11, jitterBucket = (p.t * 40).rounded(.down)
            var pts: [CGPoint] = []
            for i in 0...n {
                let f = Double(i) / Double(n)
                let aa = a0 + (a1 - a0) * f, rr = r0 + (r1 - r0) * f
                let off = (uh2(arc.seed, Double(i) + jitterBucket) - 0.5) * p.R * 0.16 * (1 + p.bass) * sin(f * .pi)
                let dx = cos(aa), dy = sin(aa)
                pts.append(CGPoint(x: p.c.x + cg(dx * rr - dy * off), y: p.c.y + cg(dy * rr + dx * off)))
            }
            var full = Path(), mid = Path(), core = Path()
            for i in 0..<n {
                if i == 0 { full.move(to: pts[0]) }; full.addLine(to: pts[i + 1])
                if i >= 2 && i <= 8 { if mid.isEmpty { mid.move(to: pts[i]) }; mid.addLine(to: pts[i + 1]) }
                if i >= 3 && i <= 7 { if core.isEmpty { core.move(to: pts[i]) }; core.addLine(to: pts[i + 1]) }
            }
            g.stroke(full, with: .color(p.color.opacity(0.12 * env)), lineWidth: max(1.5, cg(p.R * 0.012)))
            g.stroke(full, with: .color(p.color.opacity(0.45 * env)), lineWidth: max(0.8, cg(p.R * 0.005)))
            g.stroke(mid,  with: .color(UORANGE.opacity(0.75 * env)), lineWidth: max(0.6, cg(p.R * 0.0028)))
            g.stroke(core, with: .color(.white.opacity(0.9 * env)),   lineWidth: max(0.4, cg(p.R * 0.0014)))
        }
    }

    // MARK: Layer 7 — hexagonal optic core (aperture contracts on peaks)

    private func drawCore(_ p: UPen) {
        let burst = 1.0 + Double(p.lifecycle.coreBurst) * 1.5
        let hb = pow(max(0, sin(p.t * 1.35)), 8)
        var s = 1.0 - 0.26 * p.peak - 0.08 * p.lvl * (p.speak ? 1.0 : 0.3) + 0.035 * sin(p.t * 1.5) + hb * 0.04
        s = max(0.5, s) * burst
        let rot = p.t * 0.15 + p.twitch
        let hr = p.R * 0.155 * s
        var g = p.g
        g.blendMode = .plusLighter
        g.fill(Path(ellipseIn: CGRect(x: p.c.x - cg(p.R*0.30*s), y: p.c.y - cg(p.R*0.30*s), width: cg(p.R*0.60*s), height: cg(p.R*0.60*s))),
               with: .radialGradient(Gradient(colors: [.white.opacity(min(1.0, (0.5 + 0.3 * p.peak + hb * 0.15) * burst)),
                                                       UORANGE.opacity(0.35), .clear]),
                                     center: p.c, startRadius: 0, endRadius: cg(p.R * 0.30 * s)))
        line(p, hex(p.c, r: hr, rot: rot), color: p.color, alpha: min(1.0, 0.85 * burst), width: max(1, p.R * 0.007), glow: true)
        line(p, hex(p.c, r: hr * 0.58, rot: -rot * 1.6 + 0.4), color: UORANGE, alpha: 0.6,
             width: max(Double(0.6), p.R * 0.004), glow: false)
        var blades = Path()
        for i in 0..<6 {
            let a = Double(i) / 6 * UTAU + rot * 0.5
            blades.move(to: CGPoint(x: p.c.x + cg(cos(a) * hr * 0.75), y: p.c.y + cg(sin(a) * hr * 0.75)))
            blades.addLine(to: CGPoint(x: p.c.x + cg(cos(a) * hr * 1.45), y: p.c.y + cg(sin(a) * hr * 1.45)))
        }
        line(p, blades, color: p.color, alpha: min(1.0, (0.5 + 0.3 * p.peak) * burst), width: max(0.7, p.R * 0.0035), glow: false)
        dot(p, at: p.c, r: max(1.5, p.R * 0.012 * burst), color: .white, alpha: min(1.0, (0.85 + 0.15 * p.peak) * burst), halo: true)
    }

    private func hex(_ c: CGPoint, r: Double, rot: Double) -> Path {
        var path = Path()
        for i in 0...6 {
            let a = Double(i) / 6 * UTAU + rot
            let pt = CGPoint(x: c.x + cg(cos(a) * r), y: c.y + cg(sin(a) * r))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        return path
    }

    // MARK: Layer 8 — floating fragments (data structures being created & destroyed)

    private func drawFragments(_ p: UPen) {
        for f in fragments {
            if uh2(f.seed, (p.t / 2.5).rounded(.down)) < 0.22 { continue }   // appear/disappear gate
            let drift = 0.05 * sin(p.t * 0.4 + f.seed * 3.1)
            let v = V3(x: f.p.x + drift, y: f.p.y + 0.04 * sin(p.t * 0.3 + f.seed), z: f.p.z)
            let (pt, d) = p.pj(v)
            let depth = min(1, max(0, (d - 0.75) / 0.75))
            let flick = uh2(f.seed * 3.3, (p.t * 8).rounded(.down))
            let alpha = (0.10 + 0.25 * uh1(f.seed)) * (0.35 + 0.65 * depth) * (flick > 0.15 ? 1.0 : 0.3)
            let s = f.s * p.R * d
            var path = Path()
            switch f.kind {
            case 0:
                let a = p.t * f.spin + f.seed
                path.move(to: CGPoint(x: pt.x - cg(cos(a) * s), y: pt.y - cg(sin(a) * s)))
                path.addLine(to: CGPoint(x: pt.x + cg(cos(a) * s), y: pt.y + cg(sin(a) * s)))
            case 1:
                for i in 0...3 {
                    let a = Double(i % 3) / 3 * UTAU + p.t * f.spin
                    let pp = CGPoint(x: pt.x + cg(cos(a) * s), y: pt.y + cg(sin(a) * s))
                    if i == 0 { path.move(to: pp) } else { path.addLine(to: pp) }
                }
            default:
                path.move(to: CGPoint(x: pt.x - cg(s), y: pt.y - cg(s * 0.6)))
                path.addLine(to: CGPoint(x: pt.x - cg(s), y: pt.y + cg(s * 0.6)))
                path.move(to: CGPoint(x: pt.x + cg(s), y: pt.y - cg(s * 0.6)))
                path.addLine(to: CGPoint(x: pt.x + cg(s), y: pt.y + cg(s * 0.6)))
            }
            line(p, path, color: p.color, alpha: alpha, width: max(0.5, p.R * 0.0028), glow: alpha > 0.2)
        }
    }

    // MARK: Layer 9 — peak shockwave ("electrical thought pulse")

    private func drawShockwave(_ p: UPen) {
        let age = (p.t - (peakT)) / 0.55
        guard age > 0 && age < 1 else { return }
        var g = p.g
        g.blendMode = .plusLighter
        for delay in [0.0, 0.12] {
            let a2 = age - delay
            guard a2 > 0 && a2 < 1 else { continue }
            let r = p.R * (0.22 + 1.05 * a2)
            g.stroke(Path(ellipseIn: CGRect(x: p.c.x - cg(r), y: p.c.y - cg(r), width: cg(r*2), height: cg(r*2))),
                     with: .color(p.color.opacity(pow(1 - a2, 2) * 0.4)), lineWidth: max(0.6, cg(2.5 * (1 - a2))))
        }
    }

    // MARK: Layer 10 — controlled digital instability

    private func drawGlitch(_ p: UPen) {
        var g = p.g
        let y = p.c.y + cg((uh1((p.t * 31).rounded(.down)) - 0.5) * p.R * 1.6)
        g.fill(Path(CGRect(x: p.c.x - cg(p.R), y: y, width: cg(p.R * 2), height: 1)),
               with: .color(p.color.opacity(0.06)))
        g.blendMode = .plusLighter
        g.fill(Path(CGRect(x: p.c.x - cg(p.R), y: y - 6, width: cg(p.R * 2), height: 3)),
               with: .color(p.color.opacity(0.05)))
    }
}

// MARK: - Preview (simulated voice + sliders)

#if DEBUG
struct UltronHologramView_Previews: PreviewProvider {
    struct Demo: View {
        @State private var speaking = true
        @State private var level = 0.4, bass = 0.3
        var body: some View {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                let sim = 0.25 + 0.55 * abs(sin(t * 2.7)) * (0.5 + 0.5 * sin(t * 0.9))
                let simB = 0.3 + 0.4 * abs(sin(t * 1.1))
                VStack(spacing: 18) {
                    UltronHologramView(isSpeaking: speaking, isPlayingMusic: !speaking, size: 520,
                                       audioLevel: speaking ? sim : level, audioBass: speaking ? simB : bass)
                    Slider(value: $level, in: 0...1).padding(.horizontal, 40)
                    Slider(value: $bass, in: 0...1).padding(.horizontal, 40)
                    Toggle("Speaking", isOn: $speaking).frame(width: 220)
                }
                .padding(40).background(Color.black.ignoresSafeArea())
            }
        }
    }
    var previews: some View { Demo() }
}
#endif