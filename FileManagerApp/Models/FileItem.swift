//
//  FileItem.swift
//  FileManagerApp
//
//  文件/文件夹数据模型
//

import Foundation
import SwiftUI

struct FileItem: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let name: String
    let isDirectory: Bool
    let fileSize: Int64
    let creationDate: Date?
    let modificationDate: Date?
    let fileExtension: String?

    // MARK: - Computed Properties

    var formattedSize: String {
        if isDirectory {
            return "--"
        }
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var formattedModificationDate: String {
        guard let date = modificationDate else { return "未知" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var iconName: String {
        if isDirectory {
            return "folder.fill"
        }
        guard let ext = fileExtension?.lowercased() else {
            return "doc"
        }
        switch ext {
        // 图片
        case "jpg", "jpeg", "png", "gif", "heic", "webp":
            return "photo"
        // 视频
        case "mp4", "mov", "avi", "m4v":
            return "film"
        // 音频
        case "mp3", "wav", "m4a", "aac", "flac":
            return "music.note"
        // 文档
        case "pdf":
            return "doc.richtext"
        case "doc", "docx":
            return "doc.text"
        case "xls", "xlsx", "csv":
            return "tablecells"
        case "ppt", "pptx":
            return "tv"
        // 代码
        case "swift", "m", "h", "py", "js", "json", "plist":
            return "chevron.left.forwardslash.chevron.right"
        // 压缩包
        case "zip", "rar", "7z", "tar", "gz":
            return "archivebox"
        // 文本
        case "txt", "md", "rtf":
            return "text.alignleft"
        default:
            return "doc"
        }
    }

    var iconColor: Color {
        if isDirectory {
            return .blue
        }
        guard let ext = fileExtension?.lowercased() else {
            return .gray
        }
        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic", "webp":
            return .purple
        case "mp4", "mov", "avi", "m4v":
            return .red
        case "mp3", "wav", "m4a", "aac", "flac":
            return .pink
        case "pdf":
            return .red
        case "zip", "rar", "7z":
            return .orange
        default:
            return .gray
        }
    }

    // MARK: - Initializer

    init(url: URL) {
        self.url = url
        self.id = UUID()
        self.name = url.lastPathComponent
        self.fileExtension = url.pathExtension.isEmpty ? nil : url.pathExtension

        let resourceValues = try? url.resourceValues(forKeys: [
            .isDirectoryKey,
            .fileSizeKey,
            .creationDateKey,
            .contentModificationDateKey
        ])

        self.isDirectory = resourceValues?.isDirectory ?? false
        self.fileSize = Int64(resourceValues?.fileSize ?? 0)
        self.creationDate = resourceValues?.creationDate
        self.modificationDate = resourceValues?.contentModificationDate
    }
}

// MARK: - Sort Option

enum FileSortOption: String, CaseIterable {
    case name = "名称"
    case date = "修改时间"
    case size = "大小"
    case type = "类型"

    var icon: String {
        switch self {
        case .name: return "textformat"
        case .date: return "clock"
        case .size: return "arrow.up.and.down.circle"
        case .type: return "square.grid.2x2"
        }
    }
}
