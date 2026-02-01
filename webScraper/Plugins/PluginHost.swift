//
//  PluginHost.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import SwiftUI

/// SwiftUI view that hosts plugin-provided content
/// Provides a consistent container for plugin views
struct PluginHost: View {
    let plugin: any PluginProtocol
    let context: PluginContext
    
    var body: some View {
        Group {
            if let view = plugin.contentView(for: context) {
                view
            } else {
                PluginPlaceholder(plugin: plugin)
            }
        }
    }
}

/// Placeholder shown when plugin has no content view
struct PluginPlaceholder: View {
    let plugin: any PluginProtocol
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text(type(of: plugin).name)
                .font(.headline)
            
            Text(type(of: plugin).description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            HStack {
                StatusBadge(status: plugin.status)
                Text("v\(type(of: plugin).version)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Badge showing plugin status
struct StatusBadge: View {
    let status: PluginStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
            Text(status.rawValue)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .clipShape(Capsule())
    }
    
    private var backgroundColor: Color {
        switch status {
        case .inactive:
            return Color.gray.opacity(0.2)
        case .activating, .deactivating:
            return Color.orange.opacity(0.2)
        case .active:
            return Color.green.opacity(0.2)
        case .error:
            return Color.red.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        switch status {
        case .inactive:
            return .gray
        case .activating, .deactivating:
            return .orange
        case .active:
            return .green
        case .error:
            return .red
        }
    }
}

/// Container for plugin toolbar items
struct PluginToolbar: ToolbarContent {
    let items: [PluginToolbarItem]
    
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            ForEach(items) { item in
                Button(action: item.action) {
                    Label(item.title, systemImage: item.icon)
                }
                .disabled(!item.isEnabled)
                .badge(item.badge)
            }
        }
    }
}

/// Container for plugin sidebar sections
struct PluginSidebarContent: View {
    let sections: [PluginSidebarSection]
    
    var body: some View {
        ForEach(sections) { section in
            Section(section.title) {
                ForEach(section.items) { item in
                    Button(action: item.action) {
                        Label {
                            HStack {
                                Text(item.title)
                                Spacer()
                                if let badge = item.badge {
                                    Text(badge)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                            }
                        } icon: {
                            Image(systemName: item.icon)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Container for plugin context menu items
struct PluginContextMenu: View {
    let items: [PluginMenuItem]
    
    var body: some View {
        ForEach(items) { item in
            Button(role: item.isDestructive ? .destructive : nil, action: item.action) {
                if let icon = item.icon {
                    Label(item.title, systemImage: icon)
                } else {
                    Text(item.title)
                }
            }
            .disabled(!item.isEnabled)
            .keyboardShortcut(item.shortcut)
        }
    }
}

/// Environment key for plugin manager
struct PluginManagerKey: EnvironmentKey {
    static let defaultValue: PluginManager? = nil
}

extension EnvironmentValues {
    var pluginManager: PluginManager? {
        get { self[PluginManagerKey.self] }
        set { self[PluginManagerKey.self] = newValue }
    }
}

/// View modifier to inject plugin manager
struct PluginManagerModifier: ViewModifier {
    let pluginManager: PluginManager
    
    func body(content: Content) -> some View {
        content
            .environment(\.pluginManager, pluginManager)
    }
}

extension View {
    func withPluginManager(_ manager: PluginManager) -> some View {
        modifier(PluginManagerModifier(pluginManager: manager))
    }
}
