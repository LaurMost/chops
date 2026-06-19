import SwiftUI

/// Settings for the source-of-truth directory used when symlinking library items.
struct LibrarySettingsView: View {
    @AppStorage("sotDir") private var sotDir = FileManager.default.homeDirectoryForCurrentUser.path + "/.chops"
    @AppStorage("editorFontSize") private var editorFontSize = Double(EditorTheme.defaultEditorFontSize)

    /// Tools that are installed and actually have a plugin cache to scan.
    private var eligiblePluginTools: [ToolSource] {
        ChopsSettings.pluginCapableTools.filter { $0.isInstalled && $0.hasPluginCache }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Editor")
                    .font(.headline)
                Stepper(
                    value: $editorFontSize,
                    in: Double(EditorTheme.minEditorFontSize) ... Double(EditorTheme.maxEditorFontSize),
                    step: 1
                ) {
                    Text("Editor font size: \(Int(editorFontSize)) pt")
                }
                .accessibilityLabel("Editor font size")
                .accessibilityValue("\(Int(editorFontSize)) points")
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Plugin skills")
                    .font(.headline)
                Text("Plugin skills are installed by a tool's marketplace and are read-only. Enable a tool to list its plugin skills in the library.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if eligiblePluginTools.isEmpty {
                    Text("No plugin caches detected.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                } else {
                    VStack(spacing: 8) {
                        ForEach(eligiblePluginTools) { tool in
                            PluginToggleRow(tool: tool)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding()
    }

    private var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return sotDir.hasPrefix(home) ? "~" + sotDir.dropFirst(home.count) : sotDir
    }
}

/// A single per-tool plugin-scanning toggle, backed by its own UserDefaults key.
private struct PluginToggleRow: View {
    let tool: ToolSource
    @AppStorage private var enabled: Bool

    init(tool: ToolSource) {
        self.tool = tool
        _enabled = AppStorage(wrappedValue: false, ChopsSettings.pluginDefaultsKey(for: tool))
    }

    var body: some View {
        Toggle(isOn: $enabled) {
            Label {
                Text(tool.displayName)
            } icon: {
                ToolIcon(tool: tool, size: 14)
            }
        }
        .onChange(of: enabled) {
            NotificationCenter.default.post(name: .customScanPathsChanged, object: nil)
        }
    }
}

private struct DirectoryPickerRow: View {
    let label: String
    @Binding var path: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                Text(displayPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button("Choose...") {
                pickDirectory()
            }
        }
    }

    private var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.prompt = "Select"
        panel.directoryURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        path = url.path
    }
}
