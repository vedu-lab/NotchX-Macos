import Foundation
import AppKit
import Combine
import SwiftUI

public enum ClipboardItemType: String, Codable {
    case text = "Text"
    case url = "Link"
    case code = "Code"
    case colorHex = "Color"
    
    public var iconName: String {
        switch self {
        case .text: return "doc.text"
        case .url: return "link"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .colorHex: return "paintpalette"
        }
    }
}

public struct ClipboardItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let content: String
    public let timestamp: Date
    public let itemType: ClipboardItemType
    public let characterCount: Int
    
    public init(id: UUID = UUID(), content: String, timestamp: Date = Date(), itemType: ClipboardItemType, characterCount: Int) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.itemType = itemType
        self.characterCount = characterCount
    }
    
    public var previewTitle: String {
        let singleLine = content.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespaces) ?? content
        return singleLine.isEmpty ? "Empty Snippet" : singleLine
    }
    
    public var relativeTime: String {
        let seconds = Int(Date().timeIntervalSince(timestamp))
        if seconds < 60 { return "Just now" }
        let mins = seconds / 60
        if mins < 60 { return "\(mins)m ago" }
        let hours = mins / 60
        if hours < 24 { return "\(hours)h ago" }
        return "\(hours / 24)d ago"
    }
}

/// Central Clipboard Manager monitoring NSPasteboard changes in real-time
public class ClipboardManager: ObservableObject {
    public static let shared = ClipboardManager()
    
    @Published public var items: [ClipboardItem] = []
    @Published public var searchText: String = ""
    @Published public var copiedAlertID: UUID? = nil
    
    private var lastChangeCount: Int = -1
    private var pollTimer: Timer?
    private let defaults = UserDefaults.standard
    
    private init() {
        loadHistory()
        lastChangeCount = NSPasteboard.general.changeCount
        
        // Lightweight polling for pasteboard changes (1.6s interval)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.6, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }
    
    deinit {
        pollTimer?.invalidate()
    }
    
    private func loadHistory() {
        if let data = defaults.data(forKey: "notchx.clipboardHistory"),
           let saved = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            self.items = saved
        }
    }
    
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: "notchx.clipboardHistory")
        }
    }
    
    public func checkPasteboard() {
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        
        guard let str = NSPasteboard.general.string(forType: .string) else { return }
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Avoid duplicate of most recent item
        if let first = items.first, first.content == trimmed {
            return
        }
        
        // Determine type
        let type: ClipboardItemType
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            type = .url
        } else if trimmed.hasPrefix("#") && (trimmed.count == 7 || trimmed.count == 9) {
            type = .colorHex
        } else if trimmed.contains("func ") || trimmed.contains("class ") || trimmed.contains("const ") || trimmed.contains("let ") || trimmed.contains("var ") || trimmed.contains("import ") {
            type = .code
        } else {
            type = .text
        }
        
        let newItem = ClipboardItem(
            content: trimmed,
            itemType: type,
            characterCount: trimmed.count
        )
        
        DispatchQueue.main.async {
            self.items.insert(newItem, at: 0)
            if self.items.count > 35 {
                self.items.removeLast()
            }
            self.saveHistory()
        }
    }
    
    public func copyItem(_ item: ClipboardItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.content, forType: .string)
        lastChangeCount = NSPasteboard.general.changeCount
        
        AuralHapticsManager.shared.play(.mechanicalClick, haptic: .generic)
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
            self.copiedAlertID = item.id
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if self.copiedAlertID == item.id {
                withAnimation { self.copiedAlertID = nil }
            }
        }
    }
    
    public func deleteItem(id: UUID) {
        items.removeAll { $0.id == id }
        saveHistory()
        AuralHapticsManager.shared.play(.tock, haptic: .alignment)
    }
    
    public func clearAll() {
        items.removeAll()
        saveHistory()
        AuralHapticsManager.shared.play(.mechanicalClick, haptic: .levelChange)
    }
    
    public var filteredItems: [ClipboardItem] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return items }
        return items.filter { $0.content.lowercased().contains(q) }
    }
}
