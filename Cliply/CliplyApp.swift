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
		WindowGroup("Setup", id: "setup") {
			SettingsView()
		}
		.defaultSize(width: 500, height: 400)
		.defaultPosition(.center)
	}
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
	var statusItem: NSStatusItem?
	var clipboardManager: ClipboardManager?
	var hotKeyManager: HotKeyManager?
	var settingsWindow: NSWindow?
	
	func applicationDidFinishLaunching(_ notification: Notification) {
		
		// Hide dock icon and run as menu bar app
		NSApp.setActivationPolicy(.accessory)
		
		// Setup menu bar icon
		setupMenuBar()
		
		// Initialize managers
		clipboardManager = ClipboardManager.shared
		hotKeyManager = HotKeyManager.shared
		hotKeyManager?.clipboardManager = clipboardManager
		
		// Register hotkeys with saved preferences
		hotKeyManager?.registerHotKeys()
		
	}
	
	func setupMenuBar() {
		statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
		if let button = statusItem?.button {
			// Try to load custom icon first, fallback to system icon
			if let customIcon = NSImage(named: "MenuBarIcon") {
				customIcon.isTemplate = true // Makes it adapt to light/dark mode
				customIcon.accessibilityDescription = "Clipli! Manage your clipboard with ease."
				button.image = customIcon
			} else {
				// Fallback to system icon
				button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipli! Manage your clipboard with ease.")
			}
			
			// Delay animation until menu bar is fully rendered
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
				self.animateMenuBarIcon(button: button)
			}
		}
		
		let menu = NSMenu()
		menu.addItem(NSMenuItem(title: "Show History", action: #selector(showHistory), keyEquivalent: "h"))
		menu.addItem(NSMenuItem.separator())
		menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
		menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
		statusItem?.menu = menu
	}
	
	private func animateMenuBarIcon(button: NSStatusBarButton) {
		// Ensure button has a layer
		button.wantsLayer = true
		guard let layer = button.layer else { return }
		
		// Animate to full opacity
		NSAnimationContext.runAnimationGroup({ context in
			context.duration = 0.5
			context.timingFunction = CAMediaTimingFunction(name: .easeOut)
			button.animator().alphaValue = 1.0
		})
		
		// Bounce scale animation
		let scaleAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
		scaleAnimation.values = [0.5, 1.2, 0.9, 1.05, 1.0]
		scaleAnimation.keyTimes = [0, 0.3, 0.5, 0.7, 1.0]
		scaleAnimation.duration = 1.6
		scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
		
		layer.add(scaleAnimation, forKey: "bounceScale")
		
	}
	
	@objc func openSettings() {
		// Check if settings window already exists and is visible
		if let existingWindow = settingsWindow, existingWindow.isVisible {
			// Bring existing window to front instead of creating new one
			existingWindow.makeKeyAndOrderFront(nil)
			NSApp.activate(ignoringOtherApps: true)
			return
		}
		
		// Reuse the setup view as settings/preferences
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
			styleMask: [.titled, .closable],
			backing: .buffered,
			defer: false
		)
		window.title = "Preferences"
		window.center()
		window.contentView = NSHostingView(rootView: SettingsView())
		window.isReleasedWhenClosed = false
		
		// Set delegate to track when window closes
		window.delegate = self
		
		// Store reference to window
		settingsWindow = window
		
		window.makeKeyAndOrderFront(nil)
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


// MARK: - NSWindowDelegate
extension AppDelegate {
	func windowWillClose(_ notification: Notification) {
		// Clear the window reference when it closes
		if let window = notification.object as? NSWindow {
			if window == settingsWindow {
				settingsWindow = nil
			}
		}
	}
}
