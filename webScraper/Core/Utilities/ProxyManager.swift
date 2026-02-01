//
//  ProxyManager.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation

/// Manages proxy configuration and rotation
actor ProxyManager {
    
    // MARK: - Types
    
    struct ProxyConfiguration: Codable, Identifiable, Equatable {
        let id: UUID
        var name: String
        var host: String
        var port: Int
        var type: ProxyType
        var username: String?
        var password: String?
        var isEnabled: Bool
        var lastUsed: Date?
        var successCount: Int
        var failureCount: Int
        
        init(
            id: UUID = UUID(),
            name: String = "",
            host: String,
            port: Int,
            type: ProxyType = .http,
            username: String? = nil,
            password: String? = nil,
            isEnabled: Bool = true,
            lastUsed: Date? = nil,
            successCount: Int = 0,
            failureCount: Int = 0
        ) {
            self.id = id
            self.name = name.isEmpty ? "\(host):\(port)" : name
            self.host = host
            self.port = port
            self.type = type
            self.username = username
            self.password = password
            self.isEnabled = isEnabled
            self.lastUsed = lastUsed
            self.successCount = successCount
            self.failureCount = failureCount
        }
        
        var successRate: Double {
            let total = successCount + failureCount
            guard total > 0 else { return 1.0 }
            return Double(successCount) / Double(total)
        }
    }
    
    enum ProxyType: String, Codable, CaseIterable {
        case http = "HTTP"
        case https = "HTTPS"
        case socks4 = "SOCKS4"
        case socks5 = "SOCKS5"
    }
    
    enum RotationStrategy {
        case roundRobin
        case random
        case leastUsed
        case bestPerformance
    }
    
    // MARK: - Properties
    
    private var proxies: [ProxyConfiguration] = []
    private var currentIndex: Int = 0
    private var rotationStrategy: RotationStrategy = .roundRobin
    private var proxyEnabled: Bool = false
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Configuration
    
    /// Enable or disable proxy usage
    func setProxyEnabled(_ enabled: Bool) {
        proxyEnabled = enabled
    }
    
    /// Check if proxy is enabled
    func isProxyEnabled() -> Bool {
        proxyEnabled && !proxies.isEmpty
    }
    
    /// Set rotation strategy
    func setRotationStrategy(_ strategy: RotationStrategy) {
        rotationStrategy = strategy
    }
    
    /// Add a proxy configuration
    func addProxy(_ proxy: ProxyConfiguration) {
        proxies.append(proxy)
    }
    
    /// Remove a proxy by ID
    func removeProxy(id: UUID) {
        proxies.removeAll { $0.id == id }
    }
    
    /// Update a proxy configuration
    func updateProxy(_ proxy: ProxyConfiguration) {
        if let index = proxies.firstIndex(where: { $0.id == proxy.id }) {
            proxies[index] = proxy
        }
    }
    
    /// Get all proxies
    func getAllProxies() -> [ProxyConfiguration] {
        proxies
    }
    
    /// Get enabled proxies
    func getEnabledProxies() -> [ProxyConfiguration] {
        proxies.filter { $0.isEnabled }
    }
    
    // MARK: - Proxy Selection
    
    /// Get the next proxy based on rotation strategy
    func getNextProxy() -> ProxyConfiguration? {
        let enabled = getEnabledProxies()
        guard !enabled.isEmpty else { return nil }
        
        switch rotationStrategy {
        case .roundRobin:
            return roundRobinSelection(from: enabled)
        case .random:
            return randomSelection(from: enabled)
        case .leastUsed:
            return leastUsedSelection(from: enabled)
        case .bestPerformance:
            return bestPerformanceSelection(from: enabled)
        }
    }
    
    /// Mark a proxy request as successful
    func markSuccess(proxyId: UUID) {
        if let index = proxies.firstIndex(where: { $0.id == proxyId }) {
            proxies[index].successCount += 1
            proxies[index].lastUsed = Date()
        }
    }
    
    /// Mark a proxy request as failed
    func markFailure(proxyId: UUID) {
        if let index = proxies.firstIndex(where: { $0.id == proxyId }) {
            proxies[index].failureCount += 1
            proxies[index].lastUsed = Date()
            
            // Disable proxy if it fails too often
            if proxies[index].successRate < 0.1 && proxies[index].failureCount > 10 {
                proxies[index].isEnabled = false
            }
        }
    }
    
    // MARK: - URLSession Configuration
    
    /// Get proxy dictionary for URLSession configuration
    func getProxyDictionary(for proxy: ProxyConfiguration) -> [AnyHashable: Any] {
        var dict: [AnyHashable: Any] = [:]
        
        switch proxy.type {
        case .http:
            dict[kCFNetworkProxiesHTTPEnable] = true
            dict[kCFNetworkProxiesHTTPProxy] = proxy.host
            dict[kCFNetworkProxiesHTTPPort] = proxy.port
            
        case .https:
            dict[kCFNetworkProxiesHTTPSEnable] = true
            dict[kCFNetworkProxiesHTTPSProxy] = proxy.host
            dict[kCFNetworkProxiesHTTPSPort] = proxy.port
            
        case .socks4, .socks5:
            dict[kCFNetworkProxiesSOCKSEnable] = true
            dict[kCFNetworkProxiesSOCKSProxy] = proxy.host
            dict[kCFNetworkProxiesSOCKSPort] = proxy.port
        }
        
        return dict
    }
    
    /// Create a URLSessionConfiguration with proxy settings
    func createSessionConfiguration(with proxy: ProxyConfiguration?) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        
        if let proxy = proxy, proxyEnabled {
            config.connectionProxyDictionary = getProxyDictionary(for: proxy)
        }
        
        return config
    }
    
    // MARK: - Import/Export
    
    /// Export proxies to JSON
    func exportProxies() throws -> Data {
        try JSONEncoder().encode(proxies)
    }
    
    /// Import proxies from JSON
    func importProxies(from data: Data) throws {
        let imported = try JSONDecoder().decode([ProxyConfiguration].self, from: data)
        proxies.append(contentsOf: imported)
    }
    
    /// Import proxies from a text list (one per line, format: host:port or host:port:user:pass)
    func importFromText(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            let parts = trimmed.split(separator: ":")
            guard parts.count >= 2 else { continue }
            
            let host = String(parts[0])
            guard let port = Int(parts[1]) else { continue }
            
            var proxy = ProxyConfiguration(host: host, port: port)
            
            if parts.count >= 4 {
                proxy.username = String(parts[2])
                proxy.password = String(parts[3])
            }
            
            proxies.append(proxy)
        }
    }
    
    // MARK: - Private Methods
    
    private func roundRobinSelection(from proxies: [ProxyConfiguration]) -> ProxyConfiguration? {
        guard !proxies.isEmpty else { return nil }
        
        currentIndex = (currentIndex + 1) % proxies.count
        return proxies[currentIndex]
    }
    
    private func randomSelection(from proxies: [ProxyConfiguration]) -> ProxyConfiguration? {
        proxies.randomElement()
    }
    
    private func leastUsedSelection(from proxies: [ProxyConfiguration]) -> ProxyConfiguration? {
        proxies.min { ($0.successCount + $0.failureCount) < ($1.successCount + $1.failureCount) }
    }
    
    private func bestPerformanceSelection(from proxies: [ProxyConfiguration]) -> ProxyConfiguration? {
        proxies.max { $0.successRate < $1.successRate }
    }
}
