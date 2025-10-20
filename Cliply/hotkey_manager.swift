import AppKit
import SwiftUI
import Carbon

class HotKeyManager: NSObject {
    static let shared = HotKeyManager()
    
    var clipboardManager: ClipboardManager?
    private var saveHotKeyRef: EventHotKeyRef?
    private var showHotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var previousApp: NSRunningApplication?
	private var historyWindow: NSWindow?
    
    // Double-tap detection for Cmd+C
    private var lastCmdCPressTime: Date?
    private let doubleTapInterval: TimeInterval = 0.5 // 500ms window
    
    private override init() {
		super.init()
		
        // Monitor Cmd+C globally
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        // Check if it's Cmd+C (key code 8 is 'C', maskCommand is Cmd key)
        if event.keyCode == 8 && event.modifierFlags.contains(.command) {
            let now = Date()
            
            if let lastPress = lastCmdCPressTime {
                let timeSinceLastPress = now.timeIntervalSince(lastPress)
                
                // Double-tap detected!
                if timeSinceLastPress < doubleTapInterval {
                    saveClipboard()
                    lastCmdCPressTime = nil // Reset to prevent triple-tap
                    return
                }
            }
            
            // Record this press time
            lastCmdCPressTime = now
        }
    }
    
    func registerHotKeys() {
        // Unregister existing hotkeys
        unregisterHotKeys()
        
        // Get hotkey settings from UserDefaults
        let showModifiers = UserDefaults.standard.integer(forKey: "showModifiers")
        let showKeyCode = UserDefaults.standard.integer(forKey: "showKeyCode")
        
        // Use defaults if not set
        let finalShowModifiers = showModifiers != 0 ? UInt32(showModifiers) : UInt32(cmdKey | controlKey)
        let finalShowKeyCode = showKeyCode != 0 ? UInt32(showKeyCode) : UInt32(kVK_ANSI_V)
        
        // Setup event handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, userData) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData!).takeUnretainedValue()
            
            if hotKeyID.id == 2 {
                manager.showClipboardHistory()
            }
            
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        
        // Register show hotkey only (save is handled by double-tap detection)
        let showHotKeyID = EventHotKeyID(signature: OSType(0x53484F57), id: 2) // 'SHOW'
        RegisterEventHotKey(finalShowKeyCode, finalShowModifiers, showHotKeyID, GetApplicationEventTarget(), 0, &showHotKeyRef)
    }
    
    func unregisterHotKeys() {
        if let ref = saveHotKeyRef {
            UnregisterEventHotKey(ref)
            saveHotKeyRef = nil
        }
        if let ref = showHotKeyRef {
            UnregisterEventHotKey(ref)
            showHotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
    
    @objc func saveClipboard() {
        clipboardManager?.saveClipboardContent()
    }
    
	@objc func showClipboardHistory() {
		// Check if history window already exists and is visible
		if let existingWindow = historyWindow, existingWindow.isVisible {
			// Bring existing window to front instead of creating new one
			existingWindow.makeKeyAndOrderFront(nil)
			NSApp.activate(ignoringOtherApps: true)
			return
		}
		
		// Capture the currently active application before showing our window
		previousApp = NSWorkspace.shared.frontmostApplication
        
		DispatchQueue.main.async { [weak self] in
			guard let self = self else { return }
			
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Clipboard History"
            window.center()
            window.contentView = NSHostingView(rootView: ClipboardHistoryView(hotKeyManager: self))
            window.isReleasedWhenClosed = false
			window.restorationClass = nil
			
			// Set delegate to track when window closes
			window.delegate = self
			
			// Store reference to window
			self.historyWindow = window
			
			window.makeKeyAndOrderFront(nil)
			NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func returnToPreviousApp() {
        // Return focus to the previously active application
        if let app = previousApp {
            app.activate()
        }
    }
    
    deinit {
        unregisterHotKeys()
    }
}

// MARK: - NSWindowDelegate
extension HotKeyManager: NSWindowDelegate {
	func windowWillClose(_ notification: Notification) {
		// Clear the window reference when it closes
		if let window = notification.object as? NSWindow, window == historyWindow {
			historyWindow = nil
		}
	}
}
