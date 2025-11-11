import SwiftUI

// Preference key to track visible items with their frames
struct VisibleItemFramePreference: PreferenceKey {
	static var defaultValue: [Int: CGRect] = [:]
	static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
		value.merge(nextValue()) { (_, new) in new }
	}
}

struct ClipboardHistoryView: View {
	@ObservedObject var clipboardManager = ClipboardManager.shared
	@State private var searchText = ""
	@FocusState private var focusedIndex: Int?
	@State private var selectedIndex: Int = 0
	@State private var hasAccessibilityPermission = AXIsProcessTrusted()
	@State private var visibleItemFrames: [Int: CGRect] = [:]
	@Environment(\.dismiss) private var dismiss
	var hotKeyManager: HotKeyManager?
	
	private enum MoveDirection {
		case up
		case down
	}
	
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
			.focused($focusedIndex,equals: -1)
			.onKeyPress(.downArrow, action: {
				if filteredHistory.isEmpty {
					return .ignored
				}
				selectedIndex=0
				focusedIndex=0
				return .handled
			})
			
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
				
				ScrollViewReader { proxy in
					
					List {
						ForEach(filteredHistory.indices, id: \.self) { index in
							let item=filteredHistory[index]
							let disableMoveUp = index == 0 || (index > 0 && filteredHistory[index - 1].isPinned != item.isPinned)
							let disableMoveDown = index == filteredHistory.count - 1 || (index < filteredHistory.count - 1 && filteredHistory[index + 1].isPinned != item.isPinned)
							
							HStack(spacing: 16) {
								// Move and pin controls
								HistoryItemControlColumn(
									item: item,
									isMoveUpDisabled: disableMoveUp,
									isMoveDownDisabled: disableMoveDown,
									onMoveUp: { handleMoveItem(.up, item:item) },
									onMoveDown: { handleMoveItem(.down, item:item) },
									onTogglePin: { handleTogglePin(item) }
								)
								
								ClipboardItemRow(item: item, shortcutIndex: index < 10 ? index : nil, isSelected: selectedIndex==index)
									.tag(item)
									.onTapGesture(count: 2) {
										pasteItem(item)
									}
									.onTapGesture {
										updateSelection(item)
									}
									.contextMenu {
										HistoryItemContextMenu(
											item: item,
											disablePinShortcut: index > 9,
											disableMoveUp: disableMoveUp,
											disableMoveDown: disableMoveDown,
											actions: .init(
												paste: { pasteItem(item) },
												copy: { copyItem(item) },
												togglePin: { handleTogglePin(item) },
												moveUp: { handleMoveItem(.up, item: item)},
												moveDown: { handleMoveItem(.down, item: item) },
												delete:{ clipboardManager.deleteItem(item) }
											)
										)
									}
								
								Spacer()
							}
							.id(index)
							.focusable()
							.focused($focusedIndex,equals: index)
							.background(
								GeometryReader { geometry in
									Color.clear
										.preference(
											key: VisibleItemFramePreference.self,
											value: [index: geometry.frame(in: .named("scrollView"))]
										)
								}
							)
							
						}
					}
					.listStyle(.inset)
					.coordinateSpace(name: "scrollView")
					.onAppear(){
						focusedIndex=0
					}
					.onPreferenceChange(VisibleItemFramePreference.self) { frames in
						visibleItemFrames = frames
					}
					.onChange(of: focusedIndex) { oldIndex, newIndex in
						
						if let index = newIndex {
							if index<0 || index>=filteredHistory.count { return }
							// Check if the focused item is visible
							// SwiftUI List only renders visible items, so if the item's frame
							// is in the dictionary, it's currently being rendered and likely visible.
							// We also check that the frame has reasonable coordinates (not off-screen)
							if let itemFrame = visibleItemFrames[index] {
								// Frame exists, check if it's within reasonable viewport bounds
								// For List items, frames are relative to the scroll position
								// If minY is negative or very large, the item is off-screen
								if itemFrame.minY >= 10 && itemFrame.minY <= 460 {
									// Item appears to be visible, don't scroll
									return
								}
							}
							// Item is not visible (not in frames dict or has invalid coordinates), scroll to it
							withAnimation {
								proxy.scrollTo(index, anchor: .center)
							}
						}
					}
					.onKeyPress{ keypress in
						if keypress.modifiers.contains(.option) {
							return handleOptionKeyPress(keypress)
						}
						return handleNavigationKeyPress(keypress.key)
					}
					
				}
				
				Divider()
				
				// Footer
				HStack {
					Text("\(filteredHistory.count) items")
						.font(.caption)
						.foregroundColor(.secondary)
					
					Spacer()
					
					Button("Clear All") {
						showClearConfirmation()
					}
					.controlSize(.small)
				}
				.padding(12)
				.background(Color(NSColor.controlBackgroundColor))
			}
				
		}
		.onKeyPress(.escape, action: {
			// Close the window
				  if let window = NSApp.keyWindow {
					  window.close()
				  }
				  return .handled
			  })
		
	}
	
	private func startSearch(){
		focusedIndex = -1
		selectedIndex = -1
	}
	
	private func pasteItem(_ item: ClipboardItem) {
		
		clipboardManager.pasteContent(item)
		
		// Close the window
		if let window = NSApp.keyWindow {
			window.close()
		}
		
	}
	
	private func copyItem(_ item: ClipboardItem) {
		// Use the same paste logic to copy to clipboard
		clipboardManager.pasteContent(item)
	}
	
	private func handleMoveItem(_ direction: MoveDirection, item: ClipboardItem) {
		Task { @MainActor in
			let moved: Int?
			switch direction {
			case .up:
				moved = clipboardManager.moveItemUp(item)
			case .down:
				moved = clipboardManager.moveItemDown(item)
			}
			
			if moved != nil {
				updateSelection(item)
			}
		}
	}
	
	private func updateSelection(_ item: ClipboardItem) {
		if let newFilteredIndex = filteredHistory.firstIndex(where: { $0.id == item.id }) {
			focusedIndex = newFilteredIndex
			selectedIndex = newFilteredIndex
		}
	}
	
	private func handleTogglePin(_ item: ClipboardItem) {
		Task{@MainActor in
			if clipboardManager.togglePin(item) != nil {
				updateSelection(item)
			}
		}
		
	}
		
	private func handleOptionKeyPress(_ event: KeyPress) -> KeyPress.Result {
		
		if self.filteredHistory.isEmpty || self.selectedIndex < 0 || self.selectedIndex >= self.filteredHistory.count {
			return .ignored
		}
		
		let item = filteredHistory[selectedIndex]
		
		if let char = event.characters.first,
		   let number = Int(String(char)),
		   number >= 0 && number <= 9,
		   number < filteredHistory.count {
			pasteItem(filteredHistory[number])
			return .handled
		}
		
		if event.characters.first == "s" {
			startSearch( )
			return .handled
		}
		
		if event.characters.first == "p" {
			handleTogglePin(item)
			return .handled
		}
		
		switch event.key {
		case .upArrow:
			handleMoveItem(.up, item: item)
			return .handled
		case .downArrow:
			handleMoveItem( .down, item: item)
			return .handled
		default:
			return .ignored
		}
	}
	
		
	private func handleNavigationKeyPress(_ key: KeyEquivalent) -> KeyPress.Result {
		
		
		if self.filteredHistory.isEmpty || self.selectedIndex < 0 || self.selectedIndex >= self.filteredHistory.count {
			return .ignored
		}
		
		let item = filteredHistory[selectedIndex]
		
		if key.character == "\u{8}" || key.character == "\u{7F}" {
			Task{
				@MainActor in
				clipboardManager.deleteItem(item)
			}
			
			return .handled
		}
		
		switch key {
		case .upArrow:
			selectedIndex-=1
			if selectedIndex < 0 {
				startSearch()
			}
			focusedIndex = selectedIndex
			return .handled
		case .downArrow:
			selectedIndex = min(filteredHistory.count - 1, selectedIndex + 1)
			focusedIndex = selectedIndex
			return .handled
		case .return:
			pasteItem(item)
			return .handled
		default:
			return .ignored
		}
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
	let shortcutIndex: Int? // Index for showing keyboard shortcut (0-9)
	let isSelected: Bool
	
	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			// Display content based on type
			switch item.contentType {
			case .image, .tiff:
				// Show image thumbnail
				if let rawData = item.rawData,
				   let nsImage = NSImage(data: rawData) {
					Image(nsImage: nsImage)
						.resizable()
						.aspectRatio(contentMode: .fit)
						.frame(maxWidth: 200, maxHeight: 80)
						.cornerRadius(6)
						.shadow(radius: 2)
						.overlay(
							RoundedRectangle(cornerRadius: 6)
								.stroke(Color.secondary.opacity(0.2), lineWidth: 1)
						)
				} else {
					Text(item.preview)
						.lineLimit(3)
						.font(.system(.body, design: .default))
						.foregroundColor(.secondary)
				}
			case .pdf, .fileURL:
				Text(item.preview)
					.lineLimit(2)
					.font(.system(.body, design: .default))
			default:
				Text(item.preview)
					.lineLimit(3)
					.font(.system(.body, design: .default))
			}
			
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
				
				// Only show character count for plain text
				if let charCount = item.characterCount {
					Text("\(charCount) characters")
						.font(.caption)
						.foregroundColor(.secondary)
				} else if let rawData = item.rawData {
					// Show data size for non-text content
					let size = ByteCountFormatter.string(fromByteCount: Int64(rawData.count), countStyle: .file)
					Text(size)
						.font(.caption)
						.foregroundColor(.secondary)
				}
				
				// Keyboard shortcut indicator (for first 10 items)
				if let shortcut = shortcutIndex, shortcut < 10 {
					Text("⌥\(shortcut)")
						.font(.system(size: 10, weight: .medium, design: .default))
						.foregroundColor(.secondary)
						.padding(.horizontal, 4)
						.padding(.vertical, 2)
						.background(Color.secondary.opacity(0.1))
						.cornerRadius(3)
				}
			}
		}
		//.background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
		.padding(.vertical, 4)
	}
}

struct HistoryItemControlColumn: View {
	let item: ClipboardItem
	let isMoveUpDisabled: Bool
	let isMoveDownDisabled: Bool
	let onMoveUp: () -> Void
	let onMoveDown: () -> Void
	let onTogglePin: () -> Void
	
	var body: some View {
		VStack(spacing: 2) {
			Button(action: onMoveUp) {
				Image(systemName: "arrow.up")
					.font(.system(size: 10, weight: .heavy))
			}
			.buttonStyle(.plain)
			.disabled(isMoveUpDisabled)
			.foregroundColor(isMoveUpDisabled ? .gray.opacity(0.3) : .primary)
			
			Button(action: onTogglePin) {
				Image(systemName: item.isPinned ? "pin.fill" : "pin")
					.font(.system(size: 12))
			}
			.buttonStyle(.plain)
			.foregroundColor(item.isPinned ? .orange : .primary)
			
			Button(action: onMoveDown) {
				Image(systemName: "arrow.down")
					.font(.system(size: 10, weight: .heavy))
			}
			.buttonStyle(.plain)
			.disabled(isMoveDownDisabled)
			.foregroundColor(isMoveDownDisabled ? .gray.opacity(0.3) : .primary)
		}
		.frame(width: 20)
	}
}

struct HistoryItemContextMenu: View {
	struct Actions {
		let paste: () -> Void
		let copy: () -> Void
		let togglePin: () -> Void
		let moveUp: () -> Void
		let moveDown: () -> Void
		let delete: () -> Void
	}
	
	let item: ClipboardItem
	let disablePinShortcut: Bool
	let disableMoveUp: Bool
	let disableMoveDown: Bool
	let actions: Actions
	
	@ViewBuilder
	var body: some View {
		Button("Paste            ", action: actions.paste)
		Button(action: actions.copy) {
			HStack {
				Text("Copy             ")
				Spacer()
				//Text("⌥C")
				//.foregroundColor(.secondary) // Optional: makes the shortcut hint look standard
			}
		}
		Divider()
		Button(
			item.isPinned ? "Unpin            " : "Pin                 ",
			action: actions.togglePin
		)
		.disabled(disablePinShortcut)
		
		Divider()
		Button("Move Up       (⌥↑)", action: actions.moveUp)
			.disabled(disableMoveUp)
		Button("Move Down  (⌥↓)", action: actions.moveDown)
			.disabled(disableMoveDown)
		Divider()
		Button("Delete            (Del)", role: .destructive, action: actions.delete)
	}
}

#Preview{ClipboardHistoryView()}
