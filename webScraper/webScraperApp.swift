//
//  webScraperApp.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import SwiftUI
import UniformTypeIdentifiers

@main
struct webScraperApp: App {
    
    // MARK: - State
    
    @StateObject private var appState = AppState()
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
                .environmentObject(appState.featureFlags)
                .withPluginManager(appState.pluginManager)
                .task {
                    await appState.pluginManager.initializePlugins()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Project") {
                    appState.showNewProjectSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Divider()
                
                Button("Import Project...") {}
                    .disabled(true)
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                
                Button("Export Project...") {}
                    .disabled(true)
                    .keyboardShortcut("e", modifiers: [.command, .shift])
            }
            
            // Edit menu additions
            CommandGroup(after: .pasteboard) {
                Divider()
                
                Button("Find in Project") {}
                    .disabled(true)
                    .keyboardShortcut("f", modifiers: [.command, .shift])
            }
            
            // View menu
            CommandMenu("Scraping") {
                Button("Start Scrape") {}
                    .disabled(true)
                    .keyboardShortcut("r", modifiers: .command)
                
                Button("Pause Scrape") {}
                    .disabled(true)
                    .keyboardShortcut(".", modifiers: .command)
                
                Button("Stop Scrape") {}
                    .disabled(true)
                    .keyboardShortcut(".", modifiers: [.command, .shift])
                
                Divider()
                
                Button("View Site Map") {
                    appState.selectedSidebarItem = .siteMap
                }
                .keyboardShortcut("m", modifiers: [.command, .option])
                
                Button("View Downloads") {
                    appState.selectedSidebarItem = .downloads
                }
                .keyboardShortcut("d", modifiers: [.command, .option])
                
                Button("View Changes") {
                    appState.selectedSidebarItem = .diff
                }
                .keyboardShortcut("c", modifiers: [.command, .option])
            }
            
            // Help menu
            CommandGroup(replacing: .help) {
                Button("webScraper Help") {}
                    .disabled(true)
                
                Divider()
                
                Button("Report an Issue...") {}
                    .disabled(true)
                
                Button("Check for Updates...") {}
                    .disabled(true)
            }
        }
        
        // Settings window
        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(appState.featureFlags)
        }
        
        // Menu bar extra for background monitoring
        MenuBarExtra("webScraper", systemImage: "globe.badge.chevron.backward") {
            MenuBarView()
                .environmentObject(appState)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var featureFlags: FeatureFlags
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .environmentObject(appState.globalSettings)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            ScrapingSettingsView()
                .environmentObject(appState.globalSettings)
                .tabItem {
                    Label("Scraping", systemImage: "globe")
                }
            
            DownloadSettingsView()
                .environmentObject(appState.globalSettings)
                .tabItem {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }
            
            ProxySettingsView()
                .tabItem {
                    Label("Proxy", systemImage: "network")
                }
            
            PluginSettingsView()
                .tabItem {
                    Label("Plugins", systemImage: "puzzlepiece.extension")
                }
        }
        .frame(width: 550, height: 450)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var globalSettings: GlobalSettings
    @EnvironmentObject var featureFlags: FeatureFlags
    
    var body: some View {
        Form {
            Section("Default Storage") {
                Picker("Storage Type", selection: $globalSettings.defaultStorageType) {
                    ForEach(StorageType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                Text("Default for new projects (can be changed per-project)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Memory") {
                VStack(alignment: .leading) {
                    Text("Max Memory: \(featureFlags.maxMemoryUsageMB) MB")
                    Slider(
                        value: Binding(
                            get: { Double(featureFlags.maxMemoryUsageMB) },
                            set: { featureFlags.maxMemoryUsageMB = Int($0) }
                        ),
                        in: 1024...32768,
                        step: 1024
                    )
                    Text("Recommended: \(FeatureFlags.recommendedMemoryLimit()) MB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section {
                Button("Reset to Defaults") {
                    globalSettings.resetToDefaults()
                    featureFlags.resetToDefaults()
                }
            }
        }
        .padding()
    }
}

// MARK: - Scraping Settings

struct ScrapingSettingsView: View {
    @EnvironmentObject var globalSettings: GlobalSettings
    
    var body: some View {
        Form {
            Section("Default Settings") {
                TextField("User Agent", text: $globalSettings.defaultUserAgent)
                    .textFieldStyle(.roundedBorder)
                Toggle("Respect robots.txt", isOn: $globalSettings.defaultRespectRobotsTxt)
                Toggle("Enable JavaScript", isOn: $globalSettings.defaultEnableJavaScript)
                Text("These defaults apply to new scrape jobs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Rate Limiting") {
                Stepper("Request Delay: \(globalSettings.defaultRequestDelayMs)ms",
                        value: $globalSettings.defaultRequestDelayMs,
                        in: 100...10000,
                        step: 100)
                Stepper("Max Concurrent: \(globalSettings.defaultMaxConcurrentRequests)",
                        value: $globalSettings.defaultMaxConcurrentRequests,
                        in: 1...20)
            }
        }
        .padding()
    }
}

// MARK: - Download Settings

struct DownloadSettingsView: View {
    @EnvironmentObject var globalSettings: GlobalSettings
    @State private var showFolderPicker = false
    
    var body: some View {
        Form {
            Section("Download Location") {
                HStack {
                    Text(globalSettings.downloadLocation.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Choose...") {
                        showFolderPicker = true
                    }
                }
            }
            
            Section("Default File Types") {
                Toggle("Images", isOn: $globalSettings.defaultDownloadImages)
                Toggle("PDFs", isOn: $globalSettings.defaultDownloadPDFs)
                Toggle("Documents", isOn: $globalSettings.defaultDownloadDocuments)
                Toggle("Audio", isOn: $globalSettings.defaultDownloadAudio)
                Toggle("Video", isOn: $globalSettings.defaultDownloadVideo)
                Text("These defaults apply to new scrape jobs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                globalSettings.downloadLocation = url
            }
        }
    }
}

// MARK: - Proxy Settings (Not Yet Implemented)

struct ProxySettingsView: View {
    var body: some View {
        Form {
            Section("Proxy Configuration") {
                Toggle("Enable Proxy", isOn: .constant(false))
                    .disabled(true)
                TextField("Host", text: .constant(""))
                    .disabled(true)
                TextField("Port", text: .constant(""))
                    .disabled(true)
                Picker("Type", selection: .constant(ProxyManager.ProxyType.http)) {
                    ForEach(ProxyManager.ProxyType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .disabled(true)
                Text("Coming in a future update")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Plugin Settings

struct PluginSettingsView: View {
    @EnvironmentObject var featureFlags: FeatureFlags
    
    var body: some View {
        Form {
            Section("Feature Packs") {
                Toggle("Analysis Pack", isOn: $featureFlags.analysisPackEnabled)
                Text("OCR, full-text search, document viewers, AI summarization")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Toggle("Intelligence Pack", isOn: $featureFlags.intelligencePackEnabled)
                    .disabled(!featureFlags.analysisPackEnabled)
                Text("Entity extraction, knowledge graphs, RAG Q&A")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("AI Settings") {
                Toggle("Use Local Models", isOn: $featureFlags.localLLMEnabled)
                Toggle("Allow Cloud Models", isOn: $featureFlags.cloudLLMEnabled)
                Toggle("Prefer Local Models", isOn: $featureFlags.preferLocalModels)
            }
            
            Section("Experimental") {
                Toggle("Enable Experimental Features", isOn: $featureFlags.experimentalFeaturesEnabled)
                Text("May be unstable or incomplete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Menu Bar View

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if appState.activeJobs > 0 {
                Text("Active Jobs: \(appState.activeJobs)")
                Text("Downloads: \(appState.activeDownloads)")
                Divider()
            }
            
            Button("Open webScraper") {
                NSApp.activate(ignoringOtherApps: true)
            }
            
            Divider()
            
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(8)
    }
}
