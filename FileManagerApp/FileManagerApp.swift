//
//  FileManagerApp.swift
//  FileManagerApp
//
//  iPhone 自签文件管理器
//  支持访问应用沙盒数据，提供复制/移动/添加/导入/删除功能
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

    var body: some View {
        NavigationStack(path: $navPath) {
            FileListView(
                directoryURL: fileService.documentsURL,
                navPath: $navPath
            )
            .navigationDestination(for: URL.self) { url in
                FileListView(directoryURL: url, navPath: $navPath)
            }
        }
    }
}
