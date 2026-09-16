import SwiftUI
import CoreGraphics
import Foundation

// MARK: - Agent Speak / ULTRON
//
// This renderer follows the documented Age of Ultron Ultron grammar:
// blue/cyan holographic intelligence, highly sophisticated and larger/more
// ornate than JARVIS, with an organic/biological reading, fractured angular
// surface, constant re-assembly, "pops and pings", procedural cause/effect,
// center-out growth and moving data streams.
//
// It is intentionally NOT a red JARVIS variant.
//
// Public contract:
//   isSpeaking, isPlayingMusic, size, themeColor, audioLevel, audioBass
//
// macOS 14+ / SwiftUI Canvas / no third-party dependencies.

public struct ChatGPT_UltronView: View {
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
        themeColor: Color = UltronPalette.blue,
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
                let frame = UFrame(
                    time: now,
                    center: center,
                    size: side,
                    level: UMath.smoothInput(audioLevel, phase: now * 0.29),
                    bass: UMath.smoothInput(audioBass, phase: now * 0.17),
                    speaking: isSpeaking,
                    music: isPlayingMusic,
                    color: themeColor
                )
                UltronRenderer().render(context: &context, frame: frame)
            }
        }
        .frame(width: customWidth ?? size, height: size)
        .drawingGroup()
    }
}

// MARK: - Palette

public enum UltronPalette {
    public static let blue = Color(red: 0.03, green: 0.55, blue: 1.0)
    public static let cyan = Color(red: 0.10, green: 0.90, blue: 1.0)
    public static let electric = Color(red: 0.30, green: 0.98, blue: 1.0)
    public static let white = Color.white
    public static let deep = Color(red: 0.008, green: 0.045, blue: 0.10)
}

// MARK: - Frame

struct UFrame {
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
        if music { return max(0.035, bass * 0.44) }
        return 0.028
    }
    var neuralEnergy: CGFloat {
        speaking ? max(level, 0.035) : (music ? bass * 0.24 : 0)
    }
}

// MARK: - 3D Math

struct UPoint3 {
    var x: CGFloat
    var y: CGFloat
    var z: CGFloat
}

struct URotation {
    var x: CGFloat
    var y: CGFloat
    var z: CGFloat

    func apply(_ p: UPoint3) -> UPoint3 {
        let cx = CGFloat(cos(Double(x)))
        let sx = CGFloat(sin(Double(x)))
        let cy = CGFloat(cos(Double(y)))
        let sy = CGFloat(sin(Double(y)))
        let cz = CGFloat(cos(Double(z)))
        let sz = CGFloat(sin(Double(z)))

        let y1 = p.y * cx - p.z * sx
        let z1 = p.y * sx + p.z * cx
        let x2 = p.x * cy + z1 * sy
        let z2 = -p.x * sy + z1 * cy

        return UPoint3(
            x: x2 * cz - y1 * sz,
            y: x2 * sz + y1 * cz,
            z: z2
        )
    }
}

struct UProjection {
    let point: CGPoint
    let depth: CGFloat
    let scale: CGFloat
}

enum UMath {
    public static let tau = CGFloat.pi * 2

    static func clamp(_ x: CGFloat, _ lo: CGFloat = 0, _ hi: CGFloat = 1) -> CGFloat {
        min(hi, max(lo, x))
    }

    static func smoothInput(_ x: CGFloat, phase: Double) -> CGFloat {
        clamp(clamp(x) * CGFloat(0.985 + 0.015 * sin(phase)))
    }

    static func hash(_ n: Int) -> CGFloat {
        let x = sin(Double(n) * 12.9898 + 78.233) * 43758.5453
        return CGFloat(x - floor(x))
    }

    static func noise(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        let x = sin(Double(a * 127.1 + b * 311.7)) * 43758.5453123
        return CGFloat(x - floor(x))
    }

    static func project(_ p: UPoint3, radius: CGFloat, center: CGPoint) -> UProjection {
        let scale = 2.75 / (2.75 + p.z * 0.82)
        return UProjection(
            point: CGPoint(
                x: center.x + p.x * radius * scale,
                y: center.y + p.y * radius * scale
            ),
            depth: p.z,
            scale: scale
        )
    }
}

