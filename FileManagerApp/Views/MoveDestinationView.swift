//
//  MoveDestinationView.swift
//  FileManagerApp
//
//  选择移动/复制目标目录
//

import SwiftUI

struct MoveDestinationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var fileService: FileManagerService

    let rootURL: URL
    let onSelect: (URL) -> Void

    @State private var currentPath: URL

    init(rootURL: URL, onSelect: @escaping (URL) -> Void) {
        self.rootURL = rootURL
        self.onSelect = onSelect
        _currentPath = State(initialValue: rootURL)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onSelect(currentPath)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("移动到这里")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(currentPath.lastPathComponent)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                let subdirs = getSubdirectories()
                if !subdirs.isEmpty {
                    Section("子目录") {
                        ForEach(subdirs, id: \.self) { url in
                            Button {
                                currentPath = url
                            } label: {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.blue)
                                    Text(url.lastPathComponent)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if currentPath == url {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择目标位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if currentPath != rootURL {
                        Button("上级") {
                            currentPath = currentPath.deletingLastPathComponent()
                        }
                    }
                }
            }
        }
    }

    private func getSubdirectories() -> [URL] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: currentPath,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return contents.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        }.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }
}
