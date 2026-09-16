import SwiftUI

// MARK: - Reusable Hand Skeleton Canvas View
public struct HandSkeletonCanvasView: View {
    public let hands: [HandSkeletonData]
    public let anchorType: String
    
    public init(hands: [HandSkeletonData], anchorType: String = "indexMCP", showGateLine: Bool = false) {
        self.hands = hands
        self.anchorType = anchorType
    }
    
    public var body: some View {
        Canvas { context, size in
            for hand in hands {
                let isIntentional = hand.isIntentional
                let color: Color = isIntentional ? (hand.isRightHand ? .cyan : .orange) : Color.gray.opacity(0.35)
                let glowColor: Color = isIntentional ? (hand.isRightHand ? Color.cyan.opacity(0.4) : Color.orange.opacity(0.4)) : Color.clear
                
                // Helper to transform normalized (0...1) camera coords to canvas coords
                func screenPt(_ pt: CGPoint) -> CGPoint {
                    let mx = 1.0 - pt.x // Mirror horizontally for natural webcam reflection
                    let my = 1.0 - pt.y // Vision Y is bottom-up (1.0 = top)
                    return CGPoint(x: mx * size.width, y: my * size.height)
                }
                
                let w = screenPt(hand.wrist)
                let tTip = screenPt(hand.thumbTip)
                let iTip = screenPt(hand.indexTip)
                let mTip = screenPt(hand.middleTip)
                let rTip = screenPt(hand.ringTip)
                let lTip = screenPt(hand.littleTip)
                
                let tIP = screenPt(hand.thumbIP)
                let iPIP = screenPt(hand.indexPIP)
                let mPIP = screenPt(hand.middlePIP)
                let rPIP = screenPt(hand.ringPIP)
                let lPIP = screenPt(hand.littlePIP)
                
                let tMP = screenPt(hand.thumbMP)
                let iMCP = screenPt(hand.indexMCP)
                let mMCP = screenPt(hand.middleMCP)
                let rMCP = screenPt(hand.ringMCP)
                let lMCP = screenPt(hand.littleMCP)
                
                let bones: [[CGPoint]] = [
                    [w, tMP, tIP, tTip],
                    [w, iMCP, iPIP, iTip],
                    [w, mMCP, mPIP, mTip],
                    [w, rMCP, rPIP, rTip],
                    [w, lMCP, lPIP, lTip],
                    [iMCP, mMCP, rMCP, lMCP]
                ]
                
                // Draw bone lines
                for bone in bones {
                    var path = Path()
                    path.addLines(bone)
                    if isIntentional {
                        context.stroke(path, with: .color(glowColor), lineWidth: 4.5)
                    }
                    context.stroke(path, with: .color(color), lineWidth: isIntentional ? 2 : 1)
                }
                
                // Draw joint nodes
                let allTips = [w, tTip, iTip, mTip, rTip, lTip, tIP, iPIP, mPIP, rPIP, lPIP, tMP, iMCP, mMCP, rMCP, lMCP]
                for node in allTips {
                    let radius: CGFloat = 3.0
                    let rect = CGRect(x: node.x - radius, y: node.y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(isIntentional ? .white : Color(white: 0.3)))
                    context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 1.0)
                }
                
                // Highlight active tracking anchor on Right Hand with a prominent pulse ring ONLY if intentional
                if hand.isRightHand && isIntentional {
                    let activeAnchorPt: CGPoint
                    switch anchorType {
                    case "indexTip": activeAnchorPt = iTip
                    case "indexMCP": activeAnchorPt = iMCP
                    default: activeAnchorPt = w
                    }
                    
                    let ringRect = CGRect(x: activeAnchorPt.x - 7, y: activeAnchorPt.y - 7, width: 14, height: 14)
                    context.stroke(Path(ellipseIn: ringRect), with: .color(.green), lineWidth: 2.0)
                }
            }
        }
    }
}
