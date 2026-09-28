import SwiftUI

// MARK: - Live Gesture Test Grid Card
public struct GestureTestGridCardView: View {
    @ObservedObject var manager = CameraGestureManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Interactive Gesture Monitor")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Text("Perform gestures to see live illumination")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(RecognizedGestureType.allCases.filter { $0 != .none }) { g in
                    let isCurrent = (manager.lastGesture == g)
                    HStack(spacing: 8) {
                        Image(systemName: g.iconName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(isCurrent ? Color.accentColor : .cyan)
                        
                        Text(g.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isCurrent ? Color.accentColor : .primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if isCurrent {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(isCurrent ? Color.accentColor.opacity(0.18) : Color(nsColor: .quaternaryLabelColor).opacity(0.25))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isCurrent ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isCurrent ? 1.5 : 0.5)
                    )
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}

// MARK: - Gesture Reference Guide Card
public struct GestureReferenceGuideCardView: View {
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Two-Handed 10-Finger Command Map")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                guideRow(hand: "Right", pose: "Index Pointing", action: "Engages Optical Air Mouse; moves cursor relatively")
                guideRow(hand: "Right", pose: "Open / Relax Hand", action: "Lifts mouse off desk; cursor stays frozen in place")
                guideRow(hand: "Right", pose: "Index + Thumb Pinch", action: "Left click / focus input with zero cursor drift")
                guideRow(hand: "Right", pose: "Pinch & Hold (>200ms)", action: "Click and drag windows, text, or files")
                guideRow(hand: "Right", pose: "Middle + Thumb Pinch", action: "Right click context menu")
                guideRow(hand: "Right", pose: "2 Fingers Extended", action: "Smooth vertical and horizontal scroll (no cursor drop)")
                guideRow(hand: "Left", pose: "Closed Fist", action: "Records dictation (Groq Large v3 / Apple Silicon)")
                guideRow(hand: "Left", pose: "Open Fist", action: "Stops dictation, transcribes & auto-pastes text")
                guideRow(hand: "MacBook", pose: "Hold Left Fn (🌐)", action: "Push-to-Talk: records while held, auto-pastes on release")
                guideRow(hand: "Left", pose: "Index Tap / Pinch", action: "Return / Enter (submits chat query)")
                guideRow(hand: "Left", pose: "V / Peace Sign", action: "Paste (Cmd + V)")
                guideRow(hand: "Left", pose: "C Hand Pose", action: "Copy (Cmd + C)")
                guideRow(hand: "Left", pose: "Open Palm Stop", action: "Escape / Dismiss active popup")
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
    
    private func guideRow(hand: String, pose: String, action: String) -> some View {
        HStack(spacing: 12) {
            Text(hand)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(hand == "Right" ? .cyan : .orange)
                .frame(width: 44, alignment: .leading)
            
            Text(pose)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 170, alignment: .leading)
            
            Text(action)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
