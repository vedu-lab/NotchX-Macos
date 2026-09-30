import SwiftUI
import AppKit

/// Dedicated Clipboard Tab inside the NotchX overlay
public struct ClipboardTabView: View {
    @ObservedObject private var clipboard = ClipboardManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 8) {
            // Header Controls: Search bar + Clear All button
            HStack(spacing: 8) {
                // Search Input Field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                    
                    TextField("Search copied clips...", text: $clipboard.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                    
                    if !clipboard.searchText.isEmpty {
                        Button(action: { clipboard.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 0.6)
                )
                
                // Clear History Button
                if !clipboard.items.isEmpty {
                    Button(action: {
                        clipboard.clearAll()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                            Text("Clear")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("Clear Clipboard History")
                }
            }
            .padding(.horizontal, 16)
            
            // Clipboard List
            if clipboard.filteredItems.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 26))
                        .foregroundColor(.white.opacity(0.35))
                    Text(clipboard.searchText.isEmpty ? "Clipboard is empty" : "No matches found")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Text("Copy any text, URL, or code to see it here.")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 6) {
                        ForEach(clipboard.filteredItems) { item in
                            ClipboardRowView(item: item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// Single Clipboard Row Item
struct ClipboardRowView: View {
    let item: ClipboardItem
    @ObservedObject private var clipboard = ClipboardManager.shared
    @ObservedObject private var hover = ItemHoverState()
    
    var body: some View {
        Button(action: {
            clipboard.copyItem(item)
        }) {
            HStack(spacing: 10) {
                // Type Icon Badge
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(typeColor.opacity(0.20))
                        .frame(width: 26, height: 26)
                    Image(systemName: item.itemType.iconName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(typeColor)
                }
                
                // Content Preview
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.previewTitle)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(item.itemType.rawValue)
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(typeColor)
                        
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text(item.relativeTime)
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text("\(item.characterCount) chars")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                Spacer(minLength: 4)
                
                // Trailing Action Badge / Button
                if clipboard.copiedAlertID == item.id {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                        Text("Copied")
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.2))
                    .clipShape(Capsule())
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(hover.isHovered ? 0.9 : 0.45))
                        
                        Button(action: {
                            clipboard.deleteItem(id: item.id)
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                                .padding(3)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(hover.isHovered ? 0.12 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(hover.isHovered ? 0.20 : 0.10), lineWidth: 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hover.isHovered = $0 }
        .onDrag {
            NSItemProvider(object: item.content as NSString)
        }
    }
    
    private var typeColor: Color {
        switch item.itemType {
        case .text: return .blue
        case .url: return .purple
        case .code: return .green
        case .colorHex: return .orange
        }
    }
}
