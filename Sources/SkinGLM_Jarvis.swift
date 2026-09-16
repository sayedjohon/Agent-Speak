//
//  JarvisHologramView.swift
//  Agent Speak — J.A.R.V.I.S. "Cinema Arc Reactor" skin
//
//  Layer stack (back → front):
//   0. Atmospheric volumetric haze (amber)
//   1. Circuit-globe shell  — dashed latitude bands + broken meridian arcs (3D, x-ray depth)
//   2. Gyroscope rings      — counter-rotating, perspective-tilted, one mechanically stepping
//   3. Circuit traces       — right-angle PCB paths on the shell, traveling white data pulses
//   4. Junction nodes       — 80% dim / 15% medium / 5% bright hierarchy, nervous flashes
//   5. Bokeh particles      — defocused depth-of-field dots (bigger + softer = farther)
//   6. Radial burst spokes  — long thin needles with riding dot-dashes (voice bursts)
//   7. Hanging threads      — vertical data strands under the southern cap
//   8. Central core         — bright torus iris, dark pupil, hot rotating glint arc, swirl wisps
//   9. HUD telemetry frame  — corner rules, tick bar, bottom-right micro-gauge (size ≥ 300pt)
//  10. Scan pass            — slow, near-subconscious refresh band
//
//  Audio mapping:  audioLevel → spoke length, node flashes, packet speed, core glow.
//                  audioBass  → ring brightness, halo expansion, structural breathing.
//                  Idle       → never frozen: slow drift, heartbeat, sparse packets.
//

import SwiftUI
import Foundation

// MARK: - Public drop-in view

struct GLM_JarvisView: View {
    var isSpeaking: Bool = false
    var isPlayingMusic: Bool = false
    var size: CGFloat = 420                                   // 68pt icon → 800pt full screen
    var customWidth: CGFloat? = nil
    var themeColor: Color = Color(red: 1.00, green: 0.72, blue: 0.26) // golden amber
    var audioLevel: CGFloat = 0                               // 0...1 live speech RMS
    var audioBass: CGFloat = 0                                // 0...1 low band

    @State private var engine = JarvisEngine()

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

// MARK: - Math kit (file-private, zero allocations per frame)

private struct V3 { var x = 0.0, y = 0.0, z = 0.0 }
private extension V3 {
    func rotX(_ a: Double) -> V3 { V3(x: x, y: y*cos(a) - z*sin(a), z: y*sin(a) + z*cos(a)) }
    func rotY(_ a: Double) -> V3 { V3(x: x*cos(a) + z*sin(a), y: y, z: z*cos(a) - x*sin(a)) }
    func rotZ(_ a: Double) -> V3 { V3(x: x*cos(a) - y*sin(a), y: x*sin(a) + y*cos(a), z: z) }
    func scaled(_ s: Double) -> V3 { V3(x: x*s, y: y*s, z: z*s) }
}
private let JTAU = Double.pi * 2
@inline(__always) private func jfr(_ v: Double) -> Double { v - v.rounded(.down) }
@inline(__always) private func jh1(_ n: Double) -> Double { jfr(sin(n * 127.1) * 43758.5453) }
@inline(__always) private func jh2(_ a: Double, _ b: Double) -> Double { jfr(sin(a * 127.1 + b * 311.7) * 43758.5453) }
@inline(__always) private func cg(_ v: Double) -> CGFloat { CGFloat(v) }

// MARK: - Render context

private struct JPen {
    var g: GraphicsContext
    var c: CGPoint, cx: Double, cy: Double
    var R: Double, t: Double, lvl: Double, bass: Double
    var speak: Bool, music: Bool
    var color: Color
    var detail: Double
    var lifecycle: HologramLifecycleState
    var pj: (V3) -> (CGPoint, Double)   // 3D → screen + depth scale
    var df: (Double) -> Double          // depth scale → 0(back)...1(front)
}

// MARK: - Engine

private final class JarvisEngine {

    private var sLvl = 0.0, sBass = 0.0, lastT = 0.0

    // Precomputed irregular geometry tables — built once in init.
    private var latRings: [(lat: Double, spin: Double, dashes: [(a: Double, len: Double)])] = []
    private var meridians: [(spin: Double, runs: [(t0: Double, t1: Double)])] = []
    private var nodes: [(lat: Double, lon: Double, cls: Double, ph: Double)] = []
    private var bokeh: [(p: V3, s: Double, a: Double)] = []
    private var traces: [(lat: Double, lon: Double, legs: [(dLat: Double, dLon: Double)], speed: Double, off: Double)] = []
    private var spokes: [(v: V3, len: Double, seed: Double)] = []
    private var threads: [(lon: Double, len: Double, seed: Double)] = []

    init() { build() }

    private func shell(_ lat: Double, _ lon: Double) -> V3 {
        V3(x: cos(lat) * cos(lon), y: sin(lat), z: cos(lat) * sin(lon))
    }

    private func build() {
        // Latitude circuit bands: irregular dashes; ~28% fuse into long PCB runs.
        for i in 0..<11 {
            let lat = (-80.0 + 160.0 * Double(i) / 10.0) * .pi / 180
            var dashes: [(Double, Double)] = []; var a = 0.0; var k = 0.0
            while a < JTAU {
                let r1 = jh2(Double(i) * 7.31, k), r2 = jh2(Double(i) * 3.77 + 11.0, k)
                let len = 0.014 + 0.055 * r1 * r1
                let gap = r2 < 0.28 ? 0.004 : 0.02 + 0.085 * r2
                dashes.append((a, len)); a += len + gap; k += 1
            }
            latRings.append((lat, (i % 2 == 0 ? 1 : -1) * (0.045 + 0.03 * jh1(Double(i) * 5.1)), dashes))
        }
        // Meridians: pole-to-pole great-circle arcs with missing chunks.
        for m in 0..<9 {
            var runs: [(Double, Double)] = []; var th = -1.35 + jh1(Double(m) * 2.9) * 0.3
            while th < 1.35 {
                let r1 = jh2(Double(m) * 9.7, th * 5.0), len = 0.25 + 0.55 * r1
                if r1 > 0.22 { runs.append((th, min(1.35, th + len))) }
                th += len + 0.12 + 0.3 * jh2(Double(m) * 4.3, th * 7.0)
            }
            meridians.append((m % 2 == 0 ? 0.03 : -0.024, runs))
        }
        for n in 0..<48 {   // junction nodes
            nodes.append((lat: (jh1(Double(n) * 12.9) - 0.5) * 2.5, lon: jh1(Double(n) * 7.7 + 3.0) * JTAU,
                          cls: jh1(Double(n) * 3.3 + 9.0), ph: jh1(Double(n) * 5.9 + 1.0)))
        }
        for b in 0..<14 {   // defocus bokeh
            let a1 = jh1(Double(b) * 13.7) * JTAU, a2 = (jh1(Double(b) * 6.1 + 2.0) - 0.5) * 2.4
            let r = 0.35 + 0.6 * jh1(Double(b) * 8.9 + 5.0)
            bokeh.append((V3(x: cos(a1)*cos(a2), y: sin(a2), z: sin(a1)*cos(a2)).scaled(r),
                          2 + 6 * jh1(Double(b) * 4.7), 0.04 + 0.07 * jh1(Double(b) * 2.3)))
        }
        for tr in 0..<12 {  // PCB traces: alternating constant-lon / constant-lat legs → right angles
            var lat = (jh1(Double(tr) * 9.1) - 0.5) * 2.2, lon = jh1(Double(tr) * 4.4) * JTAU
            let lat0 = lat, lon0 = lon
            var legs: [(Double, Double)] = []
            for l in 0..<4 {
                let r = jh2(Double(tr) * 3.1, Double(l) * 6.7)
                let dLon = l % 2 == 0 ? (r - 0.5) * 1.5 : 0.0
                let dLat = l % 2 == 0 ? 0.0 : (r - 0.5) * 1.0
                legs.append((dLat, dLon)); lat += dLat; lon += dLon
            }
            traces.append((lat0, lon0, legs, 0.10 + 0.16 * jh1(Double(tr) * 2.6), jh1(Double(tr) * 8.8)))
        }
        for s in 0..<15 {   // burst spokes: golden-angle spread + jitter clusters
            let a = Double(s) * 2.39996 + (jh1(Double(s) * 8.8) - 0.5) * 0.7
            let el = (jh1(Double(s) * 5.3 + 4.0) - 0.5) * 1.5
            spokes.append((V3(x: cos(a)*cos(el), y: sin(el), z: sin(a)*cos(el)),
                           0.45 + 0.45 * jh1(Double(s) * 2.2), Double(s)))
        }
        for th in 0..<7 {   // hanging threads
            threads.append((jh1(Double(th) * 7.9) * JTAU, 0.10 + 0.20 * jh1(Double(th) * 3.7), Double(th)))
        }
    }

    // MARK: frame render

    func render(_ g: inout GraphicsContext, canvasSize: CGSize, time: Double,
                speaking: Bool, music: Bool, size: CGFloat, color: Color,
                level: Double, bass: Double, lifecycle: HologramLifecycleState) {
        let dt = lastT == 0 ? (1.0 / 120.0) : min(0.1, max(0.0005, time - lastT))
        lastT = time
        let t = time - 1_704_000_000
        approach(&sLvl, level, atk: 24, rel: 5.5, dt: dt)   // fast attack / slow release
        approach(&sBass, bass, atk: 26, rel: 6.5, dt: dt)
        let active = speaking ? sLvl : (music ? sBass * 0.5 : 0)
        let breathe = 0.012 * sin(t * 0.9) + active * 0.05

        let c = CGPoint(x: canvasSize.width * 0.5, y: canvasSize.height * 0.5)
        let R = Double(min(canvasSize.width, canvasSize.height)) * 0.30
        let detail = min(1.0, max(0.35, Double(size) / 420.0))
        let tilt = 0.36 + 0.045 * sin(t * 0.06)     // slow camera precession
        let prec = t * 0.05 * Double(lifecycle.spinVelocityMultiplier)

        func pj(_ v: V3) -> (CGPoint, Double) {
            let r = v.scaled((1.0 + breathe) * Double(lifecycle.power)).rotY(prec).rotX(tilt)
            let d = 3.0 / (3.0 + r.z)               // perspective
            return (CGPoint(x: c.x + cg(r.x * R * d), y: c.y + cg(r.y * R * d)), d)
        }
        func df(_ d: Double) -> Double { min(1, max(0, (d - 0.75) / 0.75)) }

        let pen = JPen(g: g, c: c, cx: Double(c.x), cy: Double(c.y), R: R, t: t,
                       lvl: sLvl, bass: sBass, speak: speaking, music: music,
                       color: color, detail: detail, lifecycle: lifecycle, pj: pj, df: df)

        drawAtmosphere(pen)
        drawCircuitGlobe(pen)
        drawGyroRings(pen)
        drawTraces(pen)
        drawNodes(pen)
        drawBokeh(pen)
        drawSpokes(pen)
        if R > 80 { drawThreads(pen) }
        drawCore(pen)
        if Double(size) >= 300 { drawHUD(pen, fade: min(1, (Double(size) - 300) / 140)) }
        drawScan(pen)
    }

    private func approach(_ v: inout Double, _ target: Double, atk: Double, rel: Double, dt: Double) {
        let r = target > v ? atk : rel
        v += (target - v) * (1 - exp(-r * dt))
    }

    // MARK: stroke/dot primitives (layered fake bloom)

    private func line(_ p: JPen, _ path: Path, color: Color, alpha: Double, width: Double, glow: Bool = true) {
        guard alpha > 0.004 else { return }
        var g = p.g
        if glow {
            g.blendMode = .plusLighter
            g.stroke(path, with: .color(color.opacity(alpha * 0.10)), lineWidth: max(1, cg(width * 6)))
            g.stroke(path, with: .color(color.opacity(alpha * 0.22)), lineWidth: max(0.6, cg(width * 2.6)))
        }
        g.stroke(path, with: .color(color.opacity(alpha)), lineWidth: max(0.4, cg(width)))
    }

    private func dot(_ p: JPen, at pt: CGPoint, r: Double, color: Color, alpha: Double, halo: Bool = true) {
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

    // MARK: Layer 0 — atmosphere

    private func drawAtmosphere(_ p: JPen) {
        let a = (0.05 + p.lvl * 0.06 + p.bass * 0.05) * Double(p.lifecycle.power)
        p.g.fill(Path(ellipseIn: CGRect(x: p.c.x - cg(p.R*1.15), y: p.c.y - cg(p.R*1.15), width: cg(p.R*2.3), height: cg(p.R*2.3))),
                 with: .radialGradient(Gradient(colors: [p.color.opacity(a), p.color.opacity(a * 0.35), .clear]),
                                       center: p.c, startRadius: 0, endRadius: cg(p.R * 1.15)))
    }

    // MARK: Layer 1 — circuit-globe shell (the dominant texture)

    private func drawCircuitGlobe(_ p: JPen) {
        for (ri, ring) in latRings.enumerated() {
            var dim = Path(), hot = Path()
            var dots: [(CGPoint, Double)] = []
            let spin = p.t * ring.spin * Double(p.lifecycle.spinVelocityMultiplier)
            for i in ring.dashes.indices {
                if p.detail < 1 && jh2(Double(ri) * 9.1, Double(i)) > p.detail { continue } // detail culling
                let d = ring.dashes[i]
                let a0 = d.a + spin, m = a0 + d.len * 0.5
                let p0 = p.pj(shell(ring.lat, a0)).0, p1 = p.pj(shell(ring.lat, a0 + d.len)).0
                let depth = p.df(p.pj(shell(ring.lat, m)).1)
                let clus = 0.30 + 0.70 * pow(jh2(Double(ri) * 2.7, (m * 1.9).rounded(.down)), 2) // brightness continents
                let flick = jh2(Double(ri) * 5.1, (p.t * 1.5 + Double(ri)).rounded(.down)) > 0.06 ? 1.0 : 0.35
                let alpha = (0.05 + 0.34 * pow(jh2(Double(ri) * 1.3, Double(i)), 2)) * clus * (0.25 + 0.75 * depth) * flick
                if alpha > 0.16 { hot.addLines([p0, p1]) } else { dim.addLines([p0, p1]) }
                if jh2(Double(ri) * 3.3, Double(i) * 1.7) > 0.86 { dots.append((p1, depth)) } // PCB junctions
            }
            let w = max(0.5, p.R * 0.004)
            line(p, dim, color: p.color, alpha: 0.85, width: w, glow: false)
            line(p, hot, color: p.color, alpha: 0.95, width: w * 1.25, glow: true)
            for (pt, depth) in dots {
                dot(p, at: pt, r: w * 1.1, color: p.color, alpha: 0.5 * (0.3 + 0.7 * depth), halo: false)
            }
        }
        for (mi, mer) in meridians.enumerated() { // broken meridian arcs
            var path = Path()
            let lon0 = p.t * mer.spin * Double(p.lifecycle.spinVelocityMultiplier) + Double(mi) * (JTAU / 9)
            var dMin = 2.0, dMax = 0.0
            for run in mer.runs {
                let steps = 7
                for s in 0...steps {
                    let th = run.t0 + (run.t1 - run.t0) * Double(s) / Double(steps)
                    let (pt, d) = p.pj(shell(th, lon0))
                    dMin = min(dMin, d); dMax = max(dMax, d)
                    if s == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
            }
            let depth = p.df((dMin + dMax) * 0.5)
            line(p, path, color: p.color, alpha: 0.16 + 0.20 * depth, width: max(0.5, p.R * 0.003), glow: false)
        }
    }

    // MARK: Layer 2 — gyroscope rings (counter-rotating, one stepping mechanically)

    private func drawGyroRings(_ p: JPen) {
        let defs: [(r: Double, rx: Double, rz: Double, speed: Double)] = [
            (0.88, 1.22, 0.15, 0.10), (0.74, 0.55, 0.85, -0.16), (0.58, 1.05, -0.60, 0.23)
        ]
        for (i, def) in defs.enumerated() {
            let deploy = Double(p.lifecycle.ringProgress(index: i, total: defs.count))
            guard deploy > 0.02 else { continue }
            var path = Path()
            var phase = p.t * def.speed * Double(p.lifecycle.spinVelocityMultiplier)
            if i == 2 { phase = (p.t * def.speed * 2.4).rounded(.down) / 2.4 } // mechanical angular stepping
            let steps = Int(90 * max(0.5, p.detail))
            var penDown = false
            for s in 0...steps {
                let a = Double(s) / Double(steps) * JTAU
                if jh2(Double(i) * 3.9, (a * 5.1).rounded(.down)) < 0.30 { penDown = false; continue } // gauge gaps
                let v = V3(x: cos(a + phase) * def.r * deploy, y: 0, z: sin(a + phase) * def.r * deploy).rotX(def.rx).rotZ(def.rz)
                let pt = p.pj(v).0
                if penDown { path.addLine(to: pt) } else { path.move(to: pt); penDown = true }
            }
            line(p, path, color: p.color, alpha: (0.35 + 0.35 * Double(i) / 2.0) * deploy,
                 width: max(0.7, p.R * 0.005 * deploy), glow: i == 1)
        }
    }

    // MARK: Layer 3 — PCB traces with traveling white data pulses

    private func drawTraces(_ p: JPen) {
        for tr in traces {
            var pts: [CGPoint] = [], depths: [Double] = []
            var lat = tr.lat, lon = tr.lon
            func emit(_ v: V3) {
                let (pt, d) = p.pj(v)
                pts.append(pt); depths.append(p.df(d))
            }
            emit(shell(lat, lon))
            for leg in tr.legs {
                let steps = 6
                for s in 1...steps {
                    let f = Double(s) / Double(steps)
                    if leg.dLon != 0 { emit(shell(lat, lon + leg.dLon * f)) }
                    else { emit(shell(lat + leg.dLat * f, lon)) }
                }
                lat += leg.dLat; lon += leg.dLon
            }
            var path = Path()
            for (i, pt) in pts.enumerated() { if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) } }
            let dAvg = depths.reduce(0, +) / Double(depths.count)
            line(p, path, color: p.color, alpha: 0.10 + 0.12 * dAvg, width: max(0.5, p.R * 0.0028), glow: false)
            // traveling pulse — speeds up while JARVIS talks
            let total = Double(pts.count - 1)
            let pos = jfr(p.t * tr.speed * (1 + (p.speak ? p.lvl * 1.2 : 0)) + tr.off) * total
            let i = min(pts.count - 2, Int(pos)), f = pos - Double(i)
            let hx = pts[i].x + (pts[i+1].x - pts[i].x) * f, hy = pts[i].y + (pts[i+1].y - pts[i].y) * f
            dot(p, at: CGPoint(x: hx, y: hy), r: max(0.8, p.R * 0.006), color: .white,
                alpha: (0.35 + 0.5 * depths[i]) * (0.4 + 0.6 * p.lvl + 0.2), halo: true)
        }
    }

    // MARK: Layer 4 — junction nodes (80/15/5 hierarchy + nervous flashes)

    private func drawNodes(_ p: JPen) {
        let spin = p.t * 0.045
        for nd in nodes {
            let (pt, d) = p.pj(shell(nd.lat, nd.lon + spin))
            let depth = p.df(d)
            let flash = pow(max(0, sin(JTAU * jfr(p.t * (0.10 + 0.2 * jh1(nd.ph * 7)) + nd.ph))), 18)
            let base = nd.cls < 0.8 ? 0.06 + 0.08 * nd.cls : (nd.cls < 0.95 ? 0.30 : 0.55)
            let boost = p.speak ? p.lvl * 0.3 : (p.music ? 0.08 : 0)
            let alpha = min(1, (base + flash * 0.55) * (0.3 + 0.7 * depth) + boost * depth)
            dot(p, at: pt, r: (nd.cls > 0.95 ? 1.8 : 1.1) * max(0.6, p.R * 0.004),
                color: nd.cls > 0.9 ? .white : p.color, alpha: alpha, halo: nd.cls > 0.8 || flash > 0.4)
        }
    }

    // MARK: Layer 5 — defocus bokeh (bigger + softer = out of focus)

    private func drawBokeh(_ p: JPen) {
        var g = p.g
        g.blendMode = .plusLighter
        for b in bokeh {
            let (pt, d) = p.pj(b.p)
            let depth = p.df(d)
            let s = b.s * (1.6 - depth) * max(0.5, p.R / 180)   // far = more defocused
            let a = b.a * (1.2 - depth)
            for (m, al) in [(1.0, 0.35), (0.6, 0.5), (0.3, 0.8)] {
                g.fill(Path(ellipseIn: CGRect(x: pt.x - cg(s*m), y: pt.y - cg(s*m), width: cg(s*m*2), height: cg(s*m*2))),
                       with: .color(p.color.opacity(a * al)))
            }
        }
    }

    // MARK: Layer 6 — radial burst spokes (the voice needles from the footage)

    private func drawSpokes(_ p: JPen) {
        let spin = p.t * 0.03
        for sp in spokes {
            let v = sp.v.rotY(spin)
            let len = sp.len * (0.55 + 0.45 * jh1(sp.seed))
                      + p.lvl * (0.30 + 0.5 * jh1(sp.seed * 3.1)) * (p.speak ? 1.0 : 0.35)
            let (a, d0) = p.pj(v.scaled(0.17))
            let (b, d1) = p.pj(v.scaled(len))
            let depth = (p.df(d0) + p.df(d1)) * 0.5
            let act = p.speak ? 0.25 + 0.75 * p.lvl : 0.18 + 0.2 * p.bass
            let alpha = act * (0.35 + 0.65 * depth)
            var path = Path(); path.move(to: a); path.addLine(to: b)
            line(p, path, color: p.color, alpha: alpha * 0.8, width: max(0.5, p.R * 0.003), glow: alpha > 0.3)
            var dash = Path()
            for f in [0.30, 0.55, 0.80] where jh1(sp.seed + f) > 0.35 {   // riding dot-dashes
                let (qa, _) = p.pj(v.scaled(0.17 + len * f))
                let (qb, _) = p.pj(v.scaled(0.17 + len * min(1, f + 0.07)))
                dash.move(to: qa); dash.addLine(to: qb)
            }
            line(p, dash, color: .white, alpha: alpha * 0.7, width: max(0.5, p.R * 0.0026), glow: false)
            dot(p, at: b, r: max(0.8, p.R * 0.005), color: .white, alpha: alpha * 0.9, halo: true)
        }
    }

    // MARK: Layer 7 — hanging data threads (southern cap, from footage frame 1)

    private func drawThreads(_ p: JPen) {
        for th in threads {
            let (a, d) = p.pj(shell(-1.28, th.lon + p.t * 0.02))
            let depth = p.df(d)
            let sway = sin(p.t * 0.7 + th.seed * 1.7) * p.R * 0.012
            let L = th.len * p.R * (1 + p.lvl * 0.3)
            var path = Path()
            path.move(to: a)
            path.addQuadCurve(to: CGPoint(x: a.x + cg(sway), y: a.y + cg(L)),
                              control: CGPoint(x: a.x + cg(sway * 0.3), y: a.y + cg(L * 0.55)))
            line(p, path, color: p.color, alpha: 0.10 + 0.14 * depth, width: max(0.5, p.R * 0.0028), glow: false)
            dot(p, at: CGPoint(x: a.x + cg(sway), y: a.y + cg(L)), r: max(0.7, p.R * 0.0045),
                color: p.color, alpha: 0.35 + 0.3 * depth, halo: true)
        }
    }

    // MARK: Layer 8 — central core: torus iris, dark pupil, hot glint, swirl wisps

    private func drawCore(_ p: JPen) {
        let s = 1.0 + 0.02 * sin(p.t * 1.1) + p.lvl * 0.16          // heartbeat + voice response
        let ringR = p.R * 0.145 * s
        let tiltC = 1.18
        let wobble = sin(p.t * 0.2) * 0.08
        func iris(_ r: Double, a0: Double = 0, a1: Double = JTAU) -> Path {
            var path = Path()
            let steps = 48
            for i in 0...steps {
                let a = a0 + (a1 - a0) * Double(i) / Double(steps)
                let pt = p.pj(V3(x: cos(a)*r, y: 0, z: sin(a)*r).rotX(tiltC).rotZ(wobble)).0
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            return path
        }
        var g = p.g
        g.blendMode = .plusLighter
        let glowA = 0.16 + 0.30 * p.lvl + 0.10 * p.bass             // volumetric heart glow
        g.fill(Path(ellipseIn: CGRect(x: p.c.x - cg(p.R*0.32*s), y: p.c.y - cg(p.R*0.32*s), width: cg(p.R*0.64*s), height: cg(p.R*0.64*s))),
               with: .radialGradient(Gradient(colors: [.white.opacity(glowA * 0.8), p.color.opacity(glowA * 0.5), .clear]),
                                     center: p.c, startRadius: 0, endRadius: cg(p.R * 0.32 * s)))
        line(p, iris(ringR * 1.28), color: p.color, alpha: 0.18, width: max(0.6, p.R * 0.004), glow: false)
        line(p, iris(ringR),        color: p.color, alpha: 0.75, width: max(0.8, p.R * 0.006), glow: true)
        line(p, iris(ringR * 0.42), color: p.color, alpha: 0.35, width: max(0.6, p.R * 0.0035), glow: false)
        let hotA = p.t * (0.55 + p.lvl * 0.9)                       // rotating glint arc (accelerates on speech)
        g.stroke(iris(ringR, a0: hotA, a1: hotA + 1.1),
                 with: .color(.white.opacity(0.55 + 0.35 * p.lvl)), lineWidth: max(1, cg(p.R * 0.007)))
        let hv = V3(x: cos(hotA + 1.1) * ringR, y: 0, z: sin(hotA + 1.1) * ringR).rotX(tiltC).rotZ(wobble)
        dot(p, at: p.pj(hv).0, r: max(1.2, p.R * 0.008), color: .white, alpha: 0.9, halo: true)
        p.g.fill(Path(ellipseIn: CGRect(x: p.c.x - cg(ringR*0.30), y: p.c.y - cg(ringR*0.30), width: cg(ringR*0.6), height: cg(ringR*0.6))),
                 with: .color(Color.black.opacity(0.45)))            // dark pupil punch-through
        for k in 0..<4 {                                            // orbiting wisps
            var path = Path()
            let steps = 26, dir = k % 2 == 0 ? 1.0 : -1.0
            for i in 0...steps {
                let f = Double(i) / Double(steps)
                let a = f * 3.4 * dir + hotA * dir * 0.5 + Double(k) * 1.7
                let r = ringR * (0.5 + 0.85 * f)
                let pt = p.pj(V3(x: cos(a)*r, y: sin(f * 2.2) * ringR * 0.16, z: sin(a)*r).rotX(tiltC * 0.9)).0
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            line(p, path, color: p.color, alpha: 0.10 + 0.08 * p.lvl, width: max(0.5, p.R * 0.0028), glow: false)
        }
    }

    // MARK: Layer 9 — HUD telemetry frame (large sizes only; matches footage frame 3)

    private func drawHUD(_ p: JPen, fade: Double) {
        let A = 0.22 * fade, e = p.R * 1.06
        var g = p.g
        var path = Path()
        let y0 = p.c.y - cg(e * 1.06)
        path.move(to: CGPoint(x: p.c.x - cg(e), y: y0)); path.addLine(to: CGPoint(x: p.c.x - cg(e * 0.45), y: y0))
        for i in 0..<4 {
            let x = p.c.x - cg(e) + cg(p.R * 0.12 * Double(i))
            path.move(to: CGPoint(x: x, y: y0)); path.addLine(to: CGPoint(x: x, y: y0 + cg(p.R * 0.03)))
        }
        path.move(to: CGPoint(x: p.c.x + cg(e * 0.62), y: y0)); path.addLine(to: CGPoint(x: p.c.x + cg(e), y: y0))
        path.move(to: CGPoint(x: p.c.x - cg(e), y: y0)); path.addLine(to: CGPoint(x: p.c.x - cg(e), y: p.c.y - cg(e * 0.55)))
        path.move(to: CGPoint(x: p.c.x + cg(e), y: y0 + cg(p.R * 0.1))); path.addLine(to: CGPoint(x: p.c.x + cg(e), y: p.c.y - cg(e * 0.45)))
        g.stroke(path, with: .color(p.color.opacity(A)), lineWidth: 1)
        let gc = CGPoint(x: p.c.x + cg(e * 0.86), y: p.c.y + cg(e * 0.86)), gr = cg(p.R * 0.075) // micro-gauge
        g.stroke(Path(CGRect(x: gc.x - gr, y: gc.y - gr, width: gr * 2, height: gr * 2)),
                 with: .color(p.color.opacity(A * 1.2)), lineWidth: 1)
        var tick = Path()
        for i in 0..<12 {
            let a = Double(i) / 12 * JTAU, r1 = gr * (i % 3 == 0 ? 1.0 : 0.88)
            tick.move(to: CGPoint(x: gc.x + cg(cos(a) * gr * 0.72), y: gc.y + cg(sin(a) * gr * 0.72)))
            tick.addLine(to: CGPoint(x: gc.x + cg(cos(a) * r1), y: gc.y + cg(sin(a) * r1)))
        }
        g.stroke(tick, with: .color(p.color.opacity(A)), lineWidth: 1)
        let na = p.t * 0.35
        var needle = Path()
        needle.move(to: gc); needle.addLine(to: CGPoint(x: gc.x + cg(cos(na) * gr * 0.9), y: gc.y + cg(sin(na) * gr * 0.9)))
        g.stroke(needle, with: .color(.white.opacity(A * 2.2)), lineWidth: 1.2)
    }

    // MARK: Layer 10 — scan refresh pass

    private func drawScan(_ p: JPen) {
        let y = p.c.y + cg((jfr(p.t / 9.0) * 2 - 1) * p.R * 1.15)
        var g = p.g
        g.blendMode = .plusLighter
        let rect = CGRect(x: p.c.x - cg(p.R * 1.3), y: y - cg(p.R * 0.28), width: cg(p.R * 2.6), height: cg(p.R * 0.56))
        g.fill(Path(rect), with: .linearGradient(Gradient(colors: [.clear, p.color.opacity(0.035), .clear]),
                                                 startPoint: CGPoint(x: 0, y: rect.minY),
                                                 endPoint: CGPoint(x: 0, y: rect.maxY)))
    }
}

// MARK: - Preview (simulated voice + sliders)

#if DEBUG
struct JarvisHologramView_Previews: PreviewProvider {
    struct Demo: View {
        @State private var speaking = true
        @State private var level = 0.4, bass = 0.3
        var body: some View {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                let sim = 0.22 + 0.5 * abs(sin(t * 3.1)) * (0.55 + 0.45 * sin(t * 0.7))
                let simB = 0.25 + 0.35 * abs(sin(t * 1.3))
                VStack(spacing: 18) {
                    JarvisHologramView(isSpeaking: speaking, isPlayingMusic: !speaking, size: 520,
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