//
//  ScrapedPage.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation

/// Represents a single scraped web page
/// Stores the raw content and extracted data
struct ScrapedPage: Identifiable, Codable, Hashable {
    let id: UUID
    let jobId: UUID
    let url: String
    let parentURL: String?
    
    // Fetch metadata
    let fetchedAt: Date
    var statusCode: Int
    var contentType: String?
    var contentLength: Int64?
    var responseHeaders: [String: String]
    
    // Content
    var htmlContent: String?
    var textContent: String?
    var title: String?
    var metaDescription: String?
    var metaKeywords: [String]
    
    // Structure
    var depth: Int
    var links: [DiscoveredLink]
    var images: [DiscoveredResource]
    var scripts: [DiscoveredResource]
    var stylesheets: [DiscoveredResource]
    
    // Extracted data (from extraction rules)
    var extractedData: [String: ExtractedValue]
    
    // Processing status
    var processingStatus: PageProcessingStatus
    var errorMessage: String?
    
    // Snapshot for diff tracking
    var snapshotHash: String?
    
    init(
        id: UUID = UUID(),
        jobId: UUID,
        url: String,
        parentURL: String? = nil,
        fetchedAt: Date = Date(),
        statusCode: Int = 0,
        contentType: String? = nil,
        contentLength: Int64? = nil,
        responseHeaders: [String: String] = [:],
        htmlContent: String? = nil,
        textContent: String? = nil,
        title: String? = nil,
        metaDescription: String? = nil,
        metaKeywords: [String] = [],
        depth: Int = 0,
        links: [DiscoveredLink] = [],
        images: [DiscoveredResource] = [],
        scripts: [DiscoveredResource] = [],
        stylesheets: [DiscoveredResource] = [],
        extractedData: [String: ExtractedValue] = [:],
        processingStatus: PageProcessingStatus = .pending,
        errorMessage: String? = nil,
        snapshotHash: String? = nil
    ) {
        self.id = id
        self.jobId = jobId
        self.url = url
        self.parentURL = parentURL
        self.fetchedAt = fetchedAt
        self.statusCode = statusCode
        self.contentType = contentType
        self.contentLength = contentLength
        self.responseHeaders = responseHeaders
        self.htmlContent = htmlContent
        self.textContent = textContent
        self.title = title
        self.metaDescription = metaDescription
        self.metaKeywords = metaKeywords
        self.depth = depth
        self.links = links
        self.images = images
        self.scripts = scripts
        self.stylesheets = stylesheets
        self.extractedData = extractedData
        self.processingStatus = processingStatus
        self.errorMessage = errorMessage
        self.snapshotHash = snapshotHash
    }
}

/// Processing status for a page
enum PageProcessingStatus: String, Codable {
    case pending = "Pending"
    case fetching = "Fetching"
    case parsing = "Parsing"
    case extracting = "Extracting"
    case complete = "Complete"
    case failed = "Failed"
    case skipped = "Skipped"
}

/// A link discovered on a page
struct DiscoveredLink: Codable, Hashable, Identifiable {
    let id: UUID
    let url: String
    let text: String?
    let title: String?
    let rel: String?
    let linkType: LinkType
    var wasFollowed: Bool
    
    init(
        id: UUID = UUID(),
        url: String,
        text: String? = nil,
        title: String? = nil,
        rel: String? = nil,
        linkType: LinkType = .internal,
        wasFollowed: Bool = false
    ) {
        self.id = id
        self.url = url
        self.text = text
        self.title = title
        self.rel = rel
        self.linkType = linkType
        self.wasFollowed = wasFollowed
    }
}

/// Type of link
enum LinkType: String, Codable {
    case `internal` = "Internal"
    case external = "External"
    case resource = "Resource"
    case download = "Download"
    case mailto = "Email"
    case tel = "Phone"
    case javascript = "JavaScript"
    case anchor = "Anchor"
}

/// A resource discovered on a page (image, script, stylesheet)
struct DiscoveredResource: Codable, Hashable, Identifiable {
    let id: UUID
    let url: String
    let alt: String?
    let title: String?
    var wasDownloaded: Bool
    var localPath: String?
    
    init(
        id: UUID = UUID(),
        url: String,
        alt: String? = nil,
        title: String? = nil,
        wasDownloaded: Bool = false,
        localPath: String? = nil
    ) {
        self.id = id
        self.url = url
        self.alt = alt
        self.title = title
        self.wasDownloaded = wasDownloaded
        self.localPath = localPath
    }
}

/// Value extracted using an extraction rule
enum ExtractedValue: Codable, Hashable {
    case string(String)
    case strings([String])
    case number(Double)
    case boolean(Bool)
    case null
    
    var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .strings(let arr): return arr.joined(separator: ", ")
        case .number(let n): return String(n)
        case .boolean(let b): return b ? "true" : "false"
        case .null: return nil
        }
    }
}
