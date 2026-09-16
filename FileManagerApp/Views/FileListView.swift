//
//  FileListView.swift
//  FileManagerApp
//
//  文件列表主界面
//

import SwiftUI
import QuickLook
import UniformTypeIdentifiers

struct FileListView: View {
    @EnvironmentObject var fileService: FileManagerService

    let directoryURL: URL
    @Binding var navPath: [URL]

    // 当前目录的文件列表（每个视图实例独立维护）
    @State private var items: [FileItem] = []
    @State private var sortOption: FileSortOption = .name

    // 弹窗状态
    @State private var showingNewFolderAlert = false
    @State private var showingNewFileAlert = false
    @State private var newName = ""
    @State private var newFileContent = ""
    @State private var showingImporter = false
    @State private var showingMoveSheet = false
    @State private var previewURL: URL?
    @State private var showingRenameAlert = false
    @State private var renameItem: FileItem?
    @State private var renameText = ""
    @State private var showingDeleteConfirm = false

    // 选择模式（局部状态）
    @State private var isSelecting: Bool = false
    @State private var selectedItems: Set<UUID> = []

    var body: some View {
        List {
            ForEach(items) { item in
                FileRowView(item: item, isSelecting: isSelecting, isSelected: selectedItems.contains(item.id))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isSelecting {
                            toggleSelection(item)
                        } else {
                            openItem(item)
                        }
                    }
                    .onLongPressGesture {
                        if !isSelecting {
                            isSelecting = true
                            selectedItems.insert(item.id)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            fileService.deleteItems([item])
                            reloadContents()
                        } label: {
                            Label("删除", systemImage: "trash")
                        }

                        Button {
                            renameItem = item
                            renameText = item.name
                            showingRenameAlert = true
                        } label: {
                            Label("重命名", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            isSelecting = true
                            selectedItems.insert(item.id)
                            showingMoveSheet = true
                        } label: {
                            Label("移动", systemImage: "folder")
                        }
                        .tint(.orange)
                    }
                    .listRowBackground(
                        isSelecting && selectedItems.contains(item.id)
                        ? Color.accentColor.opacity(0.2)
                        : Color(.systemBackground)
                    )
            }
        }
        .navigationTitle(directoryURL.lastPathComponent.isEmpty ? "文件" : directoryURL.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if isSelecting {
                    Button("取消") {
                        cancelSelection()
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        newName = ""
                        showingNewFolderAlert = true
                    } label: {
                        Label("新建文件夹", systemImage: "folder.badge.plus")
                    }

                    Button {
                        newName = ""
                        newFileContent = ""
                        showingNewFileAlert = true
                    } label: {
                        Label("新建文本文件", systemImage: "doc.badge.plus")
                    }

                    Button {
                        showingImporter = true
                    } label: {
                        Label("导入文件", systemImage: "square.and.arrow.down")
                    }

                    Divider()

                    Menu {
                        ForEach(FileSortOption.allCases, id: \.self) { option in
                            Button {
                                sortOption = option
                                sortItems()
                            } label: {
                                Label(option.rawValue, systemImage: option.icon)
                            }
                        }
                    } label: {
                        Label("排序方式", systemImage: "arrow.up.arrow.down.circle")
                    }

                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                selectionToolbar
            }
        }
        .alert("错误", isPresented: $fileService.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(fileService.errorMessage ?? "未知错误")
        }
        .alert("新建文件夹", isPresented: $showingNewFolderAlert) {
            TextField("文件夹名称", text: $newName)
            Button("取消", role: .cancel) {}
            Button("创建") {
                if !newName.isEmpty {
                    fileService.createFolder(named: newName, in: directoryURL)
                    reloadContents()
                }
            }
        } message: {
            Text("请输入新文件夹的名称")
        }
        .alert("新建文本文件", isPresented: $showingNewFileAlert) {
            TextField("文件名（含 .txt）", text: $newName)
            Button("取消", role: .cancel) {}
            Button("创建") {
                if !newName.isEmpty {
                    fileService.createTextFile(named: newName, content: newFileContent, in: directoryURL)
                    reloadContents()
                }
            }
        } message: {
            Text("请输入文件名，例如：notes.txt")
        }
        .alert("重命名", isPresented: $showingRenameAlert) {
            TextField("新名称", text: $renameText)
            Button("取消", role: .cancel) {}
            Button("保存") {
                if let item = renameItem, !renameText.isEmpty {
                    _ = fileService.renameItem(item, to: renameText)
                    reloadContents()
                }
            }
        } message: {
            Text("请输入新的名称")
        }
        .alert("确认删除", isPresented: $showingDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                let selected = getSelectedItems()
                _ = fileService.deleteItems(selected)
                cancelSelection()
                reloadContents()
            }
        } message: {
            Text("确定要删除选中的 \(selectedItems.count) 个项目吗？此操作不可恢复。")
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    _ = fileService.importData(from: url, to: directoryURL)
                }
                reloadContents()
            case .failure(let error):
                fileService.showError = true
                fileService.errorMessage = "导入失败：\(error.localizedDescription)"
            }
        }
        .sheet(isPresented: $showingMoveSheet) {
            MoveDestinationView(rootURL: fileService.documentsURL) { destinationURL in
                let selected = getSelectedItems()
                if fileService.moveItems(selected, to: destinationURL) {
                    cancelSelection()
                    reloadContents()
                }
            }
        }
        .quickLookPreview($previewURL)
        .onAppear {
            reloadContents()
        }
    }

    // MARK: - 底部选择操作栏

    private var selectionToolbar: some View {
        HStack(spacing: 0) {
            toolbarButton(icon: "doc.on.doc", title: "复制") {
                copySelected()
            }

            toolbarButton(icon: "folder", title: "移动") {
                showingMoveSheet = true
            }

            toolbarButton(icon: "trash", title: "删除", role: .destructive) {
                showingDeleteConfirm = true
            }

            toolbarButton(icon: "square.and.arrow.up", title: "分享") {
                shareSelected()
            }
        }
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func toolbarButton(icon: String, title: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(role == .destructive ? .red : .accentColor)
        }
    }

    // MARK: - 操作方法

    private func openItem(_ item: FileItem) {
        if item.isDirectory {
            navPath.append(item.url)
        } else {
            previewURL = item.url
        }
    }

    private func reloadContents() {
        let fm = FileManager.default
        do {
            let contents = try fm.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [
                    .isDirectoryKey,
                    .fileSizeKey,
                    .creationDateKey,
                    .contentModificationDateKey
                ],
                options: [.skipsHiddenFiles]
            )
            items = contents.map { FileItem(url: $0) }
            sortItems()
        } catch {
            fileService.showError = true
            fileService.errorMessage = "无法读取目录：\(error.localizedDescription)"
        }
    }

    private func sortItems() {
        switch sortOption {
        case .name:
            items.sort {
                if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .date:
            items.sort {
                if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                return ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast)
            }
        case .size:
            items.sort {
                if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                return $0.fileSize > $1.fileSize
            }
        case .type:
            items.sort {
                if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                return ($0.fileExtension ?? "") < ($1.fileExtension ?? "")
            }
        }
    }

    private func toggleSelection(_ item: FileItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    private func cancelSelection() {
        selectedItems.removeAll()
        isSelecting = false
    }

    private func getSelectedItems() -> [FileItem] {
        items.filter { selectedItems.contains($0.id) }
    }

    private func copySelected() {
        let selected = getSelectedItems()
        _ = fileService.copyItems(selected, to: directoryURL)
        cancelSelection()
        reloadContents()
    }

    private func shareSelected() {
        let selected = getSelectedItems()
        let urls = selected.map { $0.url }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }
        let activityVC = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        rootVC.present(activityVC, animated: true)
        cancelSelection()
    }
}

// MARK: - 文件行视图

struct FileRowView: View {
    let item: FileItem
    let isSelecting: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.system(size: 20))
            }

            Image(systemName: item.iconName)
                .foregroundColor(item.iconColor)
                .font(.system(size: 24))
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(item.formattedSize)
                    Text("·")
                    Text(item.formattedModificationDate)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            if item.isDirectory && !isSelecting {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .padding(.vertical, 4)
    }
}
