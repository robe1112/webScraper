//
//  SiteNode.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation

/// Represents a node in the site map tree
/// Used for visualizing website structure
struct SiteNode: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let jobId: UUID
    let url: String
    let normalizedURL: String  // URL without query params, fragments
    
    // Tree structure
    var parentId: UUID?
    var childIds: [UUID]
    var depth: Int
    
    // Node metadata
    var title: String?
    var statusCode: Int?
    var contentType: String?
    var fileType: NodeFileType
    var nodeStatus: NodeStatus
    
    // Size info
    var contentSizeBytes: Int64?
    var responseTimeMs: Int?
    
    // Relationships
    var inboundLinkCount: Int
    var outboundLinkCount: Int
    
    // Timestamps
    let discoveredAt: Date
    var fetchedAt: Date?
    var lastCheckedAt: Date?
    
    nonisolated init(
        id: UUID = UUID(),
        jobId: UUID,
        url: String,
        normalizedURL: String? = nil,
        parentId: UUID? = nil,
        childIds: [UUID] = [],
        depth: Int = 0,
        title: String? = nil,
        statusCode: Int? = nil,
        contentType: String? = nil,
        fileType: NodeFileType = .page,
        nodeStatus: NodeStatus = .discovered,
        contentSizeBytes: Int64? = nil,
        responseTimeMs: Int? = nil,
        inboundLinkCount: Int = 0,
        outboundLinkCount: Int = 0,
        discoveredAt: Date = Date(),
        fetchedAt: Date? = nil,
        lastCheckedAt: Date? = nil
    ) {
        self.id = id
        self.jobId = jobId
        self.url = url
        self.normalizedURL = normalizedURL ?? SiteNode.normalizeURL(url)
        self.parentId = parentId
        self.childIds = childIds
        self.depth = depth
        self.title = title
        self.statusCode = statusCode
        self.contentType = contentType
        self.fileType = fileType
        self.nodeStatus = nodeStatus
        self.contentSizeBytes = contentSizeBytes
        self.responseTimeMs = responseTimeMs
        self.inboundLinkCount = inboundLinkCount
        self.outboundLinkCount = outboundLinkCount
        self.discoveredAt = discoveredAt
        self.fetchedAt = fetchedAt
        self.lastCheckedAt = lastCheckedAt
    }
    
    /// Normalize URL for deduplication
    nonisolated static func normalizeURL(_ url: String) -> String {
        guard var components = URLComponents(string: url) else { return url }
        
        // Remove fragment
        components.fragment = nil
        
        // Sort query parameters for consistency
        if let queryItems = components.queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems.sorted { $0.name < $1.name }
        }
        
        // Remove trailing slash
        if components.path.hasSuffix("/") && components.path != "/" {
            components.path = String(components.path.dropLast())
        }
        
        // Lowercase scheme and host
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        
        return components.url?.absoluteString ?? url
    }
}

/// Type of content at the node
enum NodeFileType: String, Codable, CaseIterable {
    case page = "Page"
    case image = "Image"
    case pdf = "PDF"
    case document = "Document"
    case audio = "Audio"
    case video = "Video"
    case archive = "Archive"
    case script = "Script"
    case stylesheet = "Stylesheet"
    case data = "Data"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .page: return "doc.text"
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .document: return "doc"
        case .audio: return "waveform"
        case .video: return "film"
        case .archive: return "archivebox"
        case .script: return "chevron.left.forwardslash.chevron.right"
        case .stylesheet: return "paintbrush"
        case .data: return "tablecells"
        case .other: return "questionmark.circle"
        }
    }
    
    /// Determine file type from URL and content type
    nonisolated static func detect(url: String, contentType: String?) -> NodeFileType {
        let lowercaseURL = url.lowercased()
        let ext = URL(string: lowercaseURL)?.pathExtension ?? ""
        
        // Check by extension
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "svg", "bmp", "tiff", "ico"]
        let documentExtensions = ["doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "odt"]
        let audioExtensions = ["mp3", "wav", "aac", "flac", "ogg", "m4a"]
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "webm", "wmv", "m4v"]
        let archiveExtensions = ["zip", "rar", "7z", "tar", "gz", "bz2"]
        let dataExtensions = ["json", "xml", "csv"]
        
        if ext == "pdf" { return .pdf }
        if imageExtensions.contains(ext) { return .image }
        if documentExtensions.contains(ext) { return .document }
        if audioExtensions.contains(ext) { return .audio }
        if videoExtensions.contains(ext) { return .video }
        if archiveExtensions.contains(ext) { return .archive }
        if ext == "js" { return .script }
        if ext == "css" { return .stylesheet }
        if dataExtensions.contains(ext) { return .data }
        
        // Check by content type
        if let contentType = contentType?.lowercased() {
            if contentType.contains("text/html") { return .page }
            if contentType.contains("image/") { return .image }
            if contentType.contains("application/pdf") { return .pdf }
            if contentType.contains("audio/") { return .audio }
            if contentType.contains("video/") { return .video }
            if contentType.contains("application/zip") { return .archive }
            if contentType.contains("javascript") { return .script }
            if contentType.contains("css") { return .stylesheet }
            if contentType.contains("json") || contentType.contains("xml") { return .data }
        }
        
        // Default to page for HTML-like URLs
        if ext.isEmpty || ext == "html" || ext == "htm" || ext == "php" || ext == "asp" {
            return .page
        }
        
        return .other
    }
}

/// Status of a site node
enum NodeStatus: String, Codable {
    case discovered = "Discovered"
    case queued = "Queued"
    case fetching = "Fetching"
    case fetched = "Fetched"
    case failed = "Failed"
    case skipped = "Skipped"
    case blocked = "Blocked"  // By robots.txt
    case external = "External"  // External domain
    
    var color: String {
        switch self {
        case .discovered: return "gray"
        case .queued: return "blue"
        case .fetching: return "orange"
        case .fetched: return "green"
        case .failed: return "red"
        case .skipped: return "purple"
        case .blocked: return "yellow"
        case .external: return "gray"
        }
    }
}
