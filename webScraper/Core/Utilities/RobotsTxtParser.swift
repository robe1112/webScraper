//
//  RobotsTxtParser.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation

/// Parser for robots.txt files
/// Determines which URLs are allowed/disallowed for crawling
actor RobotsTxtParser {
    
    // MARK: - Types
    
    struct RobotsRules {
        let userAgent: String
        var disallowedPaths: [String] = []
        var allowedPaths: [String] = []
        var crawlDelay: TimeInterval?
        var sitemaps: [String] = []
    }
    
    // MARK: - Properties
    
    private var cache: [String: CachedRules] = [:]
    private let defaultUserAgent: String
    
    struct CachedRules {
        let rules: [RobotsRules]
        let fetchedAt: Date
        let expiresAt: Date
    }
    
    // MARK: - Initialization
    
    init(userAgent: String = "WebScraperBot/1.0") {
        self.defaultUserAgent = userAgent
    }
    
    // MARK: - Public Methods
    
    /// Fetch and parse robots.txt for a domain
    func fetchRules(for url: URL) async throws -> [RobotsRules] {
        guard let host = url.host else {
            throw RobotsError.invalidURL
        }
        
        // Check cache
        if let cached = cache[host], cached.expiresAt > Date() {
            return cached.rules
        }
        
        // Build robots.txt URL
        var components = URLComponents()
        components.scheme = url.scheme ?? "https"
        components.host = host
        components.path = "/robots.txt"
        
        guard let robotsURL = components.url else {
            throw RobotsError.invalidURL
        }
        
        // Fetch robots.txt
        let (data, response) = try await URLSession.shared.data(from: robotsURL)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RobotsError.fetchFailed
        }
        
        // Handle different status codes
        switch httpResponse.statusCode {
        case 200:
            guard let content = String(data: data, encoding: .utf8) else {
                throw RobotsError.parseError
            }
            let rules = parse(content)
            cacheRules(rules, for: host)
            return rules
            
        case 404:
            // No robots.txt - everything is allowed
            let rules: [RobotsRules] = []
            cacheRules(rules, for: host)
            return rules
            
        default:
            throw RobotsError.fetchFailed
        }
    }
    
    /// Check if a URL is allowed by robots.txt
    func isAllowed(_ url: URL, userAgent: String? = nil) async -> Bool {
        do {
            let rules = try await fetchRules(for: url)
            return isPathAllowed(url.path, rules: rules, userAgent: userAgent ?? defaultUserAgent)
        } catch {
            // If we can't fetch robots.txt, assume allowed
            return true
        }
    }
    
    /// Get crawl delay for a domain
    func getCrawlDelay(for url: URL, userAgent: String? = nil) async -> TimeInterval? {
        do {
            let rules = try await fetchRules(for: url)
            let agent = userAgent ?? defaultUserAgent
            
            // Find matching rules
            let matchingRules = findMatchingRules(for: agent, in: rules)
            return matchingRules?.crawlDelay
        } catch {
            return nil
        }
    }
    
    /// Get sitemaps from robots.txt
    func getSitemaps(for url: URL) async -> [String] {
        do {
            let rules = try await fetchRules(for: url)
            return rules.flatMap { $0.sitemaps }
        } catch {
            return []
        }
    }
    
    /// Clear cache for a domain
    func clearCache(for host: String) {
        cache.removeValue(forKey: host)
    }
    
    /// Clear all cache
    func clearAllCache() {
        cache.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func parse(_ content: String) -> [RobotsRules] {
        var allRules: [RobotsRules] = []
        var currentRules: RobotsRules?
        var sitemaps: [String] = []
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            // Remove comments
            let cleanLine = line.components(separatedBy: "#").first?.trimmingCharacters(in: .whitespaces) ?? ""
            
            guard !cleanLine.isEmpty else { continue }
            
            // Parse directive
            let parts = cleanLine.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            
            let directive = parts[0].lowercased()
            let value = parts[1]
            
            switch directive {
            case "user-agent":
                // Save previous rules
                if let rules = currentRules {
                    allRules.append(rules)
                }
                currentRules = RobotsRules(userAgent: value.lowercased())
                
            case "disallow":
                currentRules?.disallowedPaths.append(value)
                
            case "allow":
                currentRules?.allowedPaths.append(value)
                
            case "crawl-delay":
                if let delay = Double(value) {
                    currentRules?.crawlDelay = delay
                }
                
            case "sitemap":
                sitemaps.append(value)
                
            default:
                break
            }
        }
        
        // Save last rules
        if let rules = currentRules {
            allRules.append(rules)
        }
        
        // Add sitemaps to all rules
        allRules = allRules.map { rules in
            var updated = rules
            updated.sitemaps = sitemaps
            return updated
        }
        
        return allRules
    }
    
    private func findMatchingRules(for userAgent: String, in rules: [RobotsRules]) -> RobotsRules? {
        let agent = userAgent.lowercased()
        
        // Look for exact match first
        if let exact = rules.first(where: { $0.userAgent == agent }) {
            return exact
        }
        
        // Look for partial match
        if let partial = rules.first(where: { agent.contains($0.userAgent) || $0.userAgent.contains(agent) }) {
            return partial
        }
        
        // Fall back to wildcard
        return rules.first(where: { $0.userAgent == "*" })
    }
    
    private func isPathAllowed(_ path: String, rules: [RobotsRules], userAgent: String) -> Bool {
        guard let matchingRules = findMatchingRules(for: userAgent, in: rules) else {
            // No matching rules - everything allowed
            return true
        }
        
        // Check explicit allows first (they take precedence)
        for allowPath in matchingRules.allowedPaths {
            if pathMatches(path, pattern: allowPath) {
                return true
            }
        }
        
        // Check disallows
        for disallowPath in matchingRules.disallowedPaths {
            if pathMatches(path, pattern: disallowPath) {
                return false
            }
        }
        
        // Default: allowed
        return true
    }
    
    private func pathMatches(_ path: String, pattern: String) -> Bool {
        // Empty pattern matches nothing
        guard !pattern.isEmpty else { return false }
        
        // Handle wildcards
        if pattern.contains("*") {
            let regex = pattern
                .replacingOccurrences(of: ".", with: "\\.")
                .replacingOccurrences(of: "*", with: ".*")
            
            if let regex = try? NSRegularExpression(pattern: "^\(regex)") {
                let range = NSRange(path.startIndex..., in: path)
                return regex.firstMatch(in: path, range: range) != nil
            }
        }
        
        // Handle $ (end anchor)
        if pattern.hasSuffix("$") {
            let cleanPattern = String(pattern.dropLast())
            return path == cleanPattern
        }
        
        // Simple prefix match
        return path.hasPrefix(pattern)
    }
    
    private func cacheRules(_ rules: [RobotsRules], for host: String) {
        let cached = CachedRules(
            rules: rules,
            fetchedAt: Date(),
            expiresAt: Date().addingTimeInterval(3600)  // 1 hour cache
        )
        cache[host] = cached
    }
}

// MARK: - Errors

enum RobotsError: LocalizedError {
    case invalidURL
    case fetchFailed
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for robots.txt"
        case .fetchFailed:
            return "Failed to fetch robots.txt"
        case .parseError:
            return "Failed to parse robots.txt"
        }
    }
}
