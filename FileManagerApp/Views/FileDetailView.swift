//
//  FileDetailView.swift
//  FileManagerApp
//
//  文件详情查看器
//

import SwiftUI
import QuickLook

struct FileDetailView: View {
    let item: FileItem
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var fileService: FileManagerService

    @State private var fileContent: String = ""
    @State private var showingShareSheet = false

    var body: some View {
        List {
            Section("文件信息") {
                infoRow(title: "名称", value: item.name)
                infoRow(title: "类型", value: item.fileExtension?.uppercased() ?? "文件夹")
                infoRow(title: "大小", value: item.formattedSize)
                if let created = item.creationDate {
                    infoRow(title: "创建时间", value: created.formatted(date: .abbreviated, time: .shortened))
                }
                if let modified = item.modificationDate {
                    infoRow(title: "修改时间", value: modified.formatted(date: .abbreviated, time: .shortened))
                }
                infoRow(title: "路径", value: item.url.path)
            }

            // 文本内容预览
            if !item.isDirectory, isTextFile {
                Section("内容预览") {
                    ScrollView {
                        Text(fileContent)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .frame(minHeight: 200)
                }
            }

            Section {
                Button {
                    showingShareSheet = true
                } label: {
                    Label("分享文件", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle("详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完成") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(urls: [item.url])
        }
        .onAppear {
            loadTextContent()
        }
    }

    private var isTextFile: Bool {
        guard let ext = item.fileExtension?.lowercased() else { return false }
        let textExts = ["txt", "md", "swift", "py", "js", "json", "plist", "html", "css", "xml", "csv", "rtf"]
        return textExts.contains(ext)
    }

    private func loadTextContent() {
        guard isTextFile else { return }
        fileContent = (try? String(contentsOf: item.url, encoding: .utf8)) ?? "无法读取文件内容"
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - 分享 Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let urls: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: urls, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
