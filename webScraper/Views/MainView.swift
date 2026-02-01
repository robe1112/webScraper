//
//  MainView.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import SwiftUI

/// Main application view with three-column navigation
struct MainView: View {
    
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var featureFlags: FeatureFlags
    
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            SidebarView(selectedItem: $appState.selectedSidebarItem)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } content: {
            // Content list
            ContentListView()
                .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
        } detail: {
            // Detail view
            DetailView()
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { appState.showNewProjectSheet = true }) {
                    Label("New Project", systemImage: "plus")
                }
                .accessibilityIdentifier("newProjectButton")
                
                Button(action: {}) {
                    Label("Start Scrape", systemImage: "play.fill")
                }
                .disabled(appState.selectedProject == nil)
            }
            
            // Plugin toolbar items
            if let pluginManager = appState.pluginManager as PluginManager? {
                ToolbarItemGroup(placement: .automatic) {
                    ForEach(pluginManager.aggregateToolbarItems()) { item in
                        Button(action: item.action) {
                            Label(item.title, systemImage: item.icon)
                        }
                        .disabled(!item.isEnabled)
                    }
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { appState.showNewProjectSheet },
            set: { appState.showNewProjectSheet = $0 }
        )) {
            NewProjectView(isPresented: Binding(
                get: { appState.showNewProjectSheet },
                set: { appState.showNewProjectSheet = $0 }
            ))
                .environmentObject(appState)
        }
        .alert(item: $appState.currentError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK")) {
                    appState.dismissError()
                }
            )
        }
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @Binding var selectedItem: SidebarItem
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List(selection: $selectedItem) {
            Section("Navigation") {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.rawValue, systemImage: item.icon)
                        .tag(item)
                        .badge(badge(for: item))
                }
            }
            
            // Plugin sidebar sections
            if let pluginManager = appState.pluginManager as PluginManager? {
                PluginSidebarContent(sections: pluginManager.aggregateSidebarSections())
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("webScraper")
    }
    
    private func badge(for item: SidebarItem) -> Int {
        switch item {
        case .activeJobs:
            return appState.activeJobs
        case .downloads:
            return appState.activeDownloads
        default:
            return 0
        }
    }
}

// MARK: - Content List View

struct ContentListView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            switch appState.selectedSidebarItem {
            case .projects:
                ProjectListView()
            case .activeJobs:
                ActiveJobsListView()
            case .downloads:
                DownloadsListView()
            case .siteMap:
                SiteMapListView()
            case .diff:
                ChangesListView()
            case .schedule:
                ScheduleListView()
            case .settings:
                Text("Settings")
            }
        }
        .navigationTitle(appState.selectedSidebarItem.rawValue)
    }
}

// MARK: - Detail View

struct DetailView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if let project = appState.selectedProject {
                ProjectDetailView(project: project)
            } else {
                EmptyDetailView()
            }
        }
    }
}

// MARK: - Empty States

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe.badge.chevron.backward")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            
            Text("No Project Selected")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("Select a project from the sidebar or create a new one to get started.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - List Views (Placeholders)

struct ProjectListView: View {
    @EnvironmentObject var appState: AppState
    @State private var projects: [Project] = []
    
    var body: some View {
        List(projects, selection: Binding(
            get: { appState.selectedProject },
            set: { appState.selectedProject = $0 }
        )) { project in
            ProjectRow(project: project)
                .tag(project)
        }
        .listStyle(.inset)
        .overlay {
            if projects.isEmpty {
                ContentUnavailableView(
                    "No Projects",
                    systemImage: "folder",
                    description: Text("Create a new project to start scraping.")
                )
            }
        }
        .task(id: appState.projectListRefreshTrigger) {
            do {
                projects = try await appState.loadProjects()
            } catch {
                appState.showError(AppError(
                    title: "Load Failed",
                    message: "Could not load projects",
                    underlyingError: error
                ))
            }
        }
    }
}

struct ProjectRow: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.name)
                .font(.headline)
            
            Text(project.startURL)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            
            HStack(spacing: 12) {
                Label("\(project.totalPagesScraped)", systemImage: "doc.text")
                Label("\(project.totalFilesDownloaded)", systemImage: "arrow.down.circle")
                Label(ByteCountFormatter.string(fromByteCount: project.totalSizeBytes, countStyle: .file), systemImage: "internaldrive")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct ActiveJobsListView: View {
    var body: some View {
        ContentUnavailableView(
            "No Active Jobs",
            systemImage: "play.circle",
            description: Text("Start a scrape job to see it here.")
        )
    }
}

struct DownloadsListView: View {
    var body: some View {
        ContentUnavailableView(
            "No Downloads",
            systemImage: "arrow.down.circle",
            description: Text("Downloaded files will appear here.")
        )
    }
}

struct SiteMapListView: View {
    var body: some View {
        ContentUnavailableView(
            "No Site Map",
            systemImage: "map",
            description: Text("Run a scrape to generate a site map.")
        )
    }
}

struct ChangesListView: View {
    var body: some View {
        ContentUnavailableView(
            "No Changes Tracked",
            systemImage: "doc.badge.clock",
            description: Text("Changes between scrapes will appear here.")
        )
    }
}

struct ScheduleListView: View {
    var body: some View {
        ContentUnavailableView(
            "No Scheduled Jobs",
            systemImage: "calendar",
            description: Text("Schedule recurring scrapes to see them here.")
        )
    }
}

// MARK: - Project Detail View

struct ProjectDetailView: View {
    let project: Project
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(project.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if let url = URL(string: project.startURL) {
                        Link(project.startURL, destination: url)
                        .font(.subheadline)
                    } else {
                        Text(project.startURL)
                            .font(.subheadline)
                    }
                }
                
                // Stats
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatCard(title: "Pages", value: "\(project.totalPagesScraped)", icon: "doc.text")
                    StatCard(title: "Files", value: "\(project.totalFilesDownloaded)", icon: "arrow.down.circle")
                    StatCard(title: "Size", value: ByteCountFormatter.string(fromByteCount: project.totalSizeBytes, countStyle: .file), icon: "internaldrive")
                    StatCard(title: "Last Run", value: project.lastScrapedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Never", icon: "clock")
                }
                
                // Actions
                HStack(spacing: 12) {
                    Button(action: {}) {
                        Label("Start Scrape", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: {}) {
                        Label("Configure", systemImage: "gear")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {}) {
                        Label("View Site Map", systemImage: "map")
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
            }
            .padding(24)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - New Project View

struct NewProjectView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var appState: AppState
    
    @State private var projectName = ""
    @State private var startURL = ""
    @State private var storageType: StorageType = .coreData
    @State private var enableJavaScript = true
    @State private var respectRobotsTxt = true
    @State private var validationResult: ValidationResult?
    @State private var didLoadDefaults = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Project Details") {
                    TextField("Project Name", text: $projectName)
                        .accessibilityIdentifier("projectNameField")

                    TextField("Start URL", text: $startURL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("startURLField")
                        .onChange(of: startURL) { _, newValue in
                            validationResult = URLValidator.validate(newValue)
                        }
                    
                    if let result = validationResult {
                        switch result {
                        case .valid:
                            Label("Valid URL", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .warning(_, let message):
                            Label(message, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        case .invalid(let reason):
                            Label(reason, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
                
                Section("Quick Settings") {
                    Picker("Storage Type", selection: $storageType) {
                        ForEach(StorageType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    Toggle("Enable JavaScript", isOn: $enableJavaScript)
                    Toggle("Respect robots.txt", isOn: $respectRobotsTxt)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .accessibilityIdentifier("cancelButton")
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createProject()
                    }
                    .disabled(!canCreate)
                    .accessibilityIdentifier("createButton")
                }
            }
        }
        .frame(width: 450, height: 350)
        .onAppear {
            if !didLoadDefaults {
                loadDefaultsFromGlobalSettings()
                didLoadDefaults = true
            }
        }
    }
    
    private func loadDefaultsFromGlobalSettings() {
        let settings = appState.globalSettings
        storageType = settings.defaultStorageType
        enableJavaScript = settings.defaultEnableJavaScript
        respectRobotsTxt = settings.defaultRespectRobotsTxt
    }
    
    private var canCreate: Bool {
        !projectName.isEmpty && (validationResult?.isValid ?? false)
    }
    
    private func createProject() {
        // Use normalized URL from validation when available (handles pasted paths like /Users/.../TestSite)
        let urlToUse: String
        if let result = validationResult, let url = result.url {
            urlToUse = url.absoluteString
        } else {
            urlToUse = startURL
        }
        Task {
            do {
                _ = try await appState.createProject(
                    name: projectName,
                    url: urlToUse,
                    storageType: storageType,
                    enableJavaScript: enableJavaScript,
                    respectRobotsTxt: respectRobotsTxt
                )
                isPresented = false
            } catch {
                appState.showError(AppError(
                    title: "Create Failed",
                    message: "Could not create project",
                    underlyingError: error
                ))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .environmentObject(AppState())
        .environmentObject(FeatureFlags())
}
