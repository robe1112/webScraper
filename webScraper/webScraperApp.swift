//
//  webScraperApp.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import SwiftUI

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
            // File menu
            CommandGroup(replacing: .newItem) {
                Button("New Project") {
                    // TODO: Implement new project
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Divider()
                
                Button("Import Project...") {
                    // TODO: Implement import
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                
                Button("Export Project...") {
                    // TODO: Implement export
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
            
            // Edit menu additions
            CommandGroup(after: .pasteboard) {
                Divider()
                
                Button("Find in Project") {
                    // TODO: Implement find
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
            
            // View menu
            CommandMenu("Scraping") {
                Button("Start Scrape") {
                    // TODO: Implement start scrape
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Button("Pause Scrape") {
                    // TODO: Implement pause
                }
                .keyboardShortcut(".", modifiers: .command)
                
                Button("Stop Scrape") {
                    // TODO: Implement stop
                }
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
                Button("webScraper Help") {
                    // TODO: Open help
                }
                
                Divider()
                
                Button("Report an Issue...") {
                    // TODO: Open issue reporter
                }
                
                Button("Check for Updates...") {
                    // TODO: Check updates
                }
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
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            ScrapingSettingsView()
                .tabItem {
                    Label("Scraping", systemImage: "globe")
                }
            
            DownloadSettingsView()
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
        .frame(width: 500, height: 400)
    }
}

// MARK: - Settings Subviews (Placeholders)

struct GeneralSettingsView: View {
    @EnvironmentObject var featureFlags: FeatureFlags
    
    var body: some View {
        Form {
            Section("Storage") {
                Picker("Default Storage Type", selection: .constant(StorageType.coreData)) {
                    ForEach(StorageType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
            }
            
            Section("Memory") {
                Slider(
                    value: Binding(
                        get: { Double(featureFlags.maxMemoryUsageMB) },
                        set: { featureFlags.maxMemoryUsageMB = Int($0) }
                    ),
                    in: 1024...32768,
                    step: 1024
                ) {
                    Text("Max Memory: \(featureFlags.maxMemoryUsageMB) MB")
                }
            }
        }
        .padding()
    }
}

struct ScrapingSettingsView: View {
    var body: some View {
        Form {
            Section("Default Settings") {
                TextField("User Agent", text: .constant("WebScraperBot/1.0"))
                Toggle("Respect robots.txt", isOn: .constant(true))
                Toggle("Enable JavaScript", isOn: .constant(true))
            }
            
            Section("Rate Limiting") {
                Stepper("Request Delay: 1000ms", value: .constant(1000), in: 100...10000, step: 100)
                Stepper("Max Concurrent: 4", value: .constant(4), in: 1...20)
            }
        }
        .padding()
    }
}

struct DownloadSettingsView: View {
    var body: some View {
        Form {
            Section("Download Location") {
                HStack {
                    Text("~/Documents/webScraper/Downloads")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Choose...") {}
                }
            }
            
            Section("File Types") {
                Toggle("Images", isOn: .constant(true))
                Toggle("PDFs", isOn: .constant(true))
                Toggle("Documents", isOn: .constant(true))
                Toggle("Audio", isOn: .constant(false))
                Toggle("Video", isOn: .constant(false))
            }
        }
        .padding()
    }
}

struct ProxySettingsView: View {
    var body: some View {
        Form {
            Section("Proxy Configuration") {
                Toggle("Enable Proxy", isOn: .constant(false))
                TextField("Host", text: .constant(""))
                TextField("Port", text: .constant(""))
                
                Picker("Type", selection: .constant(ProxyManager.ProxyType.http)) {
                    ForEach(ProxyManager.ProxyType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
            }
        }
        .padding()
    }
}

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
