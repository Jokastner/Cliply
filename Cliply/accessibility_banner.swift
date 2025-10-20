import SwiftUI

struct AccessibilityPermissionBanner: View {
    @State private var hasAccessibilityPermission = AXIsProcessTrusted()
    
    var body: some View {
        Group {
            if !hasAccessibilityPermission {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Accessibility Permission Required")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Hotkeys and auto-paste won't work without accessibility permissions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Open Settings") {
                            openAccessibilitySettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    
                    Divider()
                        .padding(.top, 8)
                }
                .onAppear {
                    checkAccessibilityPermission()
                }
				.onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
					// Re-check permission when app becomes active (user might have changed settings)
					let previousState = hasAccessibilityPermission
					checkAccessibilityPermission()
					
					// If permission was just granted, re-register hotkeys
					if !previousState && hasAccessibilityPermission {
						HotKeyManager.shared.registerHotKeys()
					}
                }
			}
			
        }
    }
    
    private func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }
    
    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
