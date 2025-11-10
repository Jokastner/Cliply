import AppKit
import SwiftUI
import Combine

extension NSImage {
	func pngData() -> Data? {
		guard let tiffData = self.tiffRepresentation,
			  let bitmapImage = NSBitmapImageRep(data: tiffData) else {
			return nil
		}
		return bitmapImage.representation(using: .png, properties: [:])
	}
}

class ClipboardManager: ObservableObject {
	static let shared = ClipboardManager()
	
	@Published var history: [ClipboardItem] = []
	private let maxHistoryItems = 100
	
	private init() {
		loadHistory()
	}
	
	func saveClipboardContent() {
		let pasteboard = NSPasteboard.general
		
		var content: String = ""
		var contentType: ClipboardContentType = .plainText
		var rawData: Data?
		var attributedStringFromPasteboard: NSAttributedString? = nil
		
		// Priority order: Images > PDF > TIFF > File URLs > HTML > RTF > Plain Text
		
		// 1. Check for images (PNG, JPEG, TIFF, etc.)
		// Try to get image from pasteboard using NSImage
		if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
			// Try PNG first (most compatible)
			if let pngData = image.pngData() {
				rawData = pngData
				contentType = .image(pngData)
				content = "🖼️ Image (PNG)"
			} else if let tiffData = image.tiffRepresentation {
				rawData = tiffData
				contentType = .tiff(tiffData)
				content = "🖼️ Image (TIFF)"
			}
		} else if let imageData = pasteboard.data(forType: .png) {
			rawData = imageData
			contentType = .image(imageData)
			content = "🖼️ Image (PNG)"
		} else if let imageData = pasteboard.data(forType: .tiff) {
			rawData = imageData
			contentType = .tiff(imageData)
			content = "🖼️ Image (TIFF)"
		}
		// 2. Check for PDF
		else if let pdfData = pasteboard.data(forType: .pdf) {
			rawData = pdfData
			contentType = .pdf(pdfData)
			content = "📄 PDF Document"
		}
		// 3. Check for file URLs
		else if let urlString = pasteboard.string(forType: .fileURL),
				let url = URL(string: urlString) {
			// Store the URL string as data for consistency
			if let urlData = urlString.data(using: .utf8) {
				rawData = urlData
				contentType = .fileURL(urlData)
				content = "📁 \(url.lastPathComponent)"
			}
		}
		// 4. Try HTML (preserves hyperlinks and rich formatting)
		else if let htmlData = pasteboard.data(forType: .html) {
			rawData = htmlData
			contentType = .html(htmlData)
			
			// Try to read as NSAttributedString directly from pasteboard (preserves images)
			// This is the key: readObjects preserves attachments/images that might be in the pasteboard
			attributedStringFromPasteboard = pasteboard.readObjects(forClasses: [NSAttributedString.self], options: nil)?.first as? NSAttributedString
			if let attributedString = attributedStringFromPasteboard {
				content = attributedString.string
			} else {
				// Fallback: parse HTML data directly
				var documentAttributes: NSDictionary?
				if let attributedString = NSAttributedString(html: htmlData, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: &documentAttributes) {
					content = attributedString.string
				}
			}
		}
		// 5. Try RTF (preserves rich text formatting)
		else if let rtfData = pasteboard.data(forType: .rtf) {
			rawData = rtfData
			contentType = .rtf(rtfData)
			
			// Try to read as NSAttributedString directly from pasteboard (preserves images)
			attributedStringFromPasteboard = pasteboard.readObjects(forClasses: [NSAttributedString.self], options: nil)?.first as? NSAttributedString
			if let attributedString = attributedStringFromPasteboard {
				content = attributedString.string
			} else {
				// Fallback: parse RTF data directly
				var documentAttributes: NSDictionary?
				if let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: &documentAttributes) {
					content = attributedString.string
				}
			}
		}
		// 6. Fall back to plain text
		else if let string = pasteboard.string(forType: .string), !string.isEmpty {
			content = string
			contentType = .plainText
			rawData = nil
		}
		
		guard !content.isEmpty else {
			return
		}
		
		// For HTML/RTF, extract RTFD data to preserve images
		// Use the attributed string we already read from pasteboard (if available)
		var attributedStringData: Data? = nil
		
		// Convert to RTFD format to preserve images/attachments
		if let attributedString = attributedStringFromPasteboard {
			attributedStringData = try? attributedString.data(from: NSRange(location: 0, length: attributedString.length),
															 documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
		}
		
		// Avoid duplicates - check if the latest unpinned item has the same content or data
		// (since new items are inserted after pinned items)
		let pinnedCount = history.filter { $0.isPinned }.count
		if pinnedCount < history.count {
			let lastUnpinnedItem = history[pinnedCount]
			// Check both raw data and attributed string data for HTML/RTF
			if let lastAttributedData = lastUnpinnedItem.attributedStringData, let currentAttributedData = attributedStringData {
				if lastAttributedData == currentAttributedData {
					return
				}
			} else if let lastRawData = lastUnpinnedItem.rawData, let currentRawData = rawData {
				if lastRawData == currentRawData {
					return
				}
			} else if lastUnpinnedItem.content == content && lastUnpinnedItem.contentType == contentType {
				return
			}
		}
		
		let item = ClipboardItem(content: content, timestamp: Date(), contentType: contentType, rawData: rawData, attributedStringData: attributedStringData)
		// Always insert after all pinned items (pinnedCount already calculated above)
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
		
		// Restore content with original formatting/data
		switch item.contentType {
		case .image(let imageData):
			// Set image data to pasteboard
			// Try PNG first
			pasteboard.setData(imageData, forType: .png)
			// Also set as TIFF for compatibility
			if let nsImage = NSImage(data: imageData) {
				if let tiffData = nsImage.tiffRepresentation {
					pasteboard.setData(tiffData, forType: .tiff)
				}
			}
			// Set plain text fallback
			pasteboard.setString(item.content, forType: .string)
		case .tiff(let tiffData):
			pasteboard.setData(tiffData, forType: .tiff)
			pasteboard.setString(item.content, forType: .string)
		case .pdf(let pdfData):
			pasteboard.setData(pdfData, forType: .pdf)
			pasteboard.setString(item.content, forType: .string)
		case .fileURL(let urlData):
			// Restore file URL
			if let urlString = String(data: urlData, encoding: .utf8) {
				pasteboard.setString(urlString, forType: .fileURL)
				pasteboard.setString(item.content, forType: .string)
			}
		case .html(let htmlData):
			// If we have RTFD data with attachments, use that to preserve images
			if let rtfdData = item.attributedStringData,
			   let attributedString = try? NSAttributedString(data: rtfdData, options: [.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil) {
				// Use writeObjects to properly handle RTFD with attachments
				// This is the key method that preserves images in HTML/RTF
				pasteboard.writeObjects([attributedString])
				
				// Also explicitly set HTML and RTF formats for compatibility
				if let htmlOutputData = try? attributedString.data(from: NSRange(location: 0, length: attributedString.length),
																   documentAttributes: [.documentType: NSAttributedString.DocumentType.html,
																					   .characterEncoding: String.Encoding.utf8.rawValue]) {
					pasteboard.setData(htmlOutputData, forType: .html)
				} else {
					// Fallback to original HTML data
					pasteboard.setData(htmlData, forType: .html)
				}
				
				// Set RTF version
				if let rtfData = try? attributedString.data(from: NSRange(location: 0, length: attributedString.length),
															documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
					pasteboard.setData(rtfData, forType: .rtf)
				}
			} else {
				// Fallback: use original HTML data without images
				pasteboard.setData(htmlData, forType: .html)
				// Also set RTF and plain text as fallbacks
				if let attributedString = NSAttributedString(html: htmlData, documentAttributes: nil) {
					if let rtfData = try? attributedString.data(from: NSRange(location: 0, length: attributedString.length),
																documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
						pasteboard.setData(rtfData, forType: .rtf)
					}
				}
				pasteboard.setString(item.content, forType: .string)
			}
		case .rtf(let rtfData):
			// If we have RTFD data with attachments, use that to preserve images
			if let rtfdData = item.attributedStringData,
			   let attributedString = try? NSAttributedString(data: rtfdData, options: [.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil) {
				// Use writeObjects to properly handle RTFD with attachments
				// This is the key method that preserves images in RTF
				pasteboard.writeObjects([attributedString])
				
				// Also explicitly set RTF format for compatibility
				if let rtfOutputData = try? attributedString.data(from: NSRange(location: 0, length: attributedString.length),
																  documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
					pasteboard.setData(rtfOutputData, forType: .rtf)
				} else {
					// Fallback to original RTF data
					pasteboard.setData(rtfData, forType: .rtf)
				}
			} else {
				// Fallback: use original RTF data without images
				pasteboard.setData(rtfData, forType: .rtf)
				pasteboard.setString(item.content, forType: .string)
			}
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
			isPinned: !item.isPinned,
			rawData: item.rawData,
			attributedStringData: item.attributedStringData
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
	case image(Data)
	case fileURL(Data) // NSURL pasteboard type
	case pdf(Data)
	case tiff(Data)
	
	var displayName: String {
		switch self {
		case .plainText:
			return "Text"
		case .rtf:
			return "Rich Text"
		case .html:
			return "HTML"
		case .image:
			return "Image"
		case .fileURL:
			return "File URL"
		case .pdf:
			return "PDF"
		case .tiff:
			return "TIFF"
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
		case .image:
			return Color.orange.opacity(0.2)
		case .fileURL:
			return Color.purple.opacity(0.2)
		case .pdf:
			return Color.red.opacity(0.2)
		case .tiff:
			return Color.yellow.opacity(0.2)
		}
	}
}

struct ClipboardItem: Identifiable, Codable, Equatable, Hashable {
	let id: UUID
	let content: String // Preview/fallback text representation
	let rawData: Data? // Raw data for non-text content types
	let attributedStringData: Data? // RTFD data with attachments for HTML/RTF
	let timestamp: Date
	let contentType: ClipboardContentType
	var isPinned: Bool
	
	init(content: String, timestamp: Date, contentType: ClipboardContentType = .plainText, isPinned: Bool = false, rawData: Data? = nil, attributedStringData: Data? = nil) {
		self.id = UUID()
		self.content = content
		self.timestamp = timestamp
		self.contentType = contentType
		self.isPinned = isPinned
		self.rawData = rawData
		self.attributedStringData = attributedStringData
	}
	
	var preview: String {
		switch contentType {
		case .plainText, .rtf, .html:
			let maxLength = 100
			if content.count > maxLength {
				return String(content.prefix(maxLength)) + "..."
			}
			return content
		case .image:
			return "🖼️ Image"
		case .fileURL:
			if let urlString = String(data: rawData ?? Data(), encoding: .utf8),
			   let url = URL(string: urlString) {
				return "📁 \(url.lastPathComponent)"
			}
			return "📁 File URL"
		case .pdf:
			return "📄 PDF Document"
		case .tiff:
			return "🖼️ TIFF Image"
		}
	}
	
	var formattedTimestamp: String {
		let formatter = RelativeDateTimeFormatter()
		formatter.unitsStyle = .abbreviated
		return formatter.localizedString(for: timestamp, relativeTo: Date())
	}
	
	var characterCount: Int? {
		if case .plainText = contentType {
			return content.count
		}
		return nil
	}
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}
}
