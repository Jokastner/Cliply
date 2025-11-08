import AppKit
import SwiftUI
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
		
		// Try to get RTF first, then fall back to plain text
		var content: String?
		var contentType: ClipboardContentType = .plainText
		
		// 1. Try HTML first (preserves hyperlinks and rich formatting)
		if let htmlData = pasteboard.data(forType: .html),
		   let attributedString = NSAttributedString(html: htmlData, documentAttributes: nil) {
			content = attributedString.string
			contentType = .html(htmlData)
		}
		// 2. Try RTF (preserves rich text formatting)
		else if let rtfData = pasteboard.data(forType: .rtf),
				let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
			content = attributedString.string
			contentType = .rtf(rtfData)
		}
		// 3. Fall back to plain text
		else if let string = pasteboard.string(forType: .string), !string.isEmpty {
			content = string
			contentType = .plainText
		}
		
		guard let finalContent = content, !finalContent.isEmpty else {
			return
		}
		
		// Avoid duplicates - check if the latest item is the same
		if let lastItem = history.first, lastItem.content == finalContent {
			return
		}
		
		let item = ClipboardItem(content: finalContent, timestamp: Date(), contentType: contentType)
		// Always insert after all pinned items
		let pinnedCount = history.filter { $0.isPinned }.count
		history.insert(item, at: pinnedCount)
		
		// Limit history size
		if history.count > maxHistoryItems {
			history = Array(history.prefix(maxHistoryItems))
		}
		
		saveHistory()
	}
	
	func pasteContent(_ item: ClipboardItem) {
		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		
		// Restore content with original formatting if available
		switch item.contentType {
		case .html(let htmlData):
			pasteboard.setData(htmlData, forType: .html)
			// Also set RTF and plain text as fallbacks
			if let attributedString = NSAttributedString(html: htmlData, documentAttributes: nil) {
				if let rtfData = try? attributedString.data(from: NSRange(location: 0, length: attributedString.length),
															documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
					pasteboard.setData(rtfData, forType: .rtf)
				}
			}
			pasteboard.setString(item.content, forType: .string)
		case .rtf(let rtfData):
			pasteboard.setData(rtfData, forType: .rtf)
			// Also set plain text as fallback
			pasteboard.setString(item.content, forType: .string)
		case .plainText:
			pasteboard.setString(item.content, forType: .string)
		}
		
		// Check if we have accessibility permissions
		let trusted = AXIsProcessTrusted()
		if !trusted {
			// Just copy to clipboard if no accessibility permissions
			// print("Do not have accessibility permissions, copying to clipboard instead.")
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
	
	func moveItemUp(_ item: ClipboardItem) -> Int? {
		guard let index = history.firstIndex(where: { $0.id == item.id }),
			  index > 0 else { return nil }
		
		// Pinned items can only move among other pinned items
		// Unpinned items can only move among other unpinned items
		let previousItem = history[index - 1]
		if previousItem.isPinned != item.isPinned {
			return nil
		}
		
		history.swapAt(index, index - 1)
		saveHistory()
		return index - 1
	}
	
	func moveItemDown(_ item: ClipboardItem) -> Int? {
		guard let index = history.firstIndex(where: { $0.id == item.id }),
			  index < history.count - 1 else { return nil }
		
		// Pinned items can only move among other pinned items
		// Unpinned items can only move among other unpinned items
		let nextItem = history[index + 1]
		if nextItem.isPinned != item.isPinned {
			return nil
		}
		
		history.swapAt(index, index + 1)
		saveHistory()
		return index + 1
	}
	
	func togglePin(_ item: ClipboardItem) -> Int? {
		guard let index = history.firstIndex(where: { $0.id == item.id }) else { return nil }
		
		// Create updated item with toggled pin status
		let updatedItem = ClipboardItem(
			content: item.content,
			timestamp: item.timestamp,
			contentType: item.contentType,
			isPinned: !item.isPinned
		)
		
		// Remove the item from its current position
		history.remove(at: index)
		
		if updatedItem.isPinned {
			// When pinning, move to top (after the last previously pinned item)
			let pinnedCount = history.filter { $0.isPinned }.count
			history.insert(updatedItem, at: pinnedCount)
			saveHistory()
			return pinnedCount
		} else {
			// When unpinning, move to top of unpinned items (after all pinned items)
			let pinnedCount = history.filter { $0.isPinned }.count
			history.insert(updatedItem, at: pinnedCount)
			saveHistory()
			return pinnedCount
		}
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

enum ClipboardContentType: Codable, Equatable {
	case plainText
	case rtf(Data)
	case html(Data)
	
	var displayName: String {
		switch self {
		case .plainText:
			return "Text"
		case .rtf:
			return "Rich Text"
		case .html:
			return "HTML"
		}
	}
	
	var badgeColor: Color {
		switch self {
		case .plainText:
			return Color.gray.opacity(0.2)
		case .rtf:
			return Color.blue.opacity(0.2)
		case .html:
			return Color.green.opacity(0.2)
		}
	}
}

struct ClipboardItem: Identifiable, Codable, Equatable, Hashable {
	let id: UUID
	let content: String
	let timestamp: Date
	let contentType: ClipboardContentType
	var isPinned: Bool
	
	init(content: String, timestamp: Date, contentType: ClipboardContentType = .plainText, isPinned: Bool = false) {
		self.id = UUID()
		self.content = content
		self.timestamp = timestamp
		self.contentType = contentType
		self.isPinned = isPinned
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
