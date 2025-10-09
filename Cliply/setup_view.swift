import SwiftUI
import Carbon

struct SetupView: View {
    @State private var saveKeyDisplay = "⌘ C ⌘ C"
    @State private var showKeyDisplay = "⌘ ^ V"
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            HStack{
                Image(systemName: "doc.on.clipboard.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                            
                            Text("Welcome to Clipboard Manager")
                                .font(.title)
                                .fontWeight(.bold)
            }
            
            
            Text("Set up your hotkeys to manage clipboard history")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 15) {
                HotKeyRow(
                    title: "Save to History",
                    description: "Double-tap Cmd+C to save current clipboard",
                    keyDisplay: $saveKeyDisplay,
                    defaultKey: "⌘ C ⌘ C"
                )
                
                Divider()
                
                HotKeyRow(
                    title: "Show History",
                    description: "Press this hotkey to view and select from history",
                    keyDisplay: $showKeyDisplay,
                    defaultKey: "⌘ ^ V"
                )
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            
            Spacer()
            
            HStack {
                Button("Use Defaults") {
                    saveDefaults()
                    completeSetup()
                }
                
                Spacer()
                
                Button("Continue") {
                    completeSetup()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top)
        }
        .padding(30)
        .frame(width: 500, height: 400)
    }
    
    private func saveDefaults() {
        // Save hotkey is now handled by double-tap detection, no settings needed
        
        // Default: Cmd + Control + V
        UserDefaults.standard.set(Int(cmdKey | controlKey), forKey: "showModifiers")
        UserDefaults.standard.set(Int(kVK_ANSI_V), forKey: "showKeyCode")
    }
    
    private func completeSetup() {
        saveDefaults()
        UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
        HotKeyManager.shared.registerHotKeys()
        dismiss()
    }
}

// Reuse the same view for preferences, just with different title/button
struct PreferencesView: View {
    @State private var saveKeyDisplay = "⌘ C ⌘ C"
    @State private var showKeyDisplay = "⌘ ^ V"
    @ObservedObject var clipboardManager = ClipboardManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            HStack{
                Image(systemName: "doc.on.clipboard.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Preferences")
                                .font(.title)
                                .fontWeight(.bold)
            }
            
            
            VStack(alignment: .leading, spacing: 15) {
                HotKeyRow(
                    title: "Save to History",
                    description: "Double-tap Cmd+C to save current clipboard",
                    keyDisplay: $saveKeyDisplay,
                    defaultKey: "⌘ C ⌘ C"
                )
                
                Divider()
                
                HotKeyRow(
                    title: "Show History",
                    description: "Press this hotkey to view and select from history",
                    keyDisplay: $showKeyDisplay,
                    defaultKey: "⌘ ^ V"
                )
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clipboard History")
                        .font(.headline)
                    Text("\(clipboardManager.history.count) items saved")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Clear History", role: .destructive) {
                    showClearConfirmation()
                }
                .controlSize(.small)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            
            Spacer()
        }
        .padding(30)
        .frame(width: 500, height: 400)
    }
    
    private func showClearConfirmation() {
        let alert = NSAlert()
        alert.messageText = "Clear Clipboard History?"
        alert.informativeText = "This will permanently delete all \(clipboardManager.history.count) clipboard history items."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            clipboardManager.clearHistory()
        }
    }
}

struct HotKeyRow: View {
    let title: String
    let description: String
    @Binding var keyDisplay: String
    let defaultKey: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                Text(keyDisplay)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview{SetupView()}
