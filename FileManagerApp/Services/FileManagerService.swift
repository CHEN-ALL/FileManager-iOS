//
//  FileManagerService.swift
//  FileManagerApp
//
//  文件操作核心服务：复制 / 移动 / 删除 / 新建 / 导入 / 重命名
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

class FileManagerService: ObservableObject {
    static let shared = FileManagerService()

    private let fileManager = FileManager.default

    // MARK: - 常用目录

    var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var libraryURL: URL {
        fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
    }

    var tmpURL: URL {
        fileManager.temporaryDirectory
    }

    // MARK: - 全局错误提示

    @Published var errorMessage: String?
    @Published var showError: Bool = false

    // MARK: - Initializer

    private init() {}

    // MARK: - 新建文件夹

    func createFolder(named name: String, in directory: URL) {
        let newURL = directory.appendingPathComponent(name)
        do {
            try fileManager.createDirectory(at: newURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            showError(message: "创建文件夹失败：\(error.localizedDescription)")
        }
    }

    // MARK: - 新建文本文件

    func createTextFile(named name: String, content: String = "", in directory: URL) {
        let newURL = directory.appendingPathComponent(name)
        do {
            try content.write(to: newURL, atomically: true, encoding: .utf8)
        } catch {
            showError(message: "创建文件失败：\(error.localizedDescription)")
        }
    }

    // MARK: - 复制

    func copyItems(_ items: [FileItem], to destination: URL) -> Bool {
        var success = true
        for item in items {
            let destURL = destination.appendingPathComponent(item.name)
            do {
                let finalURL = resolveDuplicateURL(destURL)
                try fileManager.copyItem(at: item.url, to: finalURL)
            } catch {
                showError(message: "复制 \(item.name) 失败：\(error.localizedDescription)")
                success = false
            }
        }
        return success
    }

    // MARK: - 移动

    func moveItems(_ items: [FileItem], to destination: URL) -> Bool {
        var success = true
        for item in items {
            let destURL = destination.appendingPathComponent(item.name)
            do {
                let finalURL = resolveDuplicateURL(destURL)
                try fileManager.moveItem(at: item.url, to: finalURL)
            } catch {
                showError(message: "移动 \(item.name) 失败：\(error.localizedDescription)")
                success = false
            }
        }
        return success
    }

    // MARK: - 删除

    func deleteItems(_ items: [FileItem]) -> Bool {
        var success = true
        for item in items {
            do {
                try fileManager.removeItem(at: item.url)
            } catch {
                showError(message: "删除 \(item.name) 失败：\(error.localizedDescription)")
                success = false
            }
        }
        return success
    }

    // MARK: - 重命名

    func renameItem(_ item: FileItem, to newName: String) -> Bool {
        let newURL = item.url.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try fileManager.moveItem(at: item.url, to: newURL)
            return true
        } catch {
            showError(message: "重命名失败：\(error.localizedDescription)")
            return false
        }
    }

    // MARK: - 导入文件（从文件 App / 相册）

    func importData(from url: URL, to directory: URL) -> Bool {
        let destURL = directory.appendingPathComponent(url.lastPathComponent)
        do {
            let finalURL = resolveDuplicateURL(destURL)
            let needsStop = url.startAccessingSecurityScopedResource()
            defer {
                if needsStop {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            try fileManager.copyItem(at: url, to: finalURL)
            return true
        } catch {
            showError(message: "导入失败：\(error.localizedDescription)")
            return false
        }
    }

    // MARK: - 获取目录大小

    func directorySize(at url: URL) -> Int64 {
        var size: Int64 = 0
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
            size += Int64(values?.fileSize ?? 0)
        }
        return size
    }

    // MARK: - 辅助方法

    private func resolveDuplicateURL(_ url: URL) -> URL {
        var finalURL = url
        var counter = 1
        while fileManager.fileExists(atPath: finalURL.path) {
            let path = url.deletingLastPathComponent()
            let ext = url.pathExtension
            let name = url.deletingPathExtension().lastPathComponent
            if ext.isEmpty {
                finalURL = path.appendingPathComponent("\(name) \(counter)")
            } else {
                finalURL = path.appendingPathComponent("\(name) \(counter).\(ext)")
            }
            counter += 1
        }
        return finalURL
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}
