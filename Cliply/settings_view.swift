import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            HotKeySettingsView()
                .tabItem {
                    Label("Hotkeys", systemImage: "keyboard")
                }
            
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 300)
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
    @State private var saveKeyDisplay = "⌘ ^ C"
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
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Clipboard Manager")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Version 1.0.0")
                .foregroundColor(.secondary)
            
            Text("A simple and efficient clipboard history manager")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview{SettingsView()}
