//
//  SiteMapVisualization.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import SwiftUI

/// Interactive site map visualization using SwiftUI Canvas
struct SiteMapVisualization: View {
    let tree: SiteMapTree?
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var selectedNode: SiteNode?
    @State private var hoveredNode: SiteNode?
    
    private let nodeWidth: CGFloat = 180
    private let nodeHeight: CGFloat = 50
    private let horizontalSpacing: CGFloat = 40
    private let verticalSpacing: CGFloat = 80
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let tree = tree {
                    ScrollView([.horizontal, .vertical], showsIndicators: true) {
                        Canvas { context, size in
                            drawTree(tree, context: context, x: size.width / 2, y: 50, level: 0)
                        }
                        .frame(width: calculateTreeWidth(tree) + 200, height: calculateTreeHeight(tree) + 200)
                    }
                    .gesture(MagnificationGesture()
                        .onChanged { value in
                            scale = max(0.25, min(3.0, value))
                        }
                    )
                    .scaleEffect(scale)
                } else {
                    ContentUnavailableView(
                        "No Site Map",
                        systemImage: "map",
                        description: Text("Run a scrape to generate a site map visualization")
                    )
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if tree != nil {
                controlPanel
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let node = selectedNode {
                nodeDetailPanel(node: node)
            }
        }
    }
    
    // MARK: - Control Panel
    
    private var controlPanel: some View {
        VStack(spacing: 8) {
            Button(action: { scale = min(3.0, scale + 0.25) }) {
                Image(systemName: "plus.magnifyingglass")
            }
            
            Text("\(Int(scale * 100))%")
                .font(.caption)
                .monospacedDigit()
            
            Button(action: { scale = max(0.25, scale - 0.25) }) {
                Image(systemName: "minus.magnifyingglass")
            }
            
            Divider()
                .frame(width: 30)
            
            Button(action: { scale = 1.0 }) {
                Image(systemName: "1.magnifyingglass")
            }
            
            Button(action: { /* fit to view */ }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding()
    }
    
    // MARK: - Node Detail Panel
    
    private func nodeDetailPanel(node: SiteNode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: node.fileType.icon)
                    .foregroundStyle(colorForStatus(node.nodeStatus))
                
                Text(node.title ?? "Untitled")
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: { selectedNode = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Text(node.url)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            
            Divider()
            
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("Status")
                        .foregroundStyle(.secondary)
                    Text(node.nodeStatus.rawValue)
                        .foregroundStyle(colorForStatus(node.nodeStatus))
                }
                
                GridRow {
                    Text("Depth")
                        .foregroundStyle(.secondary)
                    Text("\(node.depth)")
                }
                
                if let statusCode = node.statusCode {
                    GridRow {
                        Text("HTTP")
                            .foregroundStyle(.secondary)
                        Text("\(statusCode)")
                    }
                }
                
                if let size = node.contentSizeBytes {
                    GridRow {
                        Text("Size")
                            .foregroundStyle(.secondary)
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    }
                }
                
                GridRow {
                    Text("Links")
                        .foregroundStyle(.secondary)
                    Text("In: \(node.inboundLinkCount) / Out: \(node.outboundLinkCount)")
                }
            }
            .font(.caption)
            
            HStack {
                Button("Open URL") {
                    if let url = URL(string: node.url) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Copy URL") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(node.url, forType: .string)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }
    
    // MARK: - Drawing
    
    private func drawTree(_ tree: SiteMapTree, context: GraphicsContext, x: CGFloat, y: CGFloat, level: Int) {
        let node = tree.node
        
        // Draw node
        let nodeRect = CGRect(
            x: x - nodeWidth / 2,
            y: y,
            width: nodeWidth,
            height: nodeHeight
        )
        
        // Node background
        let isSelected = selectedNode?.id == node.id
        let isHovered = hoveredNode?.id == node.id
        
        let backgroundColor = isSelected ? Color.accentColor.opacity(0.3) :
                             isHovered ? Color.secondary.opacity(0.2) :
                             Color.primary.opacity(0.1)
        
        context.fill(
            RoundedRectangle(cornerRadius: 8).path(in: nodeRect),
            with: .color(backgroundColor)
        )
        
        // Node border
        let borderColor = colorForStatus(node.nodeStatus)
        context.stroke(
            RoundedRectangle(cornerRadius: 8).path(in: nodeRect),
            with: .color(borderColor),
            lineWidth: isSelected ? 3 : 1
        )
        
        // Node text
        let title = node.title ?? URL(string: node.url)?.lastPathComponent ?? "Unknown"
        let truncatedTitle = title.count > 20 ? String(title.prefix(17)) + "..." : title
        
        context.draw(
            Text(truncatedTitle)
                .font(.system(size: 11, weight: .medium)),
            at: CGPoint(x: x, y: y + nodeHeight / 2 - 8)
        )
        
        // Icon
        context.draw(
            Text(Image(systemName: node.fileType.icon))
                .font(.system(size: 12)),
            at: CGPoint(x: x - nodeWidth / 2 + 16, y: y + nodeHeight / 2)
        )
        
        // Draw children
        if !tree.children.isEmpty {
            let totalChildWidth = calculateSubtreeWidth(tree)
            var childX = x - totalChildWidth / 2
            
            for child in tree.children {
                let childWidth = calculateSubtreeWidth(child)
                let childCenterX = childX + childWidth / 2
                let childY = y + nodeHeight + verticalSpacing
                
                // Draw connecting line
                var path = Path()
                path.move(to: CGPoint(x: x, y: y + nodeHeight))
                path.addLine(to: CGPoint(x: x, y: y + nodeHeight + verticalSpacing / 2))
                path.addLine(to: CGPoint(x: childCenterX, y: y + nodeHeight + verticalSpacing / 2))
                path.addLine(to: CGPoint(x: childCenterX, y: childY))
                
                context.stroke(path, with: .color(.secondary.opacity(0.5)), lineWidth: 1)
                
                // Recursively draw child
                drawTree(child, context: context, x: childCenterX, y: childY, level: level + 1)
                
                childX += childWidth + horizontalSpacing
            }
        }
    }
    
    // MARK: - Layout Calculations
    
    private func calculateSubtreeWidth(_ tree: SiteMapTree) -> CGFloat {
        if tree.children.isEmpty {
            return nodeWidth
        }
        
        let childrenWidth = tree.children.reduce(CGFloat(0)) { total, child in
            total + calculateSubtreeWidth(child)
        }
        let spacingWidth = CGFloat(tree.children.count - 1) * horizontalSpacing
        
        return max(nodeWidth, childrenWidth + spacingWidth)
    }
    
    private func calculateTreeWidth(_ tree: SiteMapTree) -> CGFloat {
        calculateSubtreeWidth(tree)
    }
    
    private func calculateTreeHeight(_ tree: SiteMapTree) -> CGFloat {
        if tree.children.isEmpty {
            return nodeHeight
        }
        
        let maxChildHeight = tree.children.map { calculateTreeHeight($0) }.max() ?? 0
        return nodeHeight + verticalSpacing + maxChildHeight
    }
    
    private func colorForStatus(_ status: NodeStatus) -> Color {
        switch status {
        case .discovered: return .gray
        case .queued: return .blue
        case .fetching: return .orange
        case .fetched: return .green
        case .failed: return .red
        case .skipped: return .purple
        case .blocked: return .yellow
        case .external: return .gray
        }
    }
}

// MARK: - Tree View Alternative

struct SiteMapTreeView: View {
    let tree: SiteMapTree?
    @State private var expandedNodes: Set<UUID> = []
    
    var body: some View {
        if let tree = tree {
            List {
                TreeNodeRow(tree: tree, expandedNodes: $expandedNodes, level: 0)
            }
            .listStyle(.sidebar)
        } else {
            ContentUnavailableView(
                "No Site Map",
                systemImage: "map",
                description: Text("Run a scrape to generate a site map")
            )
        }
    }
}

struct TreeNodeRow: View {
    let tree: SiteMapTree
    @Binding var expandedNodes: Set<UUID>
    let level: Int
    
    var body: some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedNodes.contains(tree.id) },
                set: { isExpanded in
                    if isExpanded {
                        expandedNodes.insert(tree.id)
                    } else {
                        expandedNodes.remove(tree.id)
                    }
                }
            )
        ) {
            ForEach(tree.children) { child in
                TreeNodeRow(tree: child, expandedNodes: $expandedNodes, level: level + 1)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tree.node.fileType.icon)
                    .foregroundStyle(statusColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tree.node.title ?? "Untitled")
                        .font(.body)
                        .lineLimit(1)
                    
                    Text(tree.node.url)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if let statusCode = tree.node.statusCode {
                    Text("\(statusCode)")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.2))
                        .clipShape(Capsule())
                }
                
                if !tree.isLeaf {
                    Text("\(tree.childCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var statusColor: Color {
        switch tree.node.nodeStatus {
        case .fetched: return .green
        case .failed: return .red
        case .blocked: return .yellow
        default: return .secondary
        }
    }
}

// MARK: - Preview

#Preview {
    SiteMapVisualization(tree: nil)
}
