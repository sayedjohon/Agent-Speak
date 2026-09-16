import SwiftUI

// MARK: - Gesture Toggles Card View
public struct GestureTogglesCardView: View {
    @ObservedObject var classifier = GestureClassifier.shared
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.raised.fingers.spread.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.cyan)
                        Text("Active Gesture Switches")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text("Turn individual gestures on or off to prevent accidental actions. By default, only Point & Left Click are enabled.")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                // Reset to Recommended Defaults
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        classifier.resetToDefaults()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Defaults")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.10))
                    .foregroundColor(.cyan)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            Divider().background(Color.white.opacity(0.12))
            
            // Section 1: Right Hand (Air Mouse & Navigation)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 7, height: 7)
                    Text("RIGHT HAND — AIR MOUSE & NAVIGATION")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan)
                    Spacer()
                }
                
                VStack(spacing: 8) {
                    gestureToggleRow(
                        icon: "hand.point.up.left.fill",
                        iconColor: .cyan,
                        title: "Air Mouse Movement",
                        posture: "☝️ Point index finger alone (other fingers fisted)",
                        isOn: Binding(
                            get: { classifier.toggles.airMouse },
                            set: { val in
                                classifier.toggles.airMouse = val
                                classifier.saveToggles()
                            }
                        )
                    )
                    
                    gestureToggleRow(
                        icon: "hand.tap.fill",
                        iconColor: .cyan,
                        title: "Left Click",
                        posture: "🤏 Quick pinch with index finger & thumb (< 0.45s)",
                        isOn: Binding(
                            get: { classifier.toggles.leftClick },
                            set: { val in
                                classifier.toggles.leftClick = val
                                classifier.saveToggles()
                            }
                        )
                    )
                    
                    gestureToggleRow(
                        icon: "arrow.up.and.down.and.arrow.left.and.right",
                        iconColor: .cyan,
                        title: "Click & Drag",
                        posture: "✊ Pinch index & thumb and hold for 0.55s to drag",
                        isOn: Binding(
                            get: { classifier.toggles.clickAndDrag },
                            set: { val in
                                classifier.toggles.clickAndDrag = val
                                classifier.saveToggles()
                            }
                        )
                    )
                    
                    gestureToggleRow(
                        icon: "cursorarrow.click.2",
                        iconColor: .cyan,
                        title: "Right Click Context Menu",
                        posture: "👆 Extend middle finger alone and tap thumb to middle tip",
                        isOn: Binding(
                            get: { classifier.toggles.rightClick },
                            set: { val in
                                classifier.toggles.rightClick = val
                                classifier.saveToggles()
                            }
                        )
                    )
                    
                    gestureToggleRow(
                        icon: "arrow.up.and.down",
                        iconColor: .cyan,
                        title: "Two-Finger Smooth Scroll",
                        posture: "✌️ Extend index & middle fingers together and wave vertically",
                        isOn: Binding(
                            get: { classifier.toggles.smoothScroll },
                            set: { val in
                                classifier.toggles.smoothScroll = val
                                classifier.saveToggles()
                            }
                        )
                    )
                }
            }
            .padding(12)
            .background(Color.cyan.opacity(0.04))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.15), lineWidth: 0.8))
            
            // Section 2: Left Hand (Dictation & Shortcuts)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 7, height: 7)
                    Text("LEFT HAND — VOICE DICTATION & CONTROLS")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    Spacer()
                }
                
                VStack(spacing: 8) {
                    gestureToggleRow(
                        icon: "waveform.and.mic",
                        iconColor: .orange,
                        title: "Whisper Voice Dictation",
                        posture: "✊ Hold closed fist to speak; release to auto-transcribe & paste",
                        isOn: Binding(
                            get: { classifier.toggles.leftDictation },
                            set: { val in
                                classifier.toggles.leftDictation = val
                                classifier.saveToggles()
                            }
                        )
                    )
                    
                    gestureToggleRow(
                        icon: "return",
                        iconColor: .orange,
                        title: "Return / Enter ↵",
                        posture: "🤏 Quick pinch with left index finger & thumb to press Enter",
                        isOn: Binding(
                            get: { classifier.toggles.leftReturn },
                            set: { val in
                                classifier.toggles.leftReturn = val
                                classifier.saveToggles()
                            }
                        )
                    )
                    
                    gestureToggleRow(
                        icon: "doc.on.clipboard",
                        iconColor: .orange,
                        title: "Paste Clipboard (⌘V)",
                        posture: "✌️ Peace / V-sign (extend left index & middle fingers)",
                        isOn: Binding(
                            get: { classifier.toggles.leftShortcuts },
                            set: { val in
                                classifier.toggles.leftShortcuts = val
                                classifier.saveToggles()
                            }
                        )
                    )
                }
            }
            .padding(12)
            .background(Color.orange.opacity(0.04))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.15), lineWidth: 0.8))
            
            // Quick Presets Bar
            HStack(spacing: 8) {
                Button(action: {
                    withAnimation {
                        classifier.resetToDefaults()
                    }
                }) {
                    Text("🎯 Point & Click Only (Recommended)")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white.opacity(0.9))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    withAnimation {
                        classifier.toggles = GestureToggles(
                            airMouse: true,
                            leftClick: true,
                            clickAndDrag: true,
                            rightClick: true,
                            smoothScroll: true,
                            leftDictation: true,
                            leftReturn: true,
                            leftShortcuts: true
                        )
                        classifier.saveToggles()
                    }
                }) {
                    Text("⚡️ Enable All")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white.opacity(0.9))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    withAnimation {
                        classifier.toggles = GestureToggles(
                            airMouse: false,
                            leftClick: false,
                            clickAndDrag: false,
                            rightClick: false,
                            smoothScroll: false,
                            leftDictation: false,
                            leftReturn: false,
                            leftShortcuts: false
                        )
                        classifier.saveToggles()
                    }
                }) {
                    Text("🛑 Disable All")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white.opacity(0.7))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(white: 0.1, opacity: 0.6))
        .cornerRadius(12)
    }
    
    // MARK: - Toggle Row Item
    private func gestureToggleRow(
        icon: String,
        iconColor: Color,
        title: String,
        posture: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            // Icon Badge
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isOn.wrappedValue ? iconColor.opacity(0.18) : Color.white.opacity(0.05))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isOn.wrappedValue ? iconColor : Color.gray.opacity(0.6))
            }
            
            // Description & Posture
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(isOn.wrappedValue ? .white : .gray)
                    
                    if isOn.wrappedValue {
                        Text("ACTIVE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(iconColor)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(iconColor.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                
                Text(posture)
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.9))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Toggle Switch
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: iconColor))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isOn.wrappedValue ? Color.white.opacity(0.03) : Color.clear)
        .cornerRadius(8)
    }
}
