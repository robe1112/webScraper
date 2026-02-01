//
//  SiteMapBuilder.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation

/// Builds and manages site map from crawled pages
/// Creates hierarchical tree structure for visualization
actor SiteMapBuilder {
    
    // MARK: - Types
    
    struct SiteMapStats {
        var totalNodes: Int
        var totalPages: Int
        var totalResources: Int
        var maxDepth: Int
        var orphanPages: Int
        var brokenLinks: Int
        var externalLinks: Int
    }
    
    // MARK: - Properties
    
    private var nodes: [UUID: SiteNode] = [:]
    private var urlToNodeId: [String: UUID] = [:]
    private var rootNodeId: UUID?
    private let jobId: UUID
    
    // MARK: - Initialization
    
    init(jobId: UUID) {
        self.jobId = jobId
    }
    
    // MARK: - Public Methods
    
    /// Add or update a node in the site map
    func addNode(url: URL, parentURL: URL?, depth: Int, title: String? = nil, statusCode: Int? = nil, contentType: String? = nil) -> SiteNode {
        let normalizedURL = SiteNode.normalizeURL(url.absoluteString)
        
        // Check if node already exists
        if let existingId = urlToNodeId[normalizedURL], var existing = nodes[existingId] {
            // Update existing node
            existing.title = title ?? existing.title
            existing.statusCode = statusCode ?? existing.statusCode
            existing.contentType = contentType ?? existing.contentType
            existing.fetchedAt = Date()
            existing.nodeStatus = .fetched
            nodes[existingId] = existing
            return existing
        }
        
        // Create new node
        let parentId = parentURL.flatMap { urlToNodeId[SiteNode.normalizeURL($0.absoluteString)] }
        
        let node = SiteNode(
            jobId: jobId,
            url: url.absoluteString,
            parentId: parentId,
            depth: depth,
            title: title,
            statusCode: statusCode,
            contentType: contentType,
            fileType: SiteNode.NodeFileType.detect(url: url.absoluteString, contentType: contentType),
            nodeStatus: statusCode != nil ? .fetched : .discovered
        )
        
        nodes[node.id] = node
        urlToNodeId[normalizedURL] = node.id
        
        // Update parent's children
        if let parentId = parentId, var parent = nodes[parentId] {
            if !parent.childIds.contains(node.id) {
                parent.childIds.append(node.id)
                nodes[parentId] = parent
            }
        }
        
        // Set as root if no parent and first node
        if parentId == nil && rootNodeId == nil {
            rootNodeId = node.id
        }
        
        return node
    }
    
    /// Mark a node as having an error
    func markNodeFailed(url: URL, statusCode: Int? = nil) {
        let normalizedURL = SiteNode.normalizeURL(url.absoluteString)
        if let nodeId = urlToNodeId[normalizedURL], var node = nodes[nodeId] {
            node.nodeStatus = .failed
            node.statusCode = statusCode
            nodes[nodeId] = node
        }
    }
    
    /// Mark a node as blocked by robots.txt
    func markNodeBlocked(url: URL) {
        let normalizedURL = SiteNode.normalizeURL(url.absoluteString)
        if let nodeId = urlToNodeId[normalizedURL], var node = nodes[nodeId] {
            node.nodeStatus = .blocked
            nodes[nodeId] = node
        }
    }
    
    /// Get all nodes
    func getAllNodes() -> [SiteNode] {
        Array(nodes.values)
    }
    
    /// Get node by URL
    func getNode(url: URL) -> SiteNode? {
        let normalizedURL = SiteNode.normalizeURL(url.absoluteString)
        guard let nodeId = urlToNodeId[normalizedURL] else { return nil }
        return nodes[nodeId]
    }
    
    /// Get node by ID
    func getNode(id: UUID) -> SiteNode? {
        nodes[id]
    }
    
    /// Get root node
    func getRootNode() -> SiteNode? {
        rootNodeId.flatMap { nodes[$0] }
    }
    
    /// Get children of a node
    func getChildren(of nodeId: UUID) -> [SiteNode] {
        guard let node = nodes[nodeId] else { return [] }
        return node.childIds.compactMap { nodes[$0] }
    }
    
    /// Get parent of a node
    func getParent(of nodeId: UUID) -> SiteNode? {
        guard let node = nodes[nodeId], let parentId = node.parentId else { return nil }
        return nodes[parentId]
    }
    
    /// Get nodes at a specific depth
    func getNodes(atDepth depth: Int) -> [SiteNode] {
        nodes.values.filter { $0.depth == depth }
    }
    
    /// Get statistics about the site map
    func getStats() -> SiteMapStats {
        let allNodes = Array(nodes.values)
        
        return SiteMapStats(
            totalNodes: allNodes.count,
            totalPages: allNodes.filter { $0.fileType == .page }.count,
            totalResources: allNodes.filter { $0.fileType != .page }.count,
            maxDepth: allNodes.map { $0.depth }.max() ?? 0,
            orphanPages: allNodes.filter { $0.parentId == nil && $0.id != rootNodeId }.count,
            brokenLinks: allNodes.filter { $0.nodeStatus == .failed }.count,
            externalLinks: allNodes.filter { $0.nodeStatus == .external }.count
        )
    }
    
    /// Build tree structure for visualization
    func buildTree() -> SiteMapTree? {
        guard let rootNode = getRootNode() else { return nil }
        return buildTreeNode(from: rootNode)
    }
    
    /// Export as XML sitemap
    func exportAsXMLSitemap() -> String {
        var xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
            
            """
        
        for node in nodes.values where node.fileType == .page && node.nodeStatus == .fetched {
            xml += """
                <url>
                    <loc>\(escapeXML(node.url))</loc>
                    <lastmod>\(ISO8601DateFormatter().string(from: node.fetchedAt ?? Date()))</lastmod>
                </url>
            
            """
        }
        
        xml += "</urlset>"
        return xml
    }
    
    /// Export as JSON
    func exportAsJSON() throws -> Data {
        let exportData = SiteMapExport(
            generatedAt: Date(),
            rootURL: getRootNode()?.url,
            stats: getStats(),
            nodes: Array(nodes.values)
        )
        return try JSONEncoder().encode(exportData)
    }
    
    /// Clear all data
    func clear() {
        nodes.removeAll()
        urlToNodeId.removeAll()
        rootNodeId = nil
    }
    
    // MARK: - Private Methods
    
    private func buildTreeNode(from node: SiteNode) -> SiteMapTree {
        let children = getChildren(of: node.id).map { buildTreeNode(from: $0) }
        
        return SiteMapTree(
            node: node,
            children: children
        )
    }
    
    private func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

// MARK: - Supporting Types

struct SiteMapTree: Identifiable {
    let id = UUID()
    let node: SiteNode
    let children: [SiteMapTree]
    
    var isLeaf: Bool { children.isEmpty }
    var childCount: Int { children.count }
    
    func totalDescendants() -> Int {
        children.reduce(0) { $0 + 1 + $1.totalDescendants() }
    }
}

struct SiteMapExport: Codable {
    let generatedAt: Date
    let rootURL: String?
    let stats: SiteMapStats
    let nodes: [SiteNode]
}

extension SiteMapStats: Codable {}
