//
//  MindMapGenerator.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation

/// Options for mind map generation
struct MindMapGenerationOptions {
    var maxDepth: Int
    var maxNodesPerLevel: Int
    var includeMetadata: Bool
    var groupByType: Bool
    var sortBy: MindMapGenerationOptions.SortOption
    var style: MindMapStyle
    
    enum SortOption {
        case alphabetical
        case frequency
        case date
        case size
        case relevance
    }
    
    nonisolated static var `default`: MindMapGenerationOptions {
        MindMapGenerationOptions(
            maxDepth: 5,
            maxNodesPerLevel: 10,
            includeMetadata: true,
            groupByType: true,
            sortBy: .frequency,
            style: .default
        )
    }
}

/// Generates mind maps from various data sources
actor MindMapGenerator {
    
    // MARK: - Types
    
    enum GenerationSource {
        case siteMap(SiteMapTree)
        case documents([DownloadedFile])
        case scrapedPages([ScrapedPage])
        case entities([ExtractedEntity])
        case keywords([String: Int])  // keyword -> frequency
        case custom(title: String, items: [String])
    }
    
    // MARK: - Public Methods
    
    /// Generate a mind map from a source
    func generate(from source: GenerationSource, name: String, options: MindMapGenerationOptions = .default) async -> MindMap {
        switch source {
        case .siteMap(let tree):
            return generateFromSiteMap(tree, name: name, options: options)
        case .documents(let files):
            return generateFromDocuments(files, name: name, options: options)
        case .scrapedPages(let pages):
            return generateFromPages(pages, name: name, options: options)
        case .entities(let entities):
            return generateFromEntities(entities, name: name, options: options)
        case .keywords(let keywords):
            return generateFromKeywords(keywords, name: name, options: options)
        case .custom(let title, let items):
            return generateCustom(title: title, items: items, name: name, options: options)
        }
    }
    
    /// Generate mind map from site structure
    func generateFromSiteMap(_ tree: SiteMapTree, name: String, options: MindMapGenerationOptions) -> MindMap {
        let rootNode = convertSiteTreeToMindMapNode(tree, depth: 0, options: options)
        
        return MindMap(
            name: name,
            description: "Generated from site map",
            rootNode: rootNode,
            style: options.style
        )
    }
    
    /// Generate mind map from downloaded files
    func generateFromDocuments(_ files: [DownloadedFile], name: String, options: MindMapGenerationOptions) -> MindMap {
        var rootNode = MindMapNode(text: name, type: .root)
        
        if options.groupByType {
            // Group by file type
            let grouped = Dictionary(grouping: files) { $0.fileType }
            
            for (fileType, typeFiles) in grouped.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                var typeNode = MindMapNode(
                    text: fileType.rawValue,
                    type: .topic,
                    icon: iconForFileType(fileType)
                )
                
                let sortedFiles = sortFiles(typeFiles, by: options.sortBy)
                let limitedFiles = Array(sortedFiles.prefix(options.maxNodesPerLevel))
                
                for file in limitedFiles {
                    var fileNode = MindMapNode(
                        text: file.fileName,
                        type: .document,
                        links: [NodeLink(title: "Source", url: file.sourceURL)]
                    )
                    
                    if options.includeMetadata {
                        fileNode.metadata["size"] = file.formattedSize
                        fileNode.metadata["date"] = file.downloadedAt.formatted()
                    }
                    
                    typeNode.children.append(fileNode)
                }
                
                rootNode.children.append(typeNode)
            }
        } else {
            // Flat list
            let sortedFiles = sortFiles(files, by: options.sortBy)
            let limitedFiles = Array(sortedFiles.prefix(options.maxNodesPerLevel * 5))
            
            for file in limitedFiles {
                let fileNode = MindMapNode(
                    text: file.fileName,
                    type: .document,
                    links: [NodeLink(title: "Source", url: file.sourceURL)]
                )
                rootNode.children.append(fileNode)
            }
        }
        
        return MindMap(
            name: name,
            description: "Generated from \(files.count) documents",
            rootNode: rootNode,
            style: options.style
        )
    }
    
    /// Generate mind map from scraped pages
    func generateFromPages(_ pages: [ScrapedPage], name: String, options: MindMapGenerationOptions) -> MindMap {
        var rootNode = MindMapNode(text: name, type: .root)
        
        // Group by domain or depth
        let groupedByDepth = Dictionary(grouping: pages) { $0.depth }
        
        for depth in groupedByDepth.keys.sorted() {
            guard depth <= options.maxDepth else { continue }
            
            let depthPages = groupedByDepth[depth] ?? []
            var depthNode = MindMapNode(
                text: "Depth \(depth)",
                type: .topic,
                color: colorForDepth(depth)
            )
            
            let limitedPages = Array(depthPages.prefix(options.maxNodesPerLevel))
            
            for page in limitedPages {
                var pageNode = MindMapNode(
                    text: page.title ?? URL(string: page.url)?.lastPathComponent ?? "Unknown",
                    type: .link,
                    links: [NodeLink(title: "URL", url: page.url)]
                )
                
                if options.includeMetadata {
                    pageNode.metadata["status"] = "\(page.statusCode)"
                }
                
                depthNode.children.append(pageNode)
            }
            
            rootNode.children.append(depthNode)
        }
        
        return MindMap(
            name: name,
            description: "Generated from \(pages.count) pages",
            rootNode: rootNode,
            style: options.style
        )
    }
    
    /// Generate mind map from extracted entities
    func generateFromEntities(_ entities: [ExtractedEntity], name: String, options: MindMapGenerationOptions) -> MindMap {
        var rootNode = MindMapNode(text: name, type: .root)
        
        // Group by entity type
        let grouped = Dictionary(grouping: entities) { $0.type }
        
        for (entityType, typeEntities) in grouped.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            var typeNode = MindMapNode(
                text: entityType.rawValue,
                type: .topic,
                color: colorForEntityType(entityType),
                icon: iconForEntityType(entityType)
            )
            
            // Group identical entities and count frequency
            let entityCounts = Dictionary(grouping: typeEntities) { $0.value }
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
            
            let limitedEntities = Array(entityCounts.prefix(options.maxNodesPerLevel))
            
            for (value, count) in limitedEntities {
                var entityNode = MindMapNode(
                    text: value,
                    type: .entity
                )
                
                if count > 1 {
                    entityNode.notes = "Appears \(count) times"
                }
                
                typeNode.children.append(entityNode)
            }
            
            rootNode.children.append(typeNode)
        }
        
        return MindMap(
            name: name,
            description: "Generated from \(entities.count) entities",
            rootNode: rootNode,
            style: options.style
        )
    }
    
    /// Generate mind map from keywords
    func generateFromKeywords(_ keywords: [String: Int], name: String, options: MindMapGenerationOptions) -> MindMap {
        var rootNode = MindMapNode(text: name, type: .root)
        
        let sortedKeywords = keywords.sorted { $0.value > $1.value }
        let limitedKeywords = Array(sortedKeywords.prefix(options.maxNodesPerLevel * 3))
        
        // Create tiers based on frequency
        let maxFreq = limitedKeywords.first?.value ?? 1
        let highThreshold = maxFreq * 2 / 3
        let medThreshold = maxFreq / 3
        
        var highNode = MindMapNode(text: "High Frequency", type: .topic, color: .red)
        var medNode = MindMapNode(text: "Medium Frequency", type: .topic, color: .orange)
        var lowNode = MindMapNode(text: "Lower Frequency", type: .topic, color: .blue)
        
        for (keyword, freq) in limitedKeywords {
            let keywordNode = MindMapNode(
                text: keyword,
                notes: "\(freq) occurrences",
                type: .idea
            )
            
            if freq >= highThreshold {
                highNode.children.append(keywordNode)
            } else if freq >= medThreshold {
                medNode.children.append(keywordNode)
            } else {
                lowNode.children.append(keywordNode)
            }
        }
        
        if !highNode.children.isEmpty { rootNode.children.append(highNode) }
        if !medNode.children.isEmpty { rootNode.children.append(medNode) }
        if !lowNode.children.isEmpty { rootNode.children.append(lowNode) }
        
        return MindMap(
            name: name,
            description: "Generated from keyword analysis",
            rootNode: rootNode,
            style: options.style
        )
    }
    
    /// Generate custom mind map from string items
    func generateCustom(title: String, items: [String], name: String, options: MindMapGenerationOptions) -> MindMap {
        var rootNode = MindMapNode(text: title, type: .root)
        
        for item in items.prefix(options.maxNodesPerLevel * 5) {
            let node = MindMapNode(text: item, type: .topic)
            rootNode.children.append(node)
        }
        
        return MindMap(
            name: name,
            description: "Custom mind map",
            rootNode: rootNode,
            style: options.style
        )
    }
    
    // MARK: - AI-Assisted Generation
    
    /// Generate mind map using AI to analyze content
    func generateWithAI(from text: String, name: String, options: MindMapGenerationOptions) async throws -> MindMap {
        // This would use the LLM to:
        // 1. Extract main topics
        // 2. Identify subtopics and relationships
        // 3. Structure hierarchically
        
        // Placeholder - would integrate with LLMProvider
        let rootNode = MindMapNode(
            text: name,
            type: .root,
            children: [
                MindMapNode(text: "Main Topic 1", type: .topic),
                MindMapNode(text: "Main Topic 2", type: .topic),
                MindMapNode(text: "Main Topic 3", type: .topic)
            ]
        )
        
        return MindMap(
            name: name,
            description: "AI-generated mind map",
            rootNode: rootNode,
            style: options.style
        )
    }
    
    // MARK: - Private Helpers
    
    private func convertSiteTreeToMindMapNode(_ tree: SiteMapTree, depth: Int, options: MindMapGenerationOptions) -> MindMapNode {
        guard depth <= options.maxDepth else {
            return MindMapNode(
                text: tree.node.title ?? "...",
                type: .link,
                children: [],
                isExpanded: false
            )
        }
        
        var node = MindMapNode(
            text: tree.node.title ?? URL(string: tree.node.url)?.lastPathComponent ?? "Unknown",
            type: depth == 0 ? .root : .link,
            isExpanded: depth < 2,
            color: colorForDepth(depth),
            links: [NodeLink(title: "URL", url: tree.node.url)]
        )
        
        if options.includeMetadata {
            node.metadata["status"] = tree.node.nodeStatus.rawValue
            if let statusCode = tree.node.statusCode {
                node.metadata["http"] = "\(statusCode)"
            }
        }
        
        let limitedChildren = Array(tree.children.prefix(options.maxNodesPerLevel))
        node.children = limitedChildren.map { convertSiteTreeToMindMapNode($0, depth: depth + 1, options: options) }
        
        return node
    }
    
    private func sortFiles(_ files: [DownloadedFile], by option: MindMapGenerationOptions.SortOption) -> [DownloadedFile] {
        switch option {
        case .alphabetical:
            return files.sorted { $0.fileName < $1.fileName }
        case .date:
            return files.sorted { $0.downloadedAt > $1.downloadedAt }
        case .size:
            return files.sorted { $0.fileSize > $1.fileSize }
        default:
            return files
        }
    }
    
    private func colorForDepth(_ depth: Int) -> NodeColor {
        let colors: [NodeColor] = [.blue, .green, .orange, .purple, .pink, .red]
        return colors[depth % colors.count]
    }
    
    private func iconForFileType(_ type: FileType) -> String {
        switch type {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .document: return "doc"
        case .audio: return "waveform"
        case .video: return "film"
        case .archive: return "archivebox"
        case .other: return "doc"
        }
    }
    
    private func iconForEntityType(_ type: EntityType) -> String {
        switch type {
        case .person: return "person.fill"
        case .organization: return "building.2.fill"
        case .location: return "mappin.circle.fill"
        case .date: return "calendar"
        case .time: return "clock.fill"
        case .money: return "dollarsign.circle.fill"
        case .email: return "envelope.fill"
        case .phone: return "phone.fill"
        case .url: return "link"
        case .custom: return "tag.fill"
        }
    }
    
    private func colorForEntityType(_ type: EntityType) -> NodeColor {
        switch type {
        case .person: return .blue
        case .organization: return .purple
        case .location: return .green
        case .date, .time: return .orange
        case .money: return .yellow
        case .email, .phone, .url: return .gray
        case .custom: return .pink
        }
    }
}
