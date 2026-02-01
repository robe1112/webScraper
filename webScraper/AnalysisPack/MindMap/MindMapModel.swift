//
//  MindMapModel.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation
import SwiftUI

/// Represents a mind map structure
struct MindMap: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var description: String?
    var rootNode: MindMapNode
    var createdAt: Date
    var modifiedAt: Date
    var projectId: UUID?
    var style: MindMapStyle
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        rootNode: MindMapNode? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        projectId: UUID? = nil,
        style: MindMapStyle = .default
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.rootNode = rootNode ?? MindMapNode(text: name, type: .root)
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.projectId = projectId
        self.style = style
    }
    
    /// Total node count
    var nodeCount: Int {
        rootNode.totalDescendants + 1
    }
    
    /// Maximum depth of the tree
    var maxDepth: Int {
        rootNode.maxDepth
    }
}

/// A single node in the mind map
struct MindMapNode: Identifiable, Codable, Hashable {
    let id: UUID
    var text: String
    var notes: String?
    var type: NodeType
    var children: [MindMapNode]
    var isExpanded: Bool
    var color: NodeColor?
    var icon: String?
    var links: [NodeLink]
    var metadata: [String: String]
    
    init(
        id: UUID = UUID(),
        text: String,
        notes: String? = nil,
        type: NodeType = .topic,
        children: [MindMapNode] = [],
        isExpanded: Bool = true,
        color: NodeColor? = nil,
        icon: String? = nil,
        links: [NodeLink] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.text = text
        self.notes = notes
        self.type = type
        self.children = children
        self.isExpanded = isExpanded
        self.color = color
        self.icon = icon
        self.links = links
        self.metadata = metadata
    }
    
    /// Total descendant count
    var totalDescendants: Int {
        children.reduce(0) { $0 + 1 + $1.totalDescendants }
    }
    
    /// Maximum depth from this node
    var maxDepth: Int {
        if children.isEmpty { return 0 }
        return 1 + (children.map { $0.maxDepth }.max() ?? 0)
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MindMapNode, rhs: MindMapNode) -> Bool {
        lhs.id == rhs.id
    }
}

/// Types of mind map nodes
enum NodeType: String, Codable, CaseIterable {
    case root = "Root"
    case topic = "Topic"
    case subtopic = "Subtopic"
    case note = "Note"
    case link = "Link"
    case document = "Document"
    case entity = "Entity"
    case question = "Question"
    case idea = "Idea"
    case task = "Task"
    
    var icon: String {
        switch self {
        case .root: return "star.fill"
        case .topic: return "circle.fill"
        case .subtopic: return "circle"
        case .note: return "note.text"
        case .link: return "link"
        case .document: return "doc.fill"
        case .entity: return "person.fill"
        case .question: return "questionmark.circle.fill"
        case .idea: return "lightbulb.fill"
        case .task: return "checkmark.circle"
        }
    }
}

/// Node color options
enum NodeColor: String, Codable, CaseIterable {
    case red, orange, yellow, green, blue, purple, pink, gray
    
    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .gray: return .gray
        }
    }
}

/// Link to external resource or another node
struct NodeLink: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var url: String?
    var linkedNodeId: UUID?
    var linkType: LinkType
    
    enum LinkType: String, Codable {
        case url = "URL"
        case document = "Document"
        case node = "Node"
        case file = "File"
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        url: String? = nil,
        linkedNodeId: UUID? = nil,
        linkType: LinkType = .url
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.linkedNodeId = linkedNodeId
        self.linkType = linkType
    }
}

/// Visual style for mind maps
struct MindMapStyle: Codable, Hashable {
    var layout: LayoutStyle
    var colorScheme: ColorScheme
    var nodeShape: NodeShape
    var connectionStyle: ConnectionStyle
    var fontSize: FontSize
    var spacing: Spacing
    
    enum LayoutStyle: String, Codable, CaseIterable {
        case radial = "Radial"
        case rightSide = "Right Side"
        case leftSide = "Left Side"
        case topDown = "Top Down"
        case bottomUp = "Bottom Up"
        case organic = "Organic"
    }
    
    enum ColorScheme: String, Codable, CaseIterable {
        case automatic = "Automatic"
        case monochrome = "Monochrome"
        case rainbow = "Rainbow"
        case warm = "Warm"
        case cool = "Cool"
        case earth = "Earth"
        case ocean = "Ocean"
        case forest = "Forest"
    }
    
    enum NodeShape: String, Codable, CaseIterable {
        case rectangle = "Rectangle"
        case roundedRect = "Rounded Rectangle"
        case pill = "Pill"
        case ellipse = "Ellipse"
        case underline = "Underline"
    }
    
    enum ConnectionStyle: String, Codable, CaseIterable {
        case curved = "Curved"
        case straight = "Straight"
        case orthogonal = "Orthogonal"
        case tapered = "Tapered"
    }
    
    enum FontSize: String, Codable, CaseIterable {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"
    }
    
    enum Spacing: String, Codable, CaseIterable {
        case compact = "Compact"
        case normal = "Normal"
        case spacious = "Spacious"
    }
    
    static let `default` = MindMapStyle(
        layout: .radial,
        colorScheme: .automatic,
        nodeShape: .roundedRect,
        connectionStyle: .curved,
        fontSize: .medium,
        spacing: .normal
    )
}

// MARK: - Mind Map Operations

extension MindMap {
    
    /// Add a child node to a parent
    mutating func addNode(_ node: MindMapNode, toParent parentId: UUID) {
        rootNode = addNodeRecursive(node, toParent: parentId, in: rootNode)
        modifiedAt = Date()
    }
    
    /// Remove a node by ID
    mutating func removeNode(id: UUID) {
        rootNode = removeNodeRecursive(id: id, from: rootNode) ?? rootNode
        modifiedAt = Date()
    }
    
    /// Update a node
    mutating func updateNode(_ node: MindMapNode) {
        rootNode = updateNodeRecursive(node, in: rootNode)
        modifiedAt = Date()
    }
    
    /// Find a node by ID
    func findNode(id: UUID) -> MindMapNode? {
        findNodeRecursive(id: id, in: rootNode)
    }
    
    /// Get all nodes as flat array
    func allNodes() -> [MindMapNode] {
        var nodes: [MindMapNode] = [rootNode]
        collectNodes(from: rootNode, into: &nodes)
        return nodes
    }
    
    // MARK: - Private Helpers
    
    private func addNodeRecursive(_ node: MindMapNode, toParent parentId: UUID, in current: MindMapNode) -> MindMapNode {
        if current.id == parentId {
            var updated = current
            updated.children.append(node)
            return updated
        }
        
        var updated = current
        updated.children = current.children.map { addNodeRecursive(node, toParent: parentId, in: $0) }
        return updated
    }
    
    private func removeNodeRecursive(id: UUID, from current: MindMapNode) -> MindMapNode? {
        if current.id == id {
            return nil
        }
        
        var updated = current
        updated.children = current.children.compactMap { removeNodeRecursive(id: id, from: $0) }
        return updated
    }
    
    private func updateNodeRecursive(_ node: MindMapNode, in current: MindMapNode) -> MindMapNode {
        if current.id == node.id {
            return node
        }
        
        var updated = current
        updated.children = current.children.map { updateNodeRecursive(node, in: $0) }
        return updated
    }
    
    private func findNodeRecursive(id: UUID, in current: MindMapNode) -> MindMapNode? {
        if current.id == id {
            return current
        }
        
        for child in current.children {
            if let found = findNodeRecursive(id: id, in: child) {
                return found
            }
        }
        
        return nil
    }
    
    private func collectNodes(from node: MindMapNode, into array: inout [MindMapNode]) {
        for child in node.children {
            array.append(child)
            collectNodes(from: child, into: &array)
        }
    }
}
