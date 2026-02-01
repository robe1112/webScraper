//
//  MindMapView.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import SwiftUI

/// Interactive mind map visualization view
struct MindMapView: View {
    @Binding var mindMap: MindMap
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var selectedNodeId: UUID?
    @State private var editingNodeId: UUID?
    @State private var showStyleSheet = false
    @State private var showNodeEditor = false
    
    // Layout calculations
    @State private var nodePositions: [UUID: CGPoint] = [:]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(NSColor.textBackgroundColor)
                    .ignoresSafeArea()
                
                // Mind map canvas
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    ZStack {
                        // Connections
                        ForEach(allConnections(), id: \.0) { connection in
                            ConnectionLine(
                                from: connection.1,
                                to: connection.2,
                                style: mindMap.style.connectionStyle
                            )
                        }
                        
                        // Nodes
                        MindMapNodeView(
                            node: mindMap.rootNode,
                            style: mindMap.style,
                            selectedId: $selectedNodeId,
                            editingId: $editingNodeId,
                            onUpdate: { updateNode($0) },
                            onAddChild: { addChild(to: $0) },
                            onDelete: { deleteNode($0) },
                            depth: 0,
                            position: .zero,
                            nodePositions: $nodePositions
                        )
                    }
                    .frame(width: calculateCanvasWidth(), height: calculateCanvasHeight())
                    .padding(100)
                }
                .scaleEffect(scale)
                .gesture(MagnificationGesture()
                    .onChanged { value in
                        scale = max(0.25, min(3.0, value))
                    }
                )
            }
        }
        .overlay(alignment: .topTrailing) {
            controlPanel
        }
        .overlay(alignment: .bottomLeading) {
            if let nodeId = selectedNodeId, let node = mindMap.findNode(id: nodeId) {
                nodeDetailPanel(node: node)
            }
        }
        .sheet(isPresented: $showStyleSheet) {
            StyleEditorSheet(style: $mindMap.style)
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: { addChild(to: mindMap.rootNode.id) }) {
                    Label("Add Topic", systemImage: "plus.circle")
                }
                
                Button(action: { showStyleSheet = true }) {
                    Label("Style", systemImage: "paintbrush")
                }
                
                Menu {
                    Button("Export as PNG") { exportAsPNG() }
                    Button("Export as PDF") { exportAsPDF() }
                    Button("Export as JSON") { exportAsJSON() }
                    Button("Export as Markdown") { exportAsMarkdown() }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
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
            
            Button(action: { expandAll() }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .help("Expand All")
            
            Button(action: { collapseAll() }) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
            }
            .help("Collapse All")
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding()
    }
    
    // MARK: - Node Detail Panel
    
    private func nodeDetailPanel(node: MindMapNode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: node.type.icon)
                    .foregroundStyle(node.color?.color ?? .accentColor)
                
                Text(node.text)
                    .font(.headline)
                    .lineLimit(2)
                
                Spacer()
                
                Button(action: { selectedNodeId = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            if let notes = node.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            HStack(spacing: 16) {
                Button("Edit") {
                    editingNodeId = node.id
                    showNodeEditor = true
                }
                .buttonStyle(.bordered)
                
                Button("Add Child") {
                    addChild(to: node.id)
                }
                .buttonStyle(.bordered)
                
                if node.type != .root {
                    Button("Delete", role: .destructive) {
                        deleteNode(node.id)
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            if !node.links.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Links")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ForEach(node.links) { link in
                        if let url = link.url {
                            Link(destination: URL(string: url)!) {
                                Label(link.title, systemImage: "link")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: 280)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }
    
    // MARK: - Actions
    
    private func updateNode(_ node: MindMapNode) {
        mindMap.updateNode(node)
    }
    
    private func addChild(to parentId: UUID) {
        let newNode = MindMapNode(text: "New Topic", type: .topic)
        mindMap.addNode(newNode, toParent: parentId)
        selectedNodeId = newNode.id
        editingNodeId = newNode.id
    }
    
    private func deleteNode(_ id: UUID) {
        if selectedNodeId == id {
            selectedNodeId = nil
        }
        mindMap.removeNode(id: id)
    }
    
    private func expandAll() {
        // Toggle all nodes to expanded
    }
    
    private func collapseAll() {
        // Toggle all nodes to collapsed
    }
    
    // MARK: - Export
    
    private func exportAsPNG() {
        // Export mind map as PNG image
    }
    
    private func exportAsPDF() {
        // Export mind map as PDF
    }
    
    private func exportAsJSON() {
        // Export mind map as JSON
    }
    
    private func exportAsMarkdown() {
        // Export mind map as Markdown outline
    }
    
    // MARK: - Layout Calculations
    
    private func allConnections() -> [(UUID, CGPoint, CGPoint)] {
        var connections: [(UUID, CGPoint, CGPoint)] = []
        collectConnections(from: mindMap.rootNode, connections: &connections)
        return connections
    }
    
    private func collectConnections(from node: MindMapNode, connections: inout [(UUID, CGPoint, CGPoint)]) {
        guard let parentPos = nodePositions[node.id] else { return }
        
        for child in node.children {
            if let childPos = nodePositions[child.id] {
                connections.append((child.id, parentPos, childPos))
            }
            collectConnections(from: child, connections: &connections)
        }
    }
    
    private func calculateCanvasWidth() -> CGFloat {
        CGFloat(mindMap.nodeCount) * 200
    }
    
    private func calculateCanvasHeight() -> CGFloat {
        CGFloat(mindMap.maxDepth + 1) * 150
    }
}

// MARK: - Node View

struct MindMapNodeView: View {
    let node: MindMapNode
    let style: MindMapStyle
    @Binding var selectedId: UUID?
    @Binding var editingId: UUID?
    let onUpdate: (MindMapNode) -> Void
    let onAddChild: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let depth: Int
    let position: CGPoint
    @Binding var nodePositions: [UUID: CGPoint]
    
    @State private var isEditing = false
    @State private var editText = ""
    
    var body: some View {
        VStack(spacing: spacing) {
            // This node
            nodeContent
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear {
                            let center = CGPoint(
                                x: geo.frame(in: .named("canvas")).midX,
                                y: geo.frame(in: .named("canvas")).midY
                            )
                            nodePositions[node.id] = center
                        }
                    }
                )
            
            // Children
            if node.isExpanded && !node.children.isEmpty {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(node.children) { child in
                        MindMapNodeView(
                            node: child,
                            style: style,
                            selectedId: $selectedId,
                            editingId: $editingId,
                            onUpdate: onUpdate,
                            onAddChild: onAddChild,
                            onDelete: onDelete,
                            depth: depth + 1,
                            position: .zero,
                            nodePositions: $nodePositions
                        )
                    }
                }
            }
        }
        .coordinateSpace(name: "canvas")
    }
    
    private var nodeContent: some View {
        HStack(spacing: 6) {
            if let icon = node.icon {
                Image(systemName: icon)
                    .font(.caption)
            } else {
                Image(systemName: node.type.icon)
                    .font(.caption)
            }
            
            if editingId == node.id {
                TextField("", text: $editText, onCommit: {
                    var updated = node
                    updated.text = editText
                    onUpdate(updated)
                    editingId = nil
                })
                .textFieldStyle(.plain)
                .frame(minWidth: 100)
            } else {
                Text(node.text)
                    .lineLimit(2)
            }
            
            if !node.children.isEmpty {
                Button(action: {
                    var updated = node
                    updated.isExpanded.toggle()
                    onUpdate(updated)
                }) {
                    Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .clipShape(nodeShape)
        .overlay(
            nodeShape
                .stroke(borderColor, lineWidth: selectedId == node.id ? 3 : 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        .onTapGesture {
            selectedId = node.id
        }
        .onTapGesture(count: 2) {
            editText = node.text
            editingId = node.id
        }
    }
    
    private var backgroundColor: Color {
        if let color = node.color {
            return color.color.opacity(0.2)
        }
        
        switch depth {
        case 0: return Color.accentColor.opacity(0.3)
        case 1: return Color.secondary.opacity(0.15)
        default: return Color.secondary.opacity(0.1)
        }
    }
    
    private var foregroundColor: Color {
        .primary
    }
    
    private var borderColor: Color {
        if selectedId == node.id {
            return .accentColor
        }
        return node.color?.color ?? Color.secondary.opacity(0.3)
    }
    
    private var nodeShape: some Shape {
        RoundedRectangle(cornerRadius: cornerRadius)
    }
    
    private var cornerRadius: CGFloat {
        switch style.nodeShape {
        case .rectangle: return 0
        case .roundedRect: return 8
        case .pill: return 20
        case .ellipse: return 16
        case .underline: return 0
        }
    }
    
    private var spacing: CGFloat {
        switch style.spacing {
        case .compact: return 20
        case .normal: return 40
        case .spacious: return 60
        }
    }
}

// MARK: - Connection Line

struct ConnectionLine: View {
    let from: CGPoint
    let to: CGPoint
    let style: MindMapStyle.ConnectionStyle
    
    var body: some View {
        Path { path in
            path.move(to: from)
            
            switch style {
            case .straight:
                path.addLine(to: to)
                
            case .curved:
                let midY = (from.y + to.y) / 2
                path.addCurve(
                    to: to,
                    control1: CGPoint(x: from.x, y: midY),
                    control2: CGPoint(x: to.x, y: midY)
                )
                
            case .orthogonal:
                let midY = (from.y + to.y) / 2
                path.addLine(to: CGPoint(x: from.x, y: midY))
                path.addLine(to: CGPoint(x: to.x, y: midY))
                path.addLine(to: to)
                
            case .tapered:
                path.addLine(to: to)
            }
        }
        .stroke(Color.secondary.opacity(0.5), lineWidth: style == .tapered ? 2 : 1)
    }
}

// MARK: - Style Editor

struct StyleEditorSheet: View {
    @Binding var style: MindMapStyle
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Layout") {
                    Picker("Layout Style", selection: $style.layout) {
                        ForEach(MindMapStyle.LayoutStyle.allCases, id: \.self) { layout in
                            Text(layout.rawValue).tag(layout)
                        }
                    }
                    
                    Picker("Spacing", selection: $style.spacing) {
                        ForEach(MindMapStyle.Spacing.allCases, id: \.self) { spacing in
                            Text(spacing.rawValue).tag(spacing)
                        }
                    }
                }
                
                Section("Appearance") {
                    Picker("Color Scheme", selection: $style.colorScheme) {
                        ForEach(MindMapStyle.ColorScheme.allCases, id: \.self) { scheme in
                            Text(scheme.rawValue).tag(scheme)
                        }
                    }
                    
                    Picker("Node Shape", selection: $style.nodeShape) {
                        ForEach(MindMapStyle.NodeShape.allCases, id: \.self) { shape in
                            Text(shape.rawValue).tag(shape)
                        }
                    }
                    
                    Picker("Connection Style", selection: $style.connectionStyle) {
                        ForEach(MindMapStyle.ConnectionStyle.allCases, id: \.self) { conn in
                            Text(conn.rawValue).tag(conn)
                        }
                    }
                }
                
                Section("Text") {
                    Picker("Font Size", selection: $style.fontSize) {
                        ForEach(MindMapStyle.FontSize.allCases, id: \.self) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                }
            }
            .navigationTitle("Mind Map Style")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 400, height: 400)
    }
}

// MARK: - Preview

#Preview {
    let sampleMap = MindMap(
        name: "Sample Mind Map",
        rootNode: MindMapNode(
            text: "Central Topic",
            type: .root,
            children: [
                MindMapNode(text: "Topic 1", type: .topic, children: [
                    MindMapNode(text: "Subtopic 1.1", type: .subtopic),
                    MindMapNode(text: "Subtopic 1.2", type: .subtopic)
                ]),
                MindMapNode(text: "Topic 2", type: .topic),
                MindMapNode(text: "Topic 3", type: .topic)
            ]
        )
    )
    
    return MindMapView(mindMap: .constant(sampleMap))
}
