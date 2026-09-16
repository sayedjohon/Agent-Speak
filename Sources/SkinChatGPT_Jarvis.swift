import SwiftUI
import CoreGraphics
import Foundation

// MARK: - Agent Speak / JARVIS
//
// This renderer intentionally follows the documented cinematic grammar of the
// Age of Ultron J.A.R.V.I.S. hologram: an orange/gold spherical computational
// volume, an orrery-like system of rotating data rings, block/segment data,
// a central heart, and dialogue-driven volumetric vibration.
//
// It is NOT a generic neon equalizer and it deliberately does not share the
// Ultron renderer's organic/fractured grammar.
//
// Public contract:
//   isSpeaking, isPlayingMusic, size, themeColor, audioLevel, audioBass
//
// macOS 14+ / SwiftUI Canvas / no third-party dependencies.

public struct ChatGPT_JarvisView: View {
    public let isSpeaking: Bool
    public let isPlayingMusic: Bool
    public let size: CGFloat
    public let themeColor: Color
    public let audioLevel: CGFloat
    public let audioBass: CGFloat
    public var customWidth: CGFloat?

    public init(
        isSpeaking: Bool = false,
        isPlayingMusic: Bool = false,
        size: CGFloat,
        customWidth: CGFloat? = nil,
        themeColor: Color = JARVISPalette.orange,
        audioLevel: CGFloat = 0,
        audioBass: CGFloat = 0
    ) {
        self.isSpeaking = isSpeaking
        self.isPlayingMusic = isPlayingMusic
        self.size = size
        self.customWidth = customWidth
        self.themeColor = themeColor
        self.audioLevel = audioLevel
        self.audioBass = audioBass
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 120.0, paused: false)) { timeline in
            Canvas(opaque: false, colorMode: .extendedLinear, rendersAsynchronously: true) { context, canvasSize in
                let side = min(size, min(canvasSize.width, canvasSize.height))
                let center = CGPoint(x: canvasSize.width * 0.5, y: canvasSize.height * 0.5)
                let now = timeline.date.timeIntervalSinceReferenceDate
                let frame = JARVISFrame(
                    time: now,
                    center: center,
                    size: side,
                    level: JARVISMath.smoothInput(audioLevel, phase: now * 0.31),
                    bass: JARVISMath.smoothInput(audioBass, phase: now * 0.19),
                    speaking: isSpeaking,
                    music: isPlayingMusic,
                    color: themeColor
                )
                JARVISRenderer().render(context: &context, frame: frame)
            }
        }
        .frame(width: customWidth ?? size, height: size)
        .drawingGroup()
    }
}

// MARK: - Palette

public enum JARVISPalette {
    public static let orange = Color(red: 1.0, green: 0.48, blue: 0.045)
    public static let amber = Color(red: 1.0, green: 0.72, blue: 0.20)
    public static let gold = Color(red: 1.0, green: 0.86, blue: 0.50)
    public static let hot = Color.white
    public static let dark = Color(red: 0.18, green: 0.055, blue: 0.012)
}

// MARK: - Frame

struct JARVISFrame {
    let time: Double
    let center: CGPoint
    let size: CGFloat
    let level: CGFloat
    let bass: CGFloat
    let speaking: Bool
    let music: Bool
    let color: Color

    var radius: CGFloat { size * 0.36 }
    var activity: CGFloat {
        if speaking { return max(0.08, level) }
        if music { return max(0.035, bass * 0.45) }
        return 0.025
    }
    var talkEnergy: CGFloat {
        speaking ? max(level, 0.035) : (music ? bass * 0.20 : 0)
    }
}

// MARK: - 3D Math

struct JPoint3 {
    var x: CGFloat
    var y: CGFloat
    var z: CGFloat

    public static let zero = JPoint3(x: 0, y: 0, z: 0)

    func adding(_ p: JPoint3) -> JPoint3 {
        JPoint3(x: x + p.x, y: y + p.y, z: z + p.z)
    }

    func scaled(_ s: CGFloat) -> JPoint3 {
        JPoint3(x: x * s, y: y * s, z: z * s)
    }
}

struct JRotation {
    var x: CGFloat
    var y: CGFloat
    var z: CGFloat

    func apply(_ p: JPoint3) -> JPoint3 {
        let cx = CGFloat(cos(Double(x)))
        let sx = CGFloat(sin(Double(x)))
        let cy = CGFloat(cos(Double(y)))
        let sy = CGFloat(sin(Double(y)))
        let cz = CGFloat(cos(Double(z)))
        let sz = CGFloat(sin(Double(z)))

        let x1 = p.x
        let y1 = p.y * cx - p.z * sx
        let z1 = p.y * sx + p.z * cx

        let x2 = x1 * cy + z1 * sy
        let y2 = y1
        let z2 = -x1 * sy + z1 * cy

        return JPoint3(
            x: x2 * cz - y2 * sz,
            y: x2 * sz + y2 * cz,
            z: z2
        )
    }
}

struct JProjection {
    let point: CGPoint
    let depth: CGFloat
    let scale: CGFloat
}

enum JARVISMath {
    public static let tau = CGFloat.pi * 2

    static func clamp(_ x: CGFloat, _ lo: CGFloat = 0, _ hi: CGFloat = 1) -> CGFloat {
        min(hi, max(lo, x))
    }

    static func smoothInput(_ x: CGFloat, phase: Double) -> CGFloat {
        let v = clamp(x)
        let micro = CGFloat(0.985 + 0.015 * sin(phase))
        return clamp(v * micro)
    }

    static func hash(_ n: Int) -> CGFloat {
        let x = sin(Double(n) * 12.9898 + 78.233) * 43758.5453
        return CGFloat(x - floor(x))
    }

    static func noise(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        let x = sin(Double(a * 127.1 + b * 311.7)) * 43758.5453123
        return CGFloat(x - floor(x))
    }

    static func project(_ p: JPoint3, radius: CGFloat, center: CGPoint) -> JProjection {
        let perspective: CGFloat = 2.85
        let z = clamp((p.z + 1) * 0.5, 0.02, 1.98)
        let scale = perspective / (perspective + p.z * 0.78)
        let x = center.x + p.x * radius * scale
        let y = center.y + p.y * radius * scale
        return JProjection(
            point: CGPoint(x: x, y: y),
            depth: p.z,
            scale: scale
        )
    }

    static func ringPoint(
        angle: CGFloat,
        radius: CGFloat,
        rotation: JRotation,
        yScale: CGFloat,
        zWarp: CGFloat = 0
    ) -> JPoint3 {
        let p = JPoint3(
            x: cos(angle) * radius,
            y: sin(angle) * radius * yScale,
            z: sin(angle * 2.0) * zWarp
        )
        return rotation.apply(p)
    }
}

