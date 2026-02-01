//
//  CrawlerEngine.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation

/// Orchestrates the web crawling process
/// Manages URL queue, rate limiting, and coordinates fetching
actor CrawlerEngine {
    
    // MARK: - Types
    
    enum CrawlStrategy {
        case breadthFirst
        case depthFirst
    }
    
    struct CrawlConfiguration {
        var strategy: CrawlStrategy
        var maxDepth: Int
        var maxPages: Int
        var followExternalLinks: Bool
        var respectRobotsTxt: Bool
        var enableJavaScript: Bool
        var requestDelayMs: Int
        var maxConcurrentRequests: Int
        var urlWhitelist: [String]
        var urlBlacklist: [String]
        var downloadFileTypes: [FileType]
        var extractionRules: [ExtractionRule]
        var customHeaders: [String: String]
        var userAgent: String
        
        init(
            strategy: CrawlStrategy = .breadthFirst,
            maxDepth: Int = 5,
            maxPages: Int = 1000,
            followExternalLinks: Bool = false,
            respectRobotsTxt: Bool = true,
            enableJavaScript: Bool = true,
            requestDelayMs: Int = 1000,
            maxConcurrentRequests: Int = 4,
            urlWhitelist: [String] = [],
            urlBlacklist: [String] = [],
            downloadFileTypes: [FileType] = FileType.allCases,
            extractionRules: [ExtractionRule] = [],
            customHeaders: [String: String] = [:],
            userAgent: String = "WebScraperBot/1.0"
        ) {
            self.strategy = strategy
            self.maxDepth = maxDepth
            self.maxPages = maxPages
            self.followExternalLinks = followExternalLinks
            self.respectRobotsTxt = respectRobotsTxt
            self.enableJavaScript = enableJavaScript
            self.requestDelayMs = requestDelayMs
            self.maxConcurrentRequests = maxConcurrentRequests
            self.urlWhitelist = urlWhitelist
            self.urlBlacklist = urlBlacklist
            self.downloadFileTypes = downloadFileTypes
            self.extractionRules = extractionRules
            self.customHeaders = customHeaders
            self.userAgent = userAgent
        }
    }
    
    struct CrawlProgress {
        var status: CrawlStatus
        var totalURLsDiscovered: Int
        var urlsProcessed: Int
        var urlsInQueue: Int
        var pagesScraped: Int
        var filesDiscovered: Int
        var errorsEncountered: Int
        var currentURL: String?
        var startTime: Date?
        var estimatedTimeRemaining: TimeInterval?
    }
    
    enum CrawlStatus {
        case idle
        case initializing
        case running
        case paused
        case stopping
        case completed
        case failed(Error)
    }
    
    // MARK: - Delegate Protocol
    
    protocol CrawlerDelegate: AnyObject {
        func crawler(_ crawler: CrawlerEngine, didUpdateProgress progress: CrawlProgress) async
        func crawler(_ crawler: CrawlerEngine, didScrapePage page: ScrapedPage) async
        func crawler(_ crawler: CrawlerEngine, didDiscoverFile url: URL, ofType type: FileType) async
        func crawler(_ crawler: CrawlerEngine, didEncounterError error: Error, forURL url: URL) async
        func crawlerDidComplete(_ crawler: CrawlerEngine) async
    }
    
    // MARK: - Properties
    
    private var configuration: CrawlConfiguration
    private var job: ScrapeJob?
    private var startURL: URL?
    private var baseDomain: String?
    
    // URL Management
    private var urlQueue: [QueuedURL] = []
    private var visitedURLs: Set<String> = []
    private var discoveredFiles: [URL] = []
    
    // Progress
    private var progress = CrawlProgress(
        status: .idle,
        totalURLsDiscovered: 0,
        urlsProcessed: 0,
        urlsInQueue: 0,
        pagesScraped: 0,
        filesDiscovered: 0,
        errorsEncountered: 0,
        currentURL: nil,
        startTime: nil,
        estimatedTimeRemaining: nil
    )
    
    // Services
    private let htmlFetcher: HTMLFetcher
    private var jsRenderer: JSRenderer?
    private let rateLimiter: RateLimiter
    private let robotsParser: RobotsTxtParser
    
    // Control
    private var isRunning = false
    private var isPaused = false
    private var shouldStop = false
    
    // Delegate
    weak var delegate: (any CrawlerDelegate)?
    
    // MARK: - Initialization
    
    init(configuration: CrawlConfiguration = CrawlConfiguration()) {
        self.configuration = configuration
        self.htmlFetcher = HTMLFetcher(configuration: HTMLFetcher.Configuration(
            userAgent: configuration.userAgent,
            customHeaders: configuration.customHeaders
        ))
        self.rateLimiter = RateLimiter(configuration: RateLimiter.Configuration(
            defaultDelayMs: configuration.requestDelayMs,
            maxConcurrentRequests: configuration.maxConcurrentRequests
        ))
        self.robotsParser = RobotsTxtParser(userAgent: configuration.userAgent)
    }
    
    // MARK: - Public Methods
    
    /// Update configuration
    func updateConfiguration(_ config: CrawlConfiguration) {
        self.configuration = config
    }
    
    /// Start crawling from a URL
    func start(url: URL, job: ScrapeJob) async throws {
        guard !isRunning else {
            throw CrawlerError.alreadyRunning
        }
        
        // Validate URL
        guard URLValidator.isValidForScraping(url) else {
            throw CrawlerError.invalidURL
        }
        
        // Initialize
        self.startURL = url
        self.job = job
        self.baseDomain = URLValidator.extractBaseDomain(url)
        self.isRunning = true
        self.isPaused = false
        self.shouldStop = false
        
        // Reset state
        urlQueue.removeAll()
        visitedURLs.removeAll()
        discoveredFiles.removeAll()
        progress = CrawlProgress(
            status: .initializing,
            totalURLsDiscovered: 1,
            urlsProcessed: 0,
            urlsInQueue: 1,
            pagesScraped: 0,
            filesDiscovered: 0,
            errorsEncountered: 0,
            currentURL: url.absoluteString,
            startTime: Date(),
            estimatedTimeRemaining: nil
        )
        
        await delegate?.crawler(self, didUpdateProgress: progress)
        
        // Initialize JS renderer if needed (JSRenderer is @MainActor)
        if configuration.enableJavaScript {
            let userAgent = configuration.userAgent
            let newRenderer = await MainActor.run {
                JSRenderer(configuration: JSRenderer.Configuration(userAgent: userAgent))
            }
            jsRenderer = newRenderer
        }
        
        // Check robots.txt
        if configuration.respectRobotsTxt {
            progress.status = .initializing
            let isAllowed = await robotsParser.isAllowed(url)
            if !isAllowed {
                throw CrawlerError.blockedByRobotsTxt
            }
        }
        
        // Add start URL to queue
        enqueue(url: url, depth: 0, parentURL: nil)
        
        // Start crawling
        progress.status = .running
        await delegate?.crawler(self, didUpdateProgress: progress)
        
        await crawlLoop()
    }
    
    /// Pause crawling
    func pause() {
        guard isRunning, !isPaused else { return }
        isPaused = true
        progress.status = .paused
    }
    
    /// Resume crawling
    func resume() async {
        guard isRunning, isPaused else { return }
        isPaused = false
        progress.status = .running
        await delegate?.crawler(self, didUpdateProgress: progress)
        await crawlLoop()
    }
    
    /// Stop crawling
    func stop() {
        shouldStop = true
        progress.status = .stopping
    }
    
    /// Get current progress
    func getProgress() -> CrawlProgress {
        progress
    }
    
    // MARK: - Private Methods
    
    private func crawlLoop() async {
        while isRunning && !shouldStop && !isPaused && !urlQueue.isEmpty {
            // Check limits
            if progress.pagesScraped >= configuration.maxPages {
                break
            }
            
            // Get next URL
            guard let queuedURL = dequeue() else { continue }
            
            // Check depth limit
            if queuedURL.depth > configuration.maxDepth {
                continue
            }
            
            // Check if already visited
            let normalizedURL = URLValidator.normalize(queuedURL.url)
            if visitedURLs.contains(normalizedURL) {
                continue
            }
            visitedURLs.insert(normalizedURL)
            
            // Check robots.txt
            if configuration.respectRobotsTxt {
                let isAllowed = await robotsParser.isAllowed(queuedURL.url)
                if !isAllowed {
                    continue
                }
            }
            
            // Check whitelist/blacklist
            if !shouldCrawl(url: queuedURL.url) {
                continue
            }
            
            // Rate limiting
            _ = await rateLimiter.waitForSlot(url: queuedURL.url)
            
            // Update progress
            progress.currentURL = queuedURL.url.absoluteString
            progress.urlsInQueue = urlQueue.count
            await delegate?.crawler(self, didUpdateProgress: progress)
            
            // Crawl the URL
            do {
                try await crawlURL(queuedURL)
                progress.urlsProcessed += 1
            } catch {
                progress.errorsEncountered += 1
                await delegate?.crawler(self, didEncounterError: error, forURL: queuedURL.url)
            }
            
            // Update rate limiter
            await rateLimiter.requestCompleted(url: queuedURL.url, statusCode: 200, responseTime: 0)
        }
        
        // Cleanup
        isRunning = false
        
        if shouldStop {
            progress.status = .stopping
        } else if progress.errorsEncountered > 0 && progress.pagesScraped == 0 {
            progress.status = .failed(CrawlerError.allRequestsFailed)
        } else {
            progress.status = .completed
        }
        
        await delegate?.crawler(self, didUpdateProgress: progress)
        await delegate?.crawlerDidComplete(self)
    }
    
    private func crawlURL(_ queuedURL: QueuedURL) async throws {
        let url = queuedURL.url
        
        // Determine if this is a page or a file
        let urlType = URLValidator.classifyURL(url)
        
        if urlType != .page {
            // This is a file, notify delegate
            let fileType = FileType(rawValue: urlType.rawValue) ?? .other
            if configuration.downloadFileTypes.contains(fileType) {
                discoveredFiles.append(url)
                progress.filesDiscovered += 1
                await delegate?.crawler(self, didDiscoverFile: url, ofType: fileType)
            }
            return
        }
        
        // Fetch the page
        let html: String
        let finalURL: URL
        
        if configuration.enableJavaScript, let renderer = jsRenderer {
            // Use JavaScript renderer (runs on MainActor)
            let result = try await Task { @MainActor in
                try await renderer.render(url: url)
            }.value
            html = result.htmlContent
            finalURL = result.finalURL
        } else {
            // Use static fetcher
            let result = try await htmlFetcher.fetch(url: url)
            guard let content = result.htmlContent else {
                throw CrawlerError.noContent
            }
            html = content
            finalURL = result.finalURL
        }
        
        // Parse the page
        let parser = HTMLParser(html: html)
        let document = parser.parse()
        
        // Extract data
        let extractor = DataExtractor(parser: parser)
        var extractedData = extractor.extractCommon()
        
        if !configuration.extractionRules.isEmpty {
            let ruleData = extractor.extract(rules: configuration.extractionRules)
            extractedData.merge(ruleData) { _, new in new }
        }
        
        // Create scraped page
        let page = ScrapedPage(
            jobId: job?.id ?? UUID(),
            url: url.absoluteString,
            parentURL: queuedURL.parentURL?.absoluteString,
            statusCode: 200,
            contentType: "text/html",
            htmlContent: html,
            textContent: document.textContent,
            title: document.title,
            metaDescription: document.metaTags.first(where: { $0.name == "description" })?.content,
            metaKeywords: document.metaTags.first(where: { $0.name == "keywords" })?.content?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? [],
            depth: queuedURL.depth,
            links: document.links.map { link in
                DiscoveredLink(
                    url: link.href,
                    text: link.text,
                    title: link.title,
                    rel: link.rel,
                    linkType: classifyLink(link.href, from: finalURL)
                )
            },
            images: document.images.map { img in
                DiscoveredResource(url: img.src, alt: img.alt, title: img.title)
            },
            extractedData: extractedData,
            processingStatus: .complete
        )
        
        progress.pagesScraped += 1
        await delegate?.crawler(self, didScrapePage: page)
        
        // Discover new URLs
        for link in document.links {
            if let linkURL = URLValidator.resolve(link.href, against: finalURL) {
                let linkType = classifyLink(link.href, from: finalURL)
                
                if linkType == .internal || (linkType == .external && configuration.followExternalLinks) {
                    enqueue(url: linkURL, depth: queuedURL.depth + 1, parentURL: finalURL)
                }
                
                // Check if it's a downloadable file
                let urlType = URLValidator.classifyURL(linkURL)
                if urlType != .page {
                    let fileType = FileType(rawValue: urlType.rawValue) ?? .other
                    if configuration.downloadFileTypes.contains(fileType) && !discoveredFiles.contains(linkURL) {
                        discoveredFiles.append(linkURL)
                        progress.filesDiscovered += 1
                        await delegate?.crawler(self, didDiscoverFile: linkURL, ofType: fileType)
                    }
                }
            }
        }
        
        // Discover images
        for image in document.images {
            if let imageURL = URLValidator.resolve(image.src, against: finalURL),
               configuration.downloadFileTypes.contains(.image),
               !discoveredFiles.contains(imageURL) {
                discoveredFiles.append(imageURL)
                progress.filesDiscovered += 1
                await delegate?.crawler(self, didDiscoverFile: imageURL, ofType: .image)
            }
        }
    }
    
    private func enqueue(url: URL, depth: Int, parentURL: URL?) {
        let normalizedURL = URLValidator.normalize(url)
        
        // Check if already visited or queued
        if visitedURLs.contains(normalizedURL) {
            return
        }
        
        if urlQueue.contains(where: { URLValidator.normalize($0.url) == normalizedURL }) {
            return
        }
        
        let queuedURL = QueuedURL(url: url, depth: depth, parentURL: parentURL, discoveredAt: Date())
        
        switch configuration.strategy {
        case .breadthFirst:
            urlQueue.append(queuedURL)
        case .depthFirst:
            urlQueue.insert(queuedURL, at: 0)
        }
        
        progress.totalURLsDiscovered += 1
        progress.urlsInQueue = urlQueue.count
    }
    
    private func dequeue() -> QueuedURL? {
        guard !urlQueue.isEmpty else { return nil }
        return urlQueue.removeFirst()
    }
    
    private func shouldCrawl(url: URL) -> Bool {
        let urlString = url.absoluteString
        
        // Check whitelist
        if !configuration.urlWhitelist.isEmpty {
            let matchesWhitelist = configuration.urlWhitelist.contains { pattern in
                urlString.range(of: pattern, options: .regularExpression) != nil
            }
            if !matchesWhitelist {
                return false
            }
        }
        
        // Check blacklist
        for pattern in configuration.urlBlacklist {
            if urlString.range(of: pattern, options: .regularExpression) != nil {
                return false
            }
        }
        
        // Check same domain (if not following external)
        if !configuration.followExternalLinks {
            if let baseDomain = baseDomain, URLValidator.extractBaseDomain(url) != baseDomain {
                return false
            }
        }
        
        return true
    }
    
    private func classifyLink(_ href: String, from baseURL: URL) -> LinkType {
        // mailto, tel, javascript
        if href.hasPrefix("mailto:") { return .mailto }
        if href.hasPrefix("tel:") { return .tel }
        if href.hasPrefix("javascript:") { return .javascript }
        if href.hasPrefix("#") { return .anchor }
        
        // Resolve URL
        guard let url = URLValidator.resolve(href, against: baseURL) else {
            return .other
        }
        
        // Check file type
        let urlType = URLValidator.classifyURL(url)
        if urlType != .page {
            return .download
        }
        
        // Internal vs external
        if URLValidator.isSameBaseDomain(url, baseURL) {
            return .internal
        } else {
            return .external
        }
    }
}

// MARK: - Supporting Types

private struct QueuedURL {
    let url: URL
    let depth: Int
    let parentURL: URL?
    let discoveredAt: Date
}

// MARK: - Errors

enum CrawlerError: LocalizedError {
    case alreadyRunning
    case invalidURL
    case blockedByRobotsTxt
    case noContent
    case allRequestsFailed
    
    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "Crawler is already running"
        case .invalidURL:
            return "Invalid URL"
        case .blockedByRobotsTxt:
            return "URL is blocked by robots.txt"
        case .noContent:
            return "No content received"
        case .allRequestsFailed:
            return "All requests failed"
        }
    }
}

// Add missing LinkType case
extension LinkType {
    static var other: LinkType { .javascript }  // Fallback
}
