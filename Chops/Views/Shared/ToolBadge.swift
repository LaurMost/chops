import SwiftUI

/// Small text badge for the metadata bar
struct ToolBadge: View {
    let tool: ToolSource
    @ScaledMetric(relativeTo: .caption2) private var fontSize: CGFloat = 10

    var body: some View {
        Text(tool.shortLabel)
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
            .accessibilityLabel(tool.displayName)
    }
}

/// Icon for the sidebar — uses custom logo asset or SF Symbol fallback.
///
/// Sizes scale with the user's text-size preference via `@ScaledMetric`. Pass
/// `decorative: true` when the icon sits inside a row that already exposes the
/// tool name as text, to avoid VoiceOver reading it twice.
struct ToolIcon: View {
    let tool: ToolSource
    var decorative: Bool = false
    @ScaledMetric private var size: CGFloat

    init(tool: ToolSource, size: CGFloat = 16, decorative: Bool = false) {
        self.tool = tool
        self.decorative = decorative
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    var body: some View {
        icon
            .accessibilityLabel(tool.displayName)
            .accessibilityHidden(decorative)
    }

    @ViewBuilder
    private var icon: some View {
        if let assetName = tool.logoAssetName {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: tool.iconName)
                .font(.system(size: size * 0.7))
                .frame(width: size, height: size)
        }
    }
}

extension ToolSource {
    var shortLabel: String {
        switch self {
        case .augment: "AU"
        case .claude: "CC"
        case .cursor: "CU"
        case .windsurf: "WS"
        case .codex: "CX"
        case .copilot: "CP"
        case .aider: "AI"
        case .amp: "AM"
        case .hermes: "HE"
        case .openclaw: "OC"
        case .opencode: "OP"
        case .pi: "PI"
        case .agents: "AG"
        case .antigravity: "AV"
        case .claudeDesktop: "CD"
        case .custom: "?"
        }
    }
}
