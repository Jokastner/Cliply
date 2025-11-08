import SwiftUI
import Carbon

struct SettingsView: View {
    
    var body: some View {
        TabView {
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
            
            GeneralSettingsView()
                .tabItem {
                    Label("Preference", systemImage: "gearshape")
                }
            
        }
    }
}

struct GeneralSettingsView: View {
    @AppStorage("maxHistoryItems") private var maxHistoryItems = 100
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    
    var body: some View {
        Form {
            Section {
                Stepper("Maximum history items: \(maxHistoryItems)", value: $maxHistoryItems, in: 10...500, step: 10)
                Toggle("Launch at login", isOn: $launchAtLogin)
            }
            
            Section {
                Button("Clear History") {
                    ClipboardManager.shared.clearHistory()
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct HotKeySettingsView: View {
    @State private var saveKeyDisplay = "⌘ C ⌘ C"
    @State private var showKeyDisplay = "⌘ ^ V"
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Save to History:")
                    Spacer()
                    Text(saveKeyDisplay)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                }
                
                HStack {
                    Text("Show History:")
                    Spacer()
                    Text(showKeyDisplay)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            
            Section {
                Button("Reset to Defaults") {
                    resetToDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func resetToDefaults() {
        UserDefaults.standard.removeObject(forKey: "saveModifiers")
        UserDefaults.standard.removeObject(forKey: "saveKeyCode")
        UserDefaults.standard.removeObject(forKey: "showModifiers")
        UserDefaults.standard.removeObject(forKey: "showKeyCode")
        HotKeyManager.shared.registerHotKeys()
    }
}

struct AboutView: View {
    
    @State private var saveKeyDisplay = "⌘ C ⌘ C"
    @State private var showKeyDisplay = "⌘ ^ V"
    @State private var isRecordingHotkey = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            HStack {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                Text("Clipli")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Version 1.0.0")
                               .foregroundColor(.secondary)
            }
            
           
            
            Text("A simple and efficient clipboard history manager")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(spacing: 20) {
				
				// Accessibility permission warning banner
				AccessibilityPermissionBanner()
                              
                VStack( spacing: 15) {
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
                                        defaultKey: "⌘ ^ V",
                                        
                                    )
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                
                Spacer()
            }.padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    
    private func setupKeyMonitoring() {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if isRecordingHotkey {
                    recordHotkey(event)
                    return nil // Consume the event
                }
                return event
            }
        }

    private func recordHotkey(_ event: NSEvent) {
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let keyCode = event.keyCode
            
            // Require at least one modifier key
            guard modifiers.contains(.command) || modifiers.contains(.control) ||
                  modifiers.contains(.option) || modifiers.contains(.shift) else {
                return
            }
            
            // Build display string
            var displayString = ""
            if modifiers.contains(.command) { displayString += "⌘ " }
            if modifiers.contains(.control) { displayString += "^ " }
            if modifiers.contains(.option) { displayString += "⌥ " }
            if modifiers.contains(.shift) { displayString += "⇧ " }
            
            // Get the key character
            if let keyChar = event.charactersIgnoringModifiers?.uppercased() {
                displayString += keyChar
            }
            
            showKeyDisplay = displayString.trimmingCharacters(in: .whitespaces)
            
            // Save to UserDefaults
            var carbonModifiers: UInt32 = 0
            if modifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
            if modifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
            if modifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
            if modifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
            
            UserDefaults.standard.set(Int(carbonModifiers), forKey: "showModifiers")
            UserDefaults.standard.set(Int(keyCode), forKey: "showKeyCode")
            
            isRecordingHotkey = false
        }

}

struct HotKeyRow: View {
    let title: String
    let description: String
    @Binding var keyDisplay: String
    let defaultKey: String
    var showCustomizeButton: Bool = false
    var isRecording: Bool = false
    var onCustomize: () -> Void = {}
    
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
                    .background(isRecording ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isRecording ? Color.blue : Color.clear, lineWidth: 2)
                    )
                
                if showCustomizeButton {
                    Button(isRecording ? "Recording..." : "Customize") {
                        onCustomize()
                    }
                    .controlSize(.small)
                    .disabled(isRecording)
                }
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}


#Preview{SettingsView()}
