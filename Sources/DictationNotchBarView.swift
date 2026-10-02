import SwiftUI
import Cocoa

// MARK: - Dictation Notch Bar Status
public enum DictationBarStatus: Equatable {
    case error(message: String)
    case retrying
    case success(text: String)
}

// MARK: - Dictation Notch State Manager
public class DictationNotchState: ObservableObject {
    public static let shared = DictationNotchState()
    
    @Published public var status: DictationBarStatus = .error(message: "Transcription Failed")
    @Published public var isVisible: Bool = false
    
    private var autoDismissTimer: Timer?
    
    private init() {}
    
    public func showError(message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.autoDismissTimer?.invalidate()
            self.autoDismissTimer = nil
            self.status = .error(message: message)
            self.isVisible = true
            NotchWindowController.shared.presentDictationBar(hasNotch: NotchWindowController.hasNotch())
        }
    }
    
    public func showRetrying() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.autoDismissTimer?.invalidate()
            self.autoDismissTimer = nil
            self.status = .retrying
        }
    }
    
    public func showSuccess(text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.autoDismissTimer?.invalidate()
            self.status = .success(text: text)
            self.autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                self?.dismiss()
            }
        }
    }
    
    public func dismiss() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.autoDismissTimer?.invalidate()
            self.autoDismissTimer = nil
            self.isVisible = false
            NotchWindowController.shared.dismissDictationBarOnly()
        }
    }
}

// MARK: - Liquid Glass Dictation Notch Bar View
public struct DictationNotchBarView: View {
    @ObservedObject var state = DictationNotchState.shared
    let hasNotch: Bool
    
    @State private var isSpinning: Bool = false
    
    let barWidth: CGFloat = 300.0
    let barHeight: CGFloat = 32.0
    
    var topRadius: CGFloat { hasNotch ? 0 : 10 }
    var bottomRadius: CGFloat { 10 }
    
    var borderColor: Color {
        switch state.status {
        case .error:
            return Color.orange.opacity(0.55)
        case .retrying:
            return Color.cyan.opacity(0.55)
        case .success:
            return Color.green.opacity(0.65)
        }
    }
    
    public init(hasNotch: Bool) {
        self.hasNotch = hasNotch
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            switch state.status {
            case .error(let msg):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.orange)
                
                Text(cleanErrorText(msg))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer(minLength: 4)
                
                // Retry Button
                Button(action: {
                    GroqWhisperManager.shared.retryLastDictation()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9.5, weight: .bold))
                        Text("Retry")
                            .font(.system(size: 10.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [Color.blue, Color.cyan.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                    )
                    .shadow(color: Color.blue.opacity(0.35), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                
                // Dismiss Cross Button
                Button(action: {
                    state.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
            case .retrying:
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.cyan)
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                    .animation(Animation.linear(duration: 1.0).repeatForever(autoreverses: false), value: isSpinning)
                    .onAppear { isSpinning = true }
                
                Text("Retrying transcription...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
                
                Spacer(minLength: 4)
                
                Button(action: {
                    state.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(.green)
                
                HStack(spacing: 3) {
                    Text("Copied to clipboard!")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                    Text("⌘V to paste")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .lineLimit(1)
                
                Spacer(minLength: 4)
                
                Button(action: {
                    state.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(width: barWidth, height: barHeight)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: topRadius,
                bottomLeadingRadius: bottomRadius,
                bottomTrailingRadius: bottomRadius,
                topTrailingRadius: topRadius
            )
            .fill(Color.black.opacity(0.88))
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: topRadius,
                bottomLeadingRadius: bottomRadius,
                bottomTrailingRadius: bottomRadius,
                topTrailingRadius: topRadius
            )
            .strokeBorder(borderColor, lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 10, x: 0, y: 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    private func cleanErrorText(_ raw: String) -> String {
        if raw.lowercased().contains("api key") {
            return "API Key Error"
        } else if raw.lowercased().contains("network") || raw.lowercased().contains("internet") || raw.lowercased().contains("timed out") {
            return "Connection Error"
        } else if raw.lowercased().contains("rate limit") || raw.contains("429") {
            return "Rate Limited"
        } else if raw.lowercased().contains("unauthorized") || raw.contains("401") {
            return "Unauthorized (401)"
        } else if raw.lowercased().contains("no speech") {
            return "No Speech Detected"
        }
        return raw.prefix(22) + (raw.count > 22 ? "…" : "")
    }
}
