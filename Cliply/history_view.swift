import SwiftUI

struct ClipboardHistoryView: View {
	@ObservedObject var clipboardManager = ClipboardManager.shared
	@State private var searchText = ""
	@State private var selectedItem: ClipboardItem?
	@State private var hasAccessibilityPermission = AXIsProcessTrusted()
	@Environment(\.dismiss) private var dismiss
	var hotKeyManager: HotKeyManager?
	
	var filteredHistory: [ClipboardItem] {
		if searchText.isEmpty {
			return clipboardManager.history
		}
		return clipboardManager.history.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
	}
	
	var body: some View {
		VStack(spacing: 0) {
			AccessibilityPermissionBanner()
			
			// Search bar
			HStack {
				Image(systemName: "magnifyingglass")
					.foregroundColor(.secondary)
				TextField("Search clipboard history...", text: $searchText)
					.textFieldStyle(.plain)
				
				if !searchText.isEmpty {
					Button(action: { searchText = "" }) {
						Image(systemName: "xmark.circle.fill")
							.foregroundColor(.secondary)
					}
					.buttonStyle(.plain)
				}
			}
			.padding(12)
			.background(Color(NSColor.controlBackgroundColor))
			
			Divider()
			
			// History list
			if filteredHistory.isEmpty {
				VStack(spacing: 12) {
					Image(systemName: "doc.on.clipboard")
						.font(.system(size: 50))
						.foregroundColor(.secondary)
					Text(searchText.isEmpty ? "No clipboard history yet" : "No results found")
						.foregroundColor(.secondary)
					if searchText.isEmpty {
						Text("Press ⌘ ^ C to save clipboard content")
							.font(.caption)
							.foregroundColor(.secondary)
					}
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else {
				List(selection: $selectedItem) {
					ForEach(filteredHistory) { item in
						HStack{
							ClipboardItemRow(item: item)
								.tag(item)
								.onTapGesture(count: 2) {
									pasteItem(item)
								}
								.contextMenu {
									Button("Paste") {
										pasteItem(item)
									}
									Button("Copy") {
										copyItem(item)
									}
									Divider()
									Button("Delete", role: .destructive) {
										clipboardManager.deleteItem(item)
									}
								}
							
							
							Button(action: { clipboardManager.deleteItem(item) }) {
								Image(systemName: "xmark.circle.fill")
									.foregroundColor(.red)
							}
							.buttonStyle(.plain)
						}
					}
				}
				.listStyle(.inset)
			}
			
			Divider()
			
			// Footer
			HStack {
				Text("\(filteredHistory.count) items")
					.font(.caption)
					.foregroundColor(.secondary)
				
				Spacer()
				
				if selectedItem != nil {
					Button("Paste") {
						if let item = selectedItem {
							pasteItem(item)
						}
					}
					.buttonStyle(.borderedProminent)
					.controlSize(.small)
				}
				
				Button("Clear All") {
					showClearConfirmation()
				}
				.controlSize(.small)
			}
			.padding(12)
			.background(Color(NSColor.controlBackgroundColor))
		}
	}
	
	private func pasteItem(_ item: ClipboardItem) {
		
		clipboardManager.pasteContent(item)
		
		// Close the window
		if let window = NSApp.keyWindow {
			window.close()
		}
		
	}
	
	private func copyItem(_ item: ClipboardItem) {
		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		pasteboard.setString(item.content, forType: .string)
	}
	
	private func showClearConfirmation() {
		let alert = NSAlert()
		alert.messageText = "Clear Clipboard History?"
		alert.informativeText = "This will permanently delete all clipboard history items."
		alert.alertStyle = .warning
		alert.addButton(withTitle: "Clear")
		alert.addButton(withTitle: "Cancel")
		
		if alert.runModal() == .alertFirstButtonReturn {
			clipboardManager.clearHistory()
		}
	}
}

struct ClipboardItemRow: View {
	let item: ClipboardItem
	
	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text(item.preview)
				.lineLimit(3)
				.font(.system(.body, design: .default))
			
			HStack {
				// Content type badge
				Text(item.contentType.displayName)
					.font(.caption2)
					.padding(.horizontal, 6)
					.padding(.vertical, 2)
					.background(item.contentType.badgeColor)
					.cornerRadius(4)
				
				Text(item.formattedTimestamp)
					.font(.caption)
					.foregroundColor(.secondary)
				
				Spacer()
				
				Text("\(item.content.count) characters")
					.font(.caption)
					.foregroundColor(.secondary)
			}
		}
		.padding(.vertical, 4)
	}
}
