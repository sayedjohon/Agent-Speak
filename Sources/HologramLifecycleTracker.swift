import SwiftUI
import Foundation

// =============================================================================
// MARK: - HOLOGRAM LIFECYCLE TRACKER (NATIVE HUD IGNITION & RETRACTION ENGINE)
// =============================================================================

/// Tracks real-time lifecycle dynamics for the actual HUD elements of each hologram skin.
/// Governs physical ring unfolding, 3D axon growth, spin acceleration, and core ignition.
public struct HologramLifecycleState {
    public let ignitionProgress: CGFloat        // 0.0 -> 1.0 (over 0.85s)
    public let collapseProgress: CGFloat        // 0.0 -> 1.0 (over 0.45s)
    public let isCollapsing: Bool
    public let power: CGFloat                   // Overall system luminosity (0.0 to 1.0)
    public let coreBurst: CGFloat               // High-energy core ignition flash & dying ember
    public let spinVelocityMultiplier: CGFloat  // Spin-up acceleration (e.g. 3.0x -> 1.0x)
    
    public init(time: TimeInterval) {
        let mgr = HologramManager.shared
        let boot = mgr.bootupDate.timeIntervalSinceReferenceDate
        let elapsed = max(0.0, time - boot)
        self.isCollapsing = mgr.isCollapsing
        
        let igDuration: Double = 0.95
        let ig = min(1.0, max(0.0, elapsed / igDuration))
        self.ignitionProgress = CGFloat(ig)
        
        if isCollapsing, let colStart = mgr.collapseStartDate?.timeIntervalSinceReferenceDate {
            let colElapsed = max(0.0, time - colStart)
            let col = min(1.0, max(0.0, colElapsed / 0.45))
            self.collapseProgress = CGFloat(col)
            self.power = max(0.0, 1.0 - pow(CGFloat(col), 1.25))
            
            // Dying ember flash at 70%-95% collapse
            if col > 0.65 && col < 0.95 {
                let p = (col - 0.65) / 0.30
                self.coreBurst = CGFloat(sin(p * .pi) * 1.8)
            } else {
                self.coreBurst = 0.0
            }
            self.spinVelocityMultiplier = 1.0 + CGFloat(col) * 1.5
        } else {
            self.collapseProgress = 0.0
            self.power = CGFloat(1.0 - pow(1.0 - ig, 2.0))
            if elapsed < 0.28 {
                let d = 1.0 - (elapsed / 0.28)
                self.coreBurst = CGFloat(d * d * 1.8)
            } else {
                self.coreBurst = 0.0
            }
            // Rapid spin-up decelerating into stable harmonic velocity
            self.spinVelocityMultiplier = 1.0 + CGFloat((1.0 - ig) * 2.2)
        }
    }
    
    /// Current expanding or collapsing wavefront radius (0.0 at center, 1.20 at perimeter edge)
    public var wavefrontRadius: CGFloat {
        if isCollapsing {
            let p = collapseProgress
            return max(0.0, 1.25 * pow(1.0 - p, 1.4))
        } else {
            let ig = ignitionProgress
            if ig < 0.04 {
                return 0.04
            }
            let t = (ig - 0.04) / 0.96
            return 0.04 + 1.21 * pow(t, 0.85)
        }
    }
    
    /// Returns visibility alpha (0.0 to 1.0) and instantaneous activation flash (0.0 to 1.0)
    /// for an element located at `dist` (normalized 0.0 to 1.15)
    public func radialReveal(dist: CGFloat) -> (alpha: CGFloat, flash: CGFloat) {
        let wf = wavefrontRadius
        if isCollapsing {
            if dist > wf { return (0.0, 0.0) }
            let edgeDist = wf - dist
            let a = min(1.0, max(0.0, edgeDist / 0.15)) * power
            return (a, 0.0)
        } else {
            if dist > wf { return (0.0, 0.0) }
            let edgeDist = wf - dist
            let flash: CGFloat
            if edgeDist < 0.10 && ignitionProgress < 0.98 {
                let p = 1.0 - (edgeDist / 0.10)
                flash = p * p * 1.6
            } else {
                flash = 0.0
            }
            let a = min(1.0, max(0.0, edgeDist / 0.08)) * power
            return (a, flash)
        }
    }
    
    /// Staggered deployment for concentric elements (rings, brackets, orbital shells)
    public func ringProgress(index: Int, total: Int) -> CGFloat {
        if isCollapsing {
            // Outer elements collapse inward first!
            let norm = CGFloat(total - 1 - index) / CGFloat(max(1, total))
            let start = norm * 0.35
            let prog = (collapseProgress - start) / 0.65
            return max(0.0, min(1.0, 1.0 - prog))
        } else {
            // Inner elements deploy first, outer rings unfold in sequence
            let norm = CGFloat(index) / CGFloat(max(1, total))
            let start = norm * 0.40
            let prog = (ignitionProgress - start) / 0.60
            return max(0.0, min(1.0, prog))
        }
    }
    
    /// Growth fraction for 3D neural axons given distance from center (0.0 to 1.0)
    public func axonGrowth(normalizedDist: CGFloat) -> CGFloat {
        if isCollapsing {
            // Outer axons retract toward center first
            let threshold = 1.0 - collapseProgress
            if normalizedDist > threshold {
                let diff = normalizedDist - threshold
                return max(0.0, 1.0 - diff * 3.5)
            }
            return 1.0
        } else {
            // Axons grow outward from root nodes to perimeter
            let start = normalizedDist * 0.45
            let prog = (ignitionProgress - start) / 0.55
            return max(0.0, min(1.0, prog))
        }
    }
}
