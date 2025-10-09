import AppKit
import Combine

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    @Published var history: [ClipboardItem] = []
    private let maxHistoryItems = 100
    
    private init() {
        loadHistory()
    }
    
    func saveClipboardContent() {
        let pasteboard = NSPasteboard.general
        
        guard let string = pasteboard.string(forType: .string), !string.isEmpty else {
            return
        }
        
        // Avoid duplicates - check if the latest item is the same
        if let lastItem = history.first, lastItem.content == string {
            return
        }
        
        let item = ClipboardItem(content: string, timestamp: Date())
        history.insert(item, at: 0)
        
        // Limit history size
        if history.count > maxHistoryItems {
            history = Array(history.prefix(maxHistoryItems))
        }
        
        saveHistory()
    }
    
    func pasteContent(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
        
        
        // Check if we have accessibility permissions
        let trusted = AXIsProcessTrusted()
        if !trusted {
            // Just copy to clipboard if no accessibility permissions
            print("Do not have accessibility permissions, copying to clipboard instead.")
            return
        }
        // Return focus to the previous app and give it time to focus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                HotKeyManager.shared.returnToPreviousApp()
            }
        
        // Simulate paste command
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard let source = CGEventSource(stateID: .hidSystemState) else{
                print("Failed to create CGEventSource")
                return
            }
            
            // simulate Cmd+V
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            keyDown?.flags = .maskCommand
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
        
    }
    
    func deleteItem(_ item: ClipboardItem) {
        history.removeAll { $0.id == item.id }
        saveHistory()
    }
    
    func clearHistory() {
        history.removeAll()
        saveHistory()
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: "clipboardHistory")
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "clipboardHistory"),
           let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            history = decoded
        }
    }
}

struct ClipboardItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let content: String
    let timestamp: Date
    
    init(content: String, timestamp: Date) {
        self.id = UUID()
        self.content = content
        self.timestamp = timestamp
    }
    
    var preview: String {
        let maxLength = 100
        if content.count > maxLength {
            return String(content.prefix(maxLength)) + "..."
        }
        return content
    }
    
    var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    func hash(into hasher: inout Hasher) {
         hasher.combine(id)
     }
}
