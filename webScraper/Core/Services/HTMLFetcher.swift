//
//  HTMLFetcher.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation

/// Fetches HTML content from URLs using URLSession
/// Handles headers, cookies, caching, and retry logic
actor HTMLFetcher {
    
    // MARK: - Configuration
    
    struct Configuration {
        var timeoutSeconds: TimeInterval
        var userAgent: String
        var customHeaders: [String: String]
        var followRedirects: Bool
        var maxRedirects: Int
        var cachePolicy: URLRequest.CachePolicy
        var retryCount: Int
        var retryDelayMs: Int
        
        init(
            timeoutSeconds: TimeInterval = 30,
            userAgent: String = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            customHeaders: [String: String] = [:],
            followRedirects: Bool = true,
            maxRedirects: Int = 10,
            cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData,
            retryCount: Int = 3,
            retryDelayMs: Int = 1000
        ) {
            self.timeoutSeconds = timeoutSeconds
            self.userAgent = userAgent
            self.customHeaders = customHeaders
            self.followRedirects = followRedirects
            self.maxRedirects = maxRedirects
            self.cachePolicy = cachePolicy
            self.retryCount = retryCount
            self.retryDelayMs = retryDelayMs
        }
    }
    
    // MARK: - Response Type
    
    struct FetchResult {
        let url: URL
        let finalURL: URL  // After redirects
        let statusCode: Int
        let headers: [String: String]
        let data: Data
        let htmlContent: String?
        let contentType: String?
        let contentLength: Int64?
        let responseTime: TimeInterval
        let redirectChain: [URL]
    }
    
    // MARK: - Properties
    
    private var configuration: Configuration
    private var session: URLSession
    private var cookieStorage: HTTPCookieStorage
    
    // MARK: - Initialization
    
    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.cookieStorage = HTTPCookieStorage.shared
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeoutSeconds
        sessionConfig.timeoutIntervalForResource = configuration.timeoutSeconds * 2
        sessionConfig.httpCookieStorage = cookieStorage
        sessionConfig.httpCookieAcceptPolicy = .always
        sessionConfig.httpShouldSetCookies = true
        
        self.session = URLSession(configuration: sessionConfig)
    }
    
    // MARK: - Public Methods
    
    /// Update configuration
    func updateConfiguration(_ config: Configuration) {
        self.configuration = config
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.timeoutSeconds
        sessionConfig.timeoutIntervalForResource = config.timeoutSeconds * 2
        sessionConfig.httpCookieStorage = cookieStorage
        
        self.session = URLSession(configuration: sessionConfig)
    }
    
    /// Fetch HTML from a URL
    func fetch(url: URL) async throws -> FetchResult {
        var lastError: Error?
        var attempts = 0
        
        while attempts < configuration.retryCount {
            do {
                return try await performFetch(url: url)
            } catch {
                lastError = error
                attempts += 1
                
                if attempts < configuration.retryCount {
                    // Exponential backoff
                    let delay = UInt64(configuration.retryDelayMs * (1 << (attempts - 1))) * 1_000_000
                    try? await Task.sleep(nanoseconds: delay)
                }
            }
        }
        
        throw lastError ?? FetchError.unknown
    }
    
    /// Fetch multiple URLs concurrently
    func fetchMultiple(urls: [URL], maxConcurrent: Int = 4) async -> [URL: Result<FetchResult, Error>] {
        await withTaskGroup(of: (URL, Result<FetchResult, Error>).self) { group in
            var results: [URL: Result<FetchResult, Error>] = [:]
            var pending = urls[...]
            
            // Start initial batch
            for _ in 0..<min(maxConcurrent, urls.count) {
                if let url = pending.popFirst() {
                    group.addTask {
                        do {
                            let result = try await self.fetch(url: url)
                            return (url, .success(result))
                        } catch {
                            return (url, .failure(error))
                        }
                    }
                }
            }
            
            // Process results and add more tasks
            for await (url, result) in group {
                results[url] = result
                
                // Add next URL if available
                if let nextURL = pending.popFirst() {
                    group.addTask {
                        do {
                            let result = try await self.fetch(url: nextURL)
                            return (nextURL, .success(result))
                        } catch {
                            return (nextURL, .failure(error))
                        }
                    }
                }
            }
            
            return results
        }
    }
    
    /// Get cookies for a URL
    func getCookies(for url: URL) -> [HTTPCookie] {
        cookieStorage.cookies(for: url) ?? []
    }
    
    /// Set cookies for a URL
    func setCookies(_ cookies: [HTTPCookie], for url: URL) {
        for cookie in cookies {
            cookieStorage.setCookie(cookie)
        }
    }
    
    /// Clear all cookies
    func clearCookies() {
        if let cookies = cookieStorage.cookies {
            for cookie in cookies {
                cookieStorage.deleteCookie(cookie)
            }
        }
    }
    
    /// Export cookies as JSON
    func exportCookies() throws -> Data {
        let cookies = cookieStorage.cookies ?? []
        let cookieData = cookies.compactMap { cookie -> [String: Any]? in
            var dict: [String: Any] = [
                "name": cookie.name,
                "value": cookie.value,
                "domain": cookie.domain,
                "path": cookie.path,
                "secure": cookie.isSecure,
                "httpOnly": cookie.isHTTPOnly
            ]
            if let expires = cookie.expiresDate {
                dict["expires"] = expires.timeIntervalSince1970
            }
            return dict
        }
        return try JSONSerialization.data(withJSONObject: cookieData)
    }
    
    /// Import cookies from JSON
    func importCookies(from data: Data) throws {
        guard let cookieData = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw FetchError.invalidCookieData
        }
        
        for dict in cookieData {
            if let cookie = HTTPCookie(properties: [
                .name: dict["name"] as? String ?? "",
                .value: dict["value"] as? String ?? "",
                .domain: dict["domain"] as? String ?? "",
                .path: dict["path"] as? String ?? "/",
                .secure: dict["secure"] as? Bool ?? false,
                .expires: dict["expires"].flatMap { Date(timeIntervalSince1970: $0 as? Double ?? 0) } as Any
            ]) {
                cookieStorage.setCookie(cookie)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func performFetch(url: URL) async throws -> FetchResult {
        let startTime = Date()

        // Handle file:// URLs directly - URLSession returns non-HTTP response for file protocol
        if url.isFileURL {
            return try await fetchFileURL(url, startTime: startTime)
        }

        var redirectChain: [URL] = []
        var currentURL = url
        var redirectCount = 0
        
        // Create request
        var request = URLRequest(url: url)
        request.cachePolicy = configuration.cachePolicy
        request.timeoutInterval = configuration.timeoutSeconds
        
        // Set headers
        request.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        
        for (key, value) in configuration.customHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Perform request with redirect handling
        var response: URLResponse?
        var data: Data?
        
        while true {
            request.url = currentURL
            
            let (responseData, urlResponse) = try await session.data(for: request)
            data = responseData
            response = urlResponse
            
            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                throw FetchError.invalidResponse
            }
            
            // Handle redirects manually if needed
            if configuration.followRedirects,
               (300...399).contains(httpResponse.statusCode),
               let location = httpResponse.value(forHTTPHeaderField: "Location"),
               let redirectURL = URL(string: location, relativeTo: currentURL) {
                
                redirectCount += 1
                if redirectCount > configuration.maxRedirects {
                    throw FetchError.tooManyRedirects
                }
                
                redirectChain.append(currentURL)
                currentURL = redirectURL.absoluteURL
                continue
            }
            
            break
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              let responseData = data else {
            throw FetchError.invalidResponse
        }
        
        let responseTime = Date().timeIntervalSince(startTime)
        
        // Parse headers
        var headers: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            if let keyString = key as? String, let valueString = value as? String {
                headers[keyString] = valueString
            }
        }
        
        // Parse content
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")
        let contentLength = Int64(httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "") ?? Int64(responseData.count)
        
        // Detect encoding and decode HTML
        var htmlContent: String?
        if let contentType = contentType, contentType.contains("text") || contentType.contains("html") || contentType.contains("xml") {
            // Try to detect encoding from content type
            var encoding = String.Encoding.utf8
            if contentType.lowercased().contains("charset=") {
                let parts = contentType.lowercased().components(separatedBy: "charset=")
                if parts.count > 1 {
                    let charsetName = parts[1].trimmingCharacters(in: .whitespaces).components(separatedBy: ";").first ?? ""
                    encoding = encodingFromCharset(charsetName)
                }
            }
            
            htmlContent = String(data: responseData, encoding: encoding)
            
            // Fallback to other encodings
            if htmlContent == nil {
                for fallbackEncoding in [String.Encoding.isoLatin1, .windowsCP1252, .ascii] {
                    if let decoded = String(data: responseData, encoding: fallbackEncoding) {
                        htmlContent = decoded
                        break
                    }
                }
            }
        }
        
        return FetchResult(
            url: url,
            finalURL: currentURL,
            statusCode: httpResponse.statusCode,
            headers: headers,
            data: responseData,
            htmlContent: htmlContent,
            contentType: contentType,
            contentLength: contentLength,
            responseTime: responseTime,
            redirectChain: redirectChain
        )
    }
    
    private func fetchFileURL(_ url: URL, startTime: Date) async throws -> FetchResult {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw FetchError.networkError(error)
        }
        
        let responseTime = Date().timeIntervalSince(startTime)
        let contentLength = Int64(data.count)
        
        // Detect content type from extension
        let ext = url.pathExtension.lowercased()
        let contentType: String?
        switch ext {
        case "html", "htm": contentType = "text/html; charset=utf-8"
        case "xml": contentType = "application/xml"
        case "xhtml": contentType = "application/xhtml+xml"
        default: contentType = "application/octet-stream"
        }
        
        var htmlContent: String?
        if contentType?.contains("text") == true || contentType?.contains("html") == true || contentType?.contains("xml") == true {
            htmlContent = String(data: data, encoding: .utf8)
            if htmlContent == nil {
                htmlContent = String(data: data, encoding: .isoLatin1)
            }
        }
        
        return FetchResult(
            url: url,
            finalURL: url,
            statusCode: 200,
            headers: [:],
            data: data,
            htmlContent: htmlContent,
            contentType: contentType,
            contentLength: contentLength,
            responseTime: responseTime,
            redirectChain: []
        )
    }
    
    private func encodingFromCharset(_ charset: String) -> String.Encoding {
        switch charset.lowercased() {
        case "utf-8", "utf8":
            return .utf8
        case "iso-8859-1", "latin1":
            return .isoLatin1
        case "windows-1252", "cp1252":
            return .windowsCP1252
        case "ascii", "us-ascii":
            return .ascii
        case "utf-16", "utf16":
            return .utf16
        default:
            return .utf8
        }
    }
}

// MARK: - Errors

enum FetchError: LocalizedError {
    case invalidURL
    case invalidResponse
    case tooManyRedirects
    case invalidCookieData
    case timeout
    case networkError(Error)
    case httpError(statusCode: Int)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .tooManyRedirects:
            return "Too many redirects"
        case .invalidCookieData:
            return "Invalid cookie data"
        case .timeout:
            return "Request timed out"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .unknown:
            return "Unknown error"
        }
    }
}
