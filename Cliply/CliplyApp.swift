//
//  CliplyApp.swift
//  Cliply
//
//  Created by Zhou Li on 10/3/25.
//

import SwiftUI
import Carbon

@main
struct CliplyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
        
        WindowGroup("Setup", id: "setup") {
                    SetupView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var clipboardManager: ClipboardManager?
    var hotKeyManager: HotKeyManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon and run as menu bar app
        NSApp.setActivationPolicy(.accessory)
        
        // Setup menu bar icon
        setupMenuBar()
        
        // Check and request accessibility permissions
        checkAccessibilityPermissions()
        
        // Initialize managers
        clipboardManager = ClipboardManager.shared
        hotKeyManager = HotKeyManager.shared
        hotKeyManager?.clipboardManager = clipboardManager
        
        // Check if first launch
        if !UserDefaults.standard.bool(forKey: "hasCompletedSetup") {
            DispatchQueue.main.async {
                    NSApp.sendAction(Selector(("showSetupWindow:")), to: nil, from: nil)
                }
        } else {
            // Register hotkeys with saved preferences
            hotKeyManager?.registerHotKeys()
        }
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Cliply! Your clipboard is always in sync!")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show History", action: #selector(showHistory), keyEquivalent: "h"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
    @objc func openSettings() {
            // Reuse the setup view as settings/preferences
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            settingsWindow.title = "Preferences"
            settingsWindow.center()
            settingsWindow.contentView = NSHostingView(rootView: SetupView())
            settingsWindow.isReleasedWhenClosed = false
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    
    @objc func showHistory() {
        hotKeyManager?.showClipboardHistory()
    }
    
    func checkAccessibilityPermissions() {
            let trusted = AXIsProcessTrusted()
            if !trusted {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "Clipboard Manager needs accessibility permissions to monitor hotkeys.\n\nPlease:\n1. Click 'Open System Settings'\n2. Enable Clipboard Manager in Accessibility\n3. Restart the app"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Later")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    // Open System Settings to Accessibility pane
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
}
