//
//  JSRenderer.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation
import WebKit

/// Renders JavaScript-heavy pages using WKWebView
/// Used for SPAs and pages that require JavaScript execution
@MainActor
final class JSRenderer: NSObject {
    
    // MARK: - Configuration
    
    struct Configuration {
        var timeoutSeconds: TimeInterval
        var waitAfterLoadSeconds: TimeInterval
        var userAgent: String
        var enableImages: Bool
        var enableStyles: Bool
        var customScripts: [String]
        var waitForSelectors: [String]
        
        init(
            timeoutSeconds: TimeInterval = 30,
            waitAfterLoadSeconds: TimeInterval = 2,
            userAgent: String = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            enableImages: Bool = true,
            enableStyles: Bool = true,
            customScripts: [String] = [],
            waitForSelectors: [String] = []
        ) {
            self.timeoutSeconds = timeoutSeconds
            self.waitAfterLoadSeconds = waitAfterLoadSeconds
            self.userAgent = userAgent
            self.enableImages = enableImages
            self.enableStyles = enableStyles
            self.customScripts = customScripts
            self.waitForSelectors = waitForSelectors
        }
    }
    
    // MARK: - Response Type
    
    struct RenderResult {
        let url: URL
        let finalURL: URL
        let htmlContent: String
        let textContent: String
        let title: String?
        let screenshot: Data?
        let consoleMessages: [String]
        let networkRequests: [NetworkRequest]
        let renderTime: TimeInterval
        let success: Bool
        let errorMessage: String?
    }
    
    struct NetworkRequest {
        let url: URL
        let method: String
        let statusCode: Int?
        let contentType: String?
    }
    
    // MARK: - Properties
    
    private var configuration: Configuration
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<RenderResult, Error>?
    private var consoleMessages: [String] = []
    private var networkRequests: [NetworkRequest] = []
    private var startTime: Date?
    private var currentURL: URL?
    
    // MARK: - Initialization
    
    override init() {
        self.configuration = Configuration()
        super.init()
    }
    
    init(configuration: Configuration) {
        self.configuration = configuration
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Update configuration
    func updateConfiguration(_ config: Configuration) {
        self.configuration = config
    }
    
    /// Render a page with JavaScript
    func render(url: URL, captureScreenshot: Bool = false) async throws -> RenderResult {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.consoleMessages = []
            self.networkRequests = []
            self.startTime = Date()
            self.currentURL = url
            
            // Create web view configuration
            let config = WKWebViewConfiguration()
            config.applicationNameForUserAgent = configuration.userAgent
            
            // Add content controller for JavaScript messages
            let contentController = WKUserContentController()
            
            // Inject console capture script
            let consoleScript = WKUserScript(
                source: """
                    (function() {
                        var oldLog = console.log;
                        var oldWarn = console.warn;
                        var oldError = console.error;
                        console.log = function() {
                            window.webkit.messageHandlers.console.postMessage({type: 'log', args: Array.from(arguments).map(String)});
                            oldLog.apply(console, arguments);
                        };
                        console.warn = function() {
                            window.webkit.messageHandlers.console.postMessage({type: 'warn', args: Array.from(arguments).map(String)});
                            oldWarn.apply(console, arguments);
                        };
                        console.error = function() {
                            window.webkit.messageHandlers.console.postMessage({type: 'error', args: Array.from(arguments).map(String)});
                            oldError.apply(console, arguments);
                        };
                    })();
                    """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            contentController.addUserScript(consoleScript)
            contentController.add(self, name: "console")
            
            // Add custom scripts
            for script in configuration.customScripts {
                let userScript = WKUserScript(
                    source: script,
                    injectionTime: .atDocumentEnd,
                    forMainFrameOnly: true
                )
                contentController.addUserScript(userScript)
            }
            
            config.userContentController = contentController
            
            // Preferences
            let prefs = WKWebpagePreferences()
            prefs.allowsContentJavaScript = true
            config.defaultWebpagePreferences = prefs
            
            // Create web view
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), configuration: config)
            webView.navigationDelegate = self
            webView.customUserAgent = configuration.userAgent
            self.webView = webView
            
            // Load the URL
            let request = URLRequest(url: url, timeoutInterval: configuration.timeoutSeconds)
            webView.load(request)
            
            // Set timeout
            Task {
                try? await Task.sleep(nanoseconds: UInt64(configuration.timeoutSeconds * 1_000_000_000))
                if self.continuation != nil {
                    self.completeWithError(JSRenderError.timeout)
                }
            }
        }
    }
    
    /// Execute JavaScript on the current page
    func executeScript(_ script: String) async throws -> Any? {
        guard let webView = webView else {
            throw JSRenderError.noWebView
        }
        
        return try await webView.evaluateJavaScript(script)
    }
    
    /// Wait for a specific selector to appear
    func waitForSelector(_ selector: String, timeout: TimeInterval = 10) async throws -> Bool {
        guard webView != nil else {
            throw JSRenderError.noWebView
        }
        
        let script = """
            (function() {
                return document.querySelector('\(selector)') !== null;
            })();
            """
        
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            if let result = try? await executeScript(script) as? Bool, result {
                return true
            }
            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        }
        
        return false
    }
    
    /// Click an element by selector
    func click(selector: String) async throws {
        let script = """
            (function() {
                var element = document.querySelector('\(selector)');
                if (element) {
                    element.click();
                    return true;
                }
                return false;
            })();
            """
        
        guard let result = try await executeScript(script) as? Bool, result else {
            throw JSRenderError.elementNotFound(selector)
        }
    }
    
    /// Fill a form field
    func fillField(selector: String, value: String) async throws {
        let escapedValue = value.replacingOccurrences(of: "'", with: "\\'")
        let script = """
            (function() {
                var element = document.querySelector('\(selector)');
                if (element) {
                    element.value = '\(escapedValue)';
                    element.dispatchEvent(new Event('input', { bubbles: true }));
                    element.dispatchEvent(new Event('change', { bubbles: true }));
                    return true;
                }
                return false;
            })();
            """
        
        guard let result = try await executeScript(script) as? Bool, result else {
            throw JSRenderError.elementNotFound(selector)
        }
    }
    
    /// Get current HTML content
    func getHTML() async throws -> String {
        guard webView != nil else {
            throw JSRenderError.noWebView
        }
        
        let script = "document.documentElement.outerHTML"
        guard let html = try await executeScript(script) as? String else {
            throw JSRenderError.extractionFailed
        }
        
        return html
    }
    
    /// Get current text content
    func getText() async throws -> String {
        guard webView != nil else {
            throw JSRenderError.noWebView
        }
        
        let script = "document.body.innerText"
        guard let text = try await executeScript(script) as? String else {
            throw JSRenderError.extractionFailed
        }
        
        return text
    }
    
    /// Take a screenshot
    func screenshot() async throws -> Data {
        guard let webView = webView else {
            throw JSRenderError.noWebView
        }
        
        let config = WKSnapshotConfiguration()
        config.rect = webView.bounds
        
        let image = try await webView.takeSnapshot(configuration: config)
        
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw JSRenderError.screenshotFailed
        }
        
        return pngData
    }
    
    /// Cleanup resources
    func cleanup() {
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
        continuation = nil
    }
    
    // MARK: - Private Methods
    
    private func completeWithResult(_ result: RenderResult) {
        continuation?.resume(returning: result)
        continuation = nil
    }
    
    private func completeWithError(_ error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
        cleanup()
    }
    
    private func finishRendering(captureScreenshot: Bool = false) async {
        guard let webView = webView,
              let startTime = startTime,
              let currentURL = currentURL else {
            completeWithError(JSRenderError.unknown)
            return
        }
        
        // Wait additional time for JavaScript to execute
        try? await Task.sleep(nanoseconds: UInt64(configuration.waitAfterLoadSeconds * 1_000_000_000))
        
        // Wait for specific selectors if configured
        for selector in configuration.waitForSelectors {
            _ = try? await waitForSelector(selector, timeout: 5)
        }
        
        do {
            let html = try await getHTML()
            let text = try await getText()
            
            let title = try? await executeScript("document.title") as? String
            
            var screenshotData: Data?
            if captureScreenshot {
                screenshotData = try? await screenshot()
            }
            
            let result = RenderResult(
                url: currentURL,
                finalURL: webView.url ?? currentURL,
                htmlContent: html,
                textContent: text,
                title: title,
                screenshot: screenshotData,
                consoleMessages: consoleMessages,
                networkRequests: networkRequests,
                renderTime: Date().timeIntervalSince(startTime),
                success: true,
                errorMessage: nil
            )
            
            completeWithResult(result)
        } catch {
            completeWithError(error)
        }
    }
}

// MARK: - WKNavigationDelegate

extension JSRenderer: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task {
            await finishRendering()
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        completeWithError(JSRenderError.navigationFailed(error))
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        completeWithError(JSRenderError.navigationFailed(error))
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        if let url = navigationAction.request.url {
            networkRequests.append(NetworkRequest(
                url: url,
                method: navigationAction.request.httpMethod ?? "GET",
                statusCode: nil,
                contentType: nil
            ))
        }
        return .allow
    }
}

// MARK: - WKScriptMessageHandler

extension JSRenderer: WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "console",
           let body = message.body as? [String: Any],
           let type = body["type"] as? String,
           let args = body["args"] as? [String] {
            let msg = "[\(type)] \(args.joined(separator: " "))"
            consoleMessages.append(msg)
        }
    }
}

// MARK: - Errors

enum JSRenderError: LocalizedError {
    case timeout
    case noWebView
    case navigationFailed(Error)
    case extractionFailed
    case screenshotFailed
    case elementNotFound(String)
    case scriptError(Error)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Page load timed out"
        case .noWebView:
            return "WebView not initialized"
        case .navigationFailed(let error):
            return "Navigation failed: \(error.localizedDescription)"
        case .extractionFailed:
            return "Failed to extract content"
        case .screenshotFailed:
            return "Failed to capture screenshot"
        case .elementNotFound(let selector):
            return "Element not found: \(selector)"
        case .scriptError(let error):
            return "Script error: \(error.localizedDescription)"
        case .unknown:
            return "Unknown error"
        }
    }
}
