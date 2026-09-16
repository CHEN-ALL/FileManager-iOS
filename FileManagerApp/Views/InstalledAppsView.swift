//
//  InstalledAppsView.swift
//  FileManagerApp
//
//  已安装应用列表 - 浏览其他 App 的数据容器
//

import SwiftUI

struct InstalledAppsView: View {
    @State private var apps: [InstalledApp] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var navigateToURL: URL?

    var filteredApps: [InstalledApp] {
        if searchText.isEmpty {
            return apps
        }
        return apps.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("正在加载应用列表...")
                    Spacer()
                }
            } else if filteredApps.isEmpty {
                Text("未找到应用")
                    .foregroundColor(.secondary)
            } else {
                ForEach(filteredApps) { app in
                    NavigationLink(value: AppDestination(app: app)) {
                        AppRowView(app: app)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "搜索应用名称或 Bundle ID")
        .navigationTitle("应用数据")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadApps()
        }
        .navigationDestination(for: AppDestination.self) { dest in
            if let dataURL = dest.app.dataContainerURL {
                AppDataContainerView(app: dest.app, rootURL: dataURL)
            } else {
                Text("无法获取 \(dest.app.displayName) 的数据容器\n\n可能原因：\n1. 该应用没有数据容器\n2. 沙盒限制未突破\n3. 需要特殊 entitlements")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }

    private func loadApps() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedApps = AppContainerManager.shared.listInstalledApplications()
            DispatchQueue.main.async {
                self.apps = loadedApps
                self.isLoading = false
            }
        }
    }
}

// MARK: - 导航目标

struct AppDestination: Hashable {
    let app: InstalledApp
}

// MARK: - 应用行视图

struct AppRowView: View {
    let app: InstalledApp

    var body: some View {
        HStack(spacing: 12) {
            // 应用图标
            if let icon = app.icon {
                Image(uiImage: icon)
                    .resizable()
                    .frame(width: 44, height: 44)
                    .cornerRadius(10)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(app.displayName.prefix(1)))
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.gray)
                    )
            }

            // 应用信息
            VStack(alignment: .leading, spacing: 3) {
                Text(app.displayName)
                    .font(.body)
                Text(app.id)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if app.dataContainerURL != nil {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, weight: .semibold))
            } else {
                Text("无数据")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 应用数据容器浏览视图

struct AppDataContainerView: View {
    let app: InstalledApp
    let rootURL: URL

    @EnvironmentObject var fileService: FileManagerService
    @State private var items: [FileItem] = []
    @State private var currentPath: URL

    init(app: InstalledApp, rootURL: URL) {
        self.app = app
        self.rootURL = rootURL
        _currentPath = State(initialValue: rootURL)
    }

    var body: some View {
        List {
            ForEach(items) { item in
                NavigationLink(value: item.url) {
                    HStack(spacing: 12) {
                        Image(systemName: item.iconName)
                            .foregroundColor(item.iconColor)
                            .font(.system(size: 20))
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.body)
                            Text(item.formattedSize)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(app.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: URL.self) { url in
            AppDataContainerView(app: app, rootURL: url)
        }
        .onAppear {
            loadContents()
        }
        .onChange(of: currentPath) { _ in
            loadContents()
        }
    }

    private func loadContents() {
        let fm = FileManager.default
        do {
            let contents = try fm.contentsOfDirectory(
                at: currentPath,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            items = contents.map { FileItem(url: $0) }.sorted { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        } catch {
            items = []
        }
    }
}
