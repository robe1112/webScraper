//
//  URLValidator.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation

/// Validates and normalizes URLs for scraping
struct URLValidator {
    
    // MARK: - Validation
    
    /// Validate a URL string
    static func validate(_ urlString: String) -> ValidationResult {
        // Check for empty string
        guard !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalid(reason: "URL cannot be empty")
        }
        
        // Try to create URL
        guard let url = URL(string: urlString) else {
            return .invalid(reason: "Invalid URL format")
        }
        
        // Check for scheme
        guard let scheme = url.scheme?.lowercased() else {
            return .invalid(reason: "URL must include a scheme (http:// or https://)")
        }
        
        // Only allow http and https
        guard scheme == "http" || scheme == "https" else {
            return .invalid(reason: "Only HTTP and HTTPS URLs are supported")
        }
        
        // Check for host
        guard url.host != nil, !url.host!.isEmpty else {
            return .invalid(reason: "URL must include a host")
        }
        
        // Check for localhost/internal IPs (warning, not invalid)
        if isLocalAddress(url.host!) {
            return .warning(url: url, message: "This appears to be a local address")
        }
        
        return .valid(url: url)
    }
    
    /// Check if a URL is valid for scraping
    static func isValidForScraping(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        guard scheme == "http" || scheme == "https" else { return false }
        guard url.host != nil else { return false }
        return true
    }
    
    // MARK: - Normalization
    
    /// Normalize a URL for comparison and deduplication
    static func normalize(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        
        // Lowercase scheme and host
        components?.scheme = components?.scheme?.lowercased()
        components?.host = components?.host?.lowercased()
        
        // Remove default ports
        if components?.port == 80 && components?.scheme == "http" {
            components?.port = nil
        }
        if components?.port == 443 && components?.scheme == "https" {
            components?.port = nil
        }
        
        // Remove fragment
        components?.fragment = nil
        
        // Sort query parameters
        if var queryItems = components?.queryItems, !queryItems.isEmpty {
            // Remove empty values
            queryItems = queryItems.filter { $0.value != nil && !$0.value!.isEmpty }
            // Sort by name
            queryItems.sort { $0.name < $1.name }
            components?.queryItems = queryItems.isEmpty ? nil : queryItems
        }
        
        // Normalize path
        if var path = components?.path {
            // Remove trailing slash (except for root)
            if path.count > 1 && path.hasSuffix("/") {
                path = String(path.dropLast())
            }
            // Collapse multiple slashes
            while path.contains("//") {
                path = path.replacingOccurrences(of: "//", with: "/")
            }
            components?.path = path
        }
        
        return components?.url?.absoluteString ?? url.absoluteString
    }
    
    /// Resolve a relative URL against a base URL
    static func resolve(_ relative: String, against base: URL) -> URL? {
        // Handle absolute URLs
        if relative.hasPrefix("http://") || relative.hasPrefix("https://") {
            return URL(string: relative)
        }
        
        // Handle protocol-relative URLs
        if relative.hasPrefix("//") {
            return URL(string: (base.scheme ?? "https") + ":" + relative)
        }
        
        // Handle root-relative URLs
        if relative.hasPrefix("/") {
            var components = URLComponents(url: base, resolvingAgainstBaseURL: true)
            components?.path = relative
            components?.query = nil
            components?.fragment = nil
            return components?.url
        }
        
        // Handle relative URLs
        return URL(string: relative, relativeTo: base)?.absoluteURL
    }
    
    // MARK: - Domain Extraction
    
    /// Extract the domain from a URL
    static func extractDomain(_ url: URL) -> String? {
        url.host?.lowercased()
    }
    
    /// Extract the base domain (e.g., "example.com" from "www.subdomain.example.com")
    static func extractBaseDomain(_ url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        
        let parts = host.split(separator: ".")
        guard parts.count >= 2 else { return host }
        
        // Simple heuristic: take last 2 parts for most TLDs
        // This doesn't handle all cases (e.g., .co.uk) but works for common cases
        let baseParts = parts.suffix(2)
        return baseParts.joined(separator: ".")
    }
    
    /// Check if two URLs are from the same domain
    static func isSameDomain(_ url1: URL, _ url2: URL) -> Bool {
        extractDomain(url1) == extractDomain(url2)
    }
    
    /// Check if two URLs are from the same base domain
    static func isSameBaseDomain(_ url1: URL, _ url2: URL) -> Bool {
        extractBaseDomain(url1) == extractBaseDomain(url2)
    }
    
    // MARK: - URL Classification
    
    /// Determine the type of content a URL likely points to
    static func classifyURL(_ url: URL) -> URLType {
        let path = url.path.lowercased()
        let ext = url.pathExtension.lowercased()
        
        // Check by extension
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "svg", "bmp", "tiff", "ico"]
        let documentExtensions = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf"]
        let audioExtensions = ["mp3", "wav", "aac", "flac", "ogg", "m4a"]
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "webm", "wmv", "m4v"]
        let archiveExtensions = ["zip", "rar", "7z", "tar", "gz", "bz2"]
        let dataExtensions = ["json", "xml", "csv", "rss", "atom"]
        
        if imageExtensions.contains(ext) { return .image }
        if ext == "pdf" { return .pdf }
        if documentExtensions.contains(ext) { return .document }
        if audioExtensions.contains(ext) { return .audio }
        if videoExtensions.contains(ext) { return .video }
        if archiveExtensions.contains(ext) { return .archive }
        if dataExtensions.contains(ext) { return .data }
        if ext == "js" { return .script }
        if ext == "css" { return .stylesheet }
        
        // Check for special URL patterns
        if path.contains("/api/") || path.contains("/v1/") || path.contains("/v2/") {
            return .api
        }
        
        // Default to page for HTML-like paths
        return .page
    }
    
    // MARK: - Private Methods
    
    private static func isLocalAddress(_ host: String) -> Bool {
        let localPatterns = [
            "localhost",
            "127.0.0.1",
            "0.0.0.0",
            "::1"
        ]
        
        if localPatterns.contains(host.lowercased()) {
            return true
        }
        
        // Check for private IP ranges
        if host.hasPrefix("192.168.") || host.hasPrefix("10.") || host.hasPrefix("172.") {
            return true
        }
        
        return false
    }
}

// MARK: - Supporting Types

enum ValidationResult {
    case valid(url: URL)
    case warning(url: URL, message: String)
    case invalid(reason: String)
    
    var isValid: Bool {
        switch self {
        case .valid, .warning:
            return true
        case .invalid:
            return false
        }
    }
    
    var url: URL? {
        switch self {
        case .valid(let url), .warning(let url, _):
            return url
        case .invalid:
            return nil
        }
    }
}

enum URLType: String, CaseIterable {
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
    case api = "API"
    case other = "Other"
}
