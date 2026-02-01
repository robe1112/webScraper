//
//  ScrapeConfigurationView.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import SwiftUI

/// View for configuring scrape job settings
struct ScrapeConfigurationView: View {
    @Binding var project: Project
    @Environment(\.dismiss) private var dismiss
    
    @State private var startURL: String = ""
    @State private var maxDepth: Int = 5
    @State private var maxPages: Int = 1000
    @State private var enableJavaScript: Bool = true
    @State private var respectRobotsTxt: Bool = true
    @State private var followExternalLinks: Bool = false
    @State private var requestDelayMs: Int = 1000
    @State private var maxConcurrent: Int = 4
    
    @State private var downloadImages: Bool = true
    @State private var downloadPDFs: Bool = true
    @State private var downloadDocuments: Bool = true
    @State private var downloadAudio: Bool = false
    @State private var downloadVideo: Bool = false
    
    @State private var urlWhitelist: String = ""
    @State private var urlBlacklist: String = ""
    
    @State private var customUserAgent: String = ""
    @State private var selectedTab = 0
    
    var onStartScrape: ((CrawlerEngine.CrawlConfiguration) -> Void)?
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                basicSettingsTab
                    .tabItem {
                        Label("Basic", systemImage: "gear")
                    }
                    .tag(0)
                
                downloadSettingsTab
                    .tabItem {
                        Label("Downloads", systemImage: "arrow.down.circle")
                    }
                    .tag(1)
                
                filterSettingsTab
                    .tabItem {
                        Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .tag(2)
                
                advancedSettingsTab
                    .tabItem {
                        Label("Advanced", systemImage: "slider.horizontal.3")
                    }
                    .tag(3)
            }
            .padding()
            .frame(minWidth: 500, minHeight: 400)
            .navigationTitle("Configure Scrape")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start Scrape") {
                        startScrape()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(startURL.isEmpty)
                }
            }
        }
        .onAppear {
            loadFromProject()
        }
    }
    
    // MARK: - Basic Settings Tab
    
    private var basicSettingsTab: some View {
        Form {
            Section("Target URL") {
                TextField("https://example.com or file:///path/to/TestSite/index.html", text: $startURL)
                    .textFieldStyle(.roundedBorder)
                
                if let validation = validateURL(startURL), !startURL.isEmpty {
                    Label(validation.message, systemImage: validation.icon)
                        .foregroundStyle(validation.color)
                        .font(.caption)
                }
            }
            
            Section("Crawl Limits") {
                Stepper("Max Depth: \(maxDepth)", value: $maxDepth, in: 1...20)
                
                HStack {
                    Text("Max Pages:")
                    TextField("", value: $maxPages, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            }
            
            Section("Behavior") {
                Toggle("Enable JavaScript (for SPAs)", isOn: $enableJavaScript)
                Toggle("Respect robots.txt", isOn: $respectRobotsTxt)
                Toggle("Follow external links", isOn: $followExternalLinks)
            }
            
            Section("Rate Limiting") {
                Stepper("Delay: \(requestDelayMs)ms", value: $requestDelayMs, in: 100...10000, step: 100)
                Stepper("Concurrent requests: \(maxConcurrent)", value: $maxConcurrent, in: 1...20)
            }
        }
    }
    
    // MARK: - Download Settings Tab
    
    private var downloadSettingsTab: some View {
        Form {
            Section("File Types to Download") {
                Toggle("Images (jpg, png, gif, etc.)", isOn: $downloadImages)
                Toggle("PDFs", isOn: $downloadPDFs)
                Toggle("Documents (doc, xls, etc.)", isOn: $downloadDocuments)
                Toggle("Audio files", isOn: $downloadAudio)
                Toggle("Video files", isOn: $downloadVideo)
            }
            
            Section("Size Limit") {
                Stepper("Max file size: \(project.settings.maxFileSizeMB) MB", 
                       value: Binding(
                        get: { project.settings.maxFileSizeMB },
                        set: { project.settings.maxFileSizeMB = $0 }
                       ),
                       in: 1...2000, step: 10)
            }
            
            Section("Organization") {
                Toggle("Organize by file type", isOn: .constant(true))
                Toggle("Organize by date", isOn: .constant(false))
                Toggle("Preserve original filenames", isOn: .constant(true))
            }
        }
    }
    
    // MARK: - Filter Settings Tab
    
    private var filterSettingsTab: some View {
        Form {
            Section("URL Whitelist") {
                Text("Only crawl URLs matching these patterns (one per line)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextEditor(text: $urlWhitelist)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 100)
                    .border(Color.secondary.opacity(0.3))
            }
            
            Section("URL Blacklist") {
                Text("Skip URLs matching these patterns (one per line)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextEditor(text: $urlBlacklist)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 100)
                    .border(Color.secondary.opacity(0.3))
            }
            
            Section("Quick Filters") {
                Toggle("Skip query parameters", isOn: .constant(false))
                Toggle("Skip hash fragments", isOn: .constant(true))
                Toggle("Skip login/logout pages", isOn: .constant(true))
            }
        }
    }
    
    // MARK: - Advanced Settings Tab
    
    private var advancedSettingsTab: some View {
        Form {
            Section("User Agent") {
                TextField("Custom User Agent (optional)", text: $customUserAgent)
                    .textFieldStyle(.roundedBorder)
                
                Text("Leave empty to use default browser user agent")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Cookies") {
                Button("Import Cookies...") {
                    // TODO: Import cookies
                }
                
                Button("Export Cookies...") {
                    // TODO: Export cookies
                }
            }
            
            Section("Authentication") {
                Button("Configure Login...") {
                    // TODO: Configure login
                }
                .disabled(true)  // Not yet implemented
            }
            
            Section("Proxy") {
                Toggle("Use Proxy", isOn: .constant(false))
                    .disabled(true)  // Configured in app settings
                
                Text("Configure proxy in application settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadFromProject() {
        startURL = project.startURL
        maxDepth = project.settings.maxDepth
        maxPages = project.settings.maxPages
        enableJavaScript = project.settings.enableJavaScript
        respectRobotsTxt = project.settings.respectRobotsTxt
        followExternalLinks = project.settings.followExternalLinks
        requestDelayMs = project.settings.requestDelayMs
        maxConcurrent = project.settings.maxConcurrentRequests
        
        downloadImages = project.settings.downloadImages
        downloadPDFs = project.settings.downloadPDFs
        downloadDocuments = project.settings.downloadDocuments
        downloadAudio = project.settings.downloadMedia
        downloadVideo = project.settings.downloadMedia
        
        urlWhitelist = project.settings.urlWhitelist.joined(separator: "\n")
        urlBlacklist = project.settings.urlBlacklist.joined(separator: "\n")
        
        customUserAgent = project.settings.customUserAgent ?? ""
    }
    
    private func validateURL(_ urlString: String) -> (message: String, icon: String, color: Color)? {
        guard !urlString.isEmpty else { return nil }
        
        let result = URLValidator.validate(urlString)
        
        switch result {
        case .valid:
            return ("Valid URL", "checkmark.circle.fill", .green)
        case .warning(_, let message):
            return (message, "exclamationmark.triangle.fill", .orange)
        case .invalid(let reason):
            return (reason, "xmark.circle.fill", .red)
        }
    }
    
    private func startScrape() {
        var downloadTypes: [FileType] = []
        if downloadImages { downloadTypes.append(.image) }
        if downloadPDFs { downloadTypes.append(.pdf) }
        if downloadDocuments { downloadTypes.append(.document) }
        if downloadAudio { downloadTypes.append(.audio) }
        if downloadVideo { downloadTypes.append(.video) }
        
        let config = CrawlerEngine.CrawlConfiguration(
            strategy: .breadthFirst,
            maxDepth: maxDepth,
            maxPages: maxPages,
            followExternalLinks: followExternalLinks,
            respectRobotsTxt: respectRobotsTxt,
            enableJavaScript: enableJavaScript,
            requestDelayMs: requestDelayMs,
            maxConcurrentRequests: maxConcurrent,
            urlWhitelist: urlWhitelist.components(separatedBy: .newlines).filter { !$0.isEmpty },
            urlBlacklist: urlBlacklist.components(separatedBy: .newlines).filter { !$0.isEmpty },
            downloadFileTypes: downloadTypes,
            userAgent: customUserAgent.isEmpty ? "WebScraperBot/1.0" : customUserAgent
        )
        
        onStartScrape?(config)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    ScrapeConfigurationView(project: .constant(Project(
        name: "Test Project",
        startURL: "https://example.com"
    )))
}
