//
//  FileManagerApp.swift
//  FileManagerApp
//
//  iPhone 自签文件管理器
//  - 我的文件：管理自身沙盒 Documents
//  - 应用数据：浏览其他 App 的数据容器（需企业签名 + 特殊 entitlements）
//

import SwiftUI

@main
struct FileManagerApp: App {
    @StateObject private var fileService = FileManagerService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(fileService)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var fileService: FileManagerService
    @State private var navPath: [URL] = []
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: 我的文件
            NavigationStack(path: $navPath) {
                FileListView(
                    directoryURL: fileService.documentsURL,
                    navPath: $navPath
                )
                .navigationDestination(for: URL.self) { url in
                    FileListView(directoryURL: url, navPath: $navPath)
                }
            }
            .tabItem {
                Label("我的文件", systemImage: "folder")
            }
            .tag(0)

            // Tab 2: 应用数据
            NavigationStack {
                InstalledAppsView()
            }
            .tabItem {
                Label("应用数据", systemImage: "apps.iphone")
            }
            .tag(1)

            // Tab 3: 清理缓存
            NavigationStack {
                CacheCleanerView()
            }
            .tabItem {
                Label("清理", systemImage: "trash")
            }
            .tag(2)
        }
    }
}

// MARK: - 缓存清理视图

struct CacheCleanerView: View {
    @State private var scanResults: [String: Int64] = [:]
    @State private var isScanning = false
    @State private var totalCleaned: Int64 = 0

    var body: some View {
        List {
            Section {
                Button {
                    scanAndClean()
                } label: {
                    HStack {
                        if isScanning {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text(isScanning ? "正在扫描..." : "扫描并清理缓存")
                    }
                }
                .disabled(isScanning)
            }

            if !scanResults.isEmpty {
                Section("扫描结果") {
                    ForEach(scanResults.keys.sorted(), id: \.self) { key in
                        HStack {
                            Text(key)
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: scanResults[key] ?? 0, countStyle: .file))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            if totalCleaned > 0 {
                Section {
                    HStack {
                        Text("已清理")
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: totalCleaned, countStyle: .file))
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .navigationTitle("缓存清理")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func scanAndClean() {
        isScanning = true
        scanResults.removeAll()
        totalCleaned = 0

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            var results: [String: Int64] = [:]

            // 清理自身缓存
            let cachePaths = [
                "Library/Caches": fm.urls(for: .cachesDirectory, in: .userDomainMask)[0],
                "tmp": fm.temporaryDirectory
            ]

            for (name, path) in cachePaths {
                if let contents = try? fm.contentsOfDirectory(at: path, includingPropertiesForKeys: [.fileSizeKey]) {
                    var size: Int64 = 0
                    for url in contents {
                        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
                        size += Int64(values?.fileSize ?? 0)
                        try? fm.removeItem(at: url)
                    }
                    results[name] = size
                    totalCleaned += size
                }
            }

            DispatchQueue.main.async {
                self.scanResults = results
                self.isScanning = false
            }
        }
    }
}
