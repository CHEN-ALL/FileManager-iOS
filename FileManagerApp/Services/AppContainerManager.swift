//
//  AppContainerManager.swift
//  FileManagerApp
//
//  跨应用容器访问服务
//  利用 MobileHouseArrest 信任漏洞，通过 MobileContainerManager 获取其他 App 的数据容器
//

import Foundation
import UIKit
import ObjectiveC

// MARK: - 已安装应用模型

struct InstalledApp: Identifiable, Hashable {
    let id: String           // bundle identifier
    let bundleURL: URL       // .app 路径
    let dataContainerURL: URL? // 数据容器路径
    let displayName: String
    let bundleVersion: String
    let icon: UIImage?

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - 应用容器管理器

class AppContainerManager: NSObject {
    static let shared = AppContainerManager()

    private override init() {
        super.init()
    }

    // MARK: - 列出所有已安装应用

    func listInstalledApplications() -> [InstalledApp] {
        var results: [InstalledApp] = []

        // 方法1: 通过 LSApplicationWorkspace 获取已安装应用
        if let apps = listViaLSApplicationWorkspace() {
            results = apps
        }

        // 方法2: 扫描 Bundle 目录兜底
        if results.isEmpty {
            results = scanBundleDirectory()
        }

        return results.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    // MARK: - 方法1: 通过 LSApplicationWorkspace

    private func listViaLSApplicationWorkspace() -> [InstalledApp]? {
        guard let workspace = LSApplicationWorkspace() else {
            return nil
        }

        guard let appsArray = workspace.allApplications() else {
            return nil
        }

        var apps: [InstalledApp] = []

        for case let appInfo as [String: Any] in appsArray {
            // 获取 Bundle ID
            var bundleID: String?
            if let bid = appInfo["ApplicationIdentifier"] as? String {
                bundleID = bid
            } else if let bid = appInfo["CFBundleIdentifier"] as? String {
                bundleID = bid
            }
            guard let bundleID = bundleID else { continue }

            // 获取 Bundle 路径
            var bundlePath: String?
            if let path = appInfo["BundleURL"] as? String {
                bundlePath = path
            } else if let url = appInfo["BundleURL"] as? URL {
                bundlePath = url.path
            } else if let url = appInfo["BundleURL"] as? NSURL {
                bundlePath = url.path
            }

            // 获取显示名称
            var displayName = bundleID
            if let name = appInfo["DisplayName"] as? String {
                displayName = name
            } else if let name = appInfo["CFBundleDisplayName"] as? String {
                displayName = name
            }

            // 获取数据容器
            let dataURL = getAppDataContainer(bundleID: bundleID)

            // 获取图标
            var icon: UIImage?
            if let bundlePath = bundlePath {
                let iconDir = bundlePath + "/"
                if let iconFiles = try? FileManager.default.contentsOfDirectory(atPath: bundlePath) {
                    for file in iconFiles {
                        if file.hasPrefix("AppIcon") && file.hasSuffix(".png") {
                            icon = UIImage(contentsOfFile: iconDir + file)
                            break
                        }
                    }
                }
            }

            if let bundlePath = bundlePath {
                apps.append(InstalledApp(
                    id: bundleID,
                    bundleURL: URL(fileURLWithPath: bundlePath),
                    dataContainerURL: dataURL,
                    displayName: displayName,
                    bundleVersion: "1.0",
                    icon: icon
                ))
            }
        }

        return apps.isEmpty ? nil : apps
    }

    // MARK: - 获取指定 App 的数据容器路径

    func getAppDataContainer(bundleID: String) -> URL? {
        // 方法1: 通过 MCMAppDataContainer
        if let containerClass = NSClassFromString("MCMAppDataContainer") {
            let createIfNecessary: Bool = false
            var existed: Bool = false
            var error: NSDictionary?

            typealias ContainerCreateFunc = @convention(c) (AnyClass, Selector, String, Bool, UnsafeMutablePointer<Bool>, UnsafeMutablePointer<NSDictionary?>) -> AnyObject?
            let selector = NSSelectorFromString("containerWithIdentifier:createIfNecessary:existed:error:")

            if containerClass.responds(to: selector) {
                if let method = class_getClassMethod(containerClass, selector) {
                    let imp = method_getImplementation(method)
                    let function = unsafeBitCast(imp, to: ContainerCreateFunc.self)

                    if let container = function(containerClass, selector, bundleID, createIfNecessary, &existed, &error) {
                        // 获取容器 URL
                        let urlSelector = NSSelectorFromString("url")
                        let containerType: AnyObject.Type = type(of: container)
                        if let urlMethod = class_getInstanceMethod(containerType, urlSelector) {
                            let urlImp = method_getImplementation(urlMethod)
                            typealias GetURLFunc = @convention(c) (AnyObject, Selector) -> Unmanaged<NSURL>?
                            let getURL = unsafeBitCast(urlImp, to: GetURLFunc.self)
                            if let nsurl = getURL(container, urlSelector)?.takeUnretainedValue() {
                                return nsurl as URL
                            }
                        }
                    }
                }
            }
        }

        // 方法2: 直接扫描已知路径（兜底）
        let containersPath = "/var/mobile/Containers/Data/Application/"
        if let containers = try? FileManager.default.contentsOfDirectory(atPath: containersPath) {
            for container in containers {
                let containerURL = URL(fileURLWithPath: containersPath).appendingPathComponent(container)
                let metadataURL = containerURL.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")

                if let metadata = NSDictionary(contentsOf: metadataURL as URL) {
                    if let mcmmetadata = metadata["MCMMetadataIdentifier"] as? String,
                       mcmmetadata == bundleID {
                        return containerURL
                    }
                }
            }
        }

        return nil
    }

    // MARK: - 方法2: 扫描 Bundle 目录（兜底）

    private func scanBundleDirectory() -> [InstalledApp] {
        var apps: [InstalledApp] = []

        let bundlePaths = [
            "/var/containers/Bundle/Application/",
            "/private/var/containers/Bundle/Application/"
        ]

        for basePath in bundlePaths {
            guard let entries = try? FileManager.default.contentsOfDirectory(atPath: basePath) else {
                continue
            }

            for entry in entries {
                let appDir = basePath + entry
                guard let appEntries = try? FileManager.default.contentsOfDirectory(atPath: appDir) else {
                    continue
                }

                for appEntry in appEntries {
                    if appEntry.hasSuffix(".app") {
                        let appURL = URL(fileURLWithPath: appDir).appendingPathComponent(appEntry)
                        let plistURL = appURL.appendingPathComponent("Info.plist")

                        guard let plist = NSDictionary(contentsOf: plistURL) else {
                            continue
                        }

                        let bundleID = plist["CFBundleIdentifier"] as? String ?? appEntry
                        let displayName = plist["CFBundleDisplayName"] as? String ?? plist["CFBundleName"] as? String ?? appEntry
                        let version = plist["CFBundleShortVersionString"] as? String ?? "1.0"

                        let dataURL = getAppDataContainer(bundleID: bundleID)

                        var icon: UIImage?
                        if let iconFiles = try? FileManager.default.contentsOfDirectory(atPath: appURL.path) {
                            for file in iconFiles {
                                if file.hasPrefix("AppIcon") && file.hasSuffix(".png") {
                                    icon = UIImage(contentsOfFile: appURL.appendingPathComponent(file).path)
                                    break
                                }
                            }
                        }

                        apps.append(InstalledApp(
                            id: bundleID,
                            bundleURL: appURL,
                            dataContainerURL: dataURL,
                            displayName: displayName,
                            bundleVersion: version,
                            icon: icon
                        ))
                        break
                    }
                }
            }
        }

        return apps
    }
}

// MARK: - LSApplicationWorkspace 私有类封装

class LSApplicationWorkspace: NSObject {
    private let instance: NSObject

    init?() {
        guard let LSApplicationWorkspaceClass = NSClassFromString("LSApplicationWorkspace") else {
            return nil
        }

        let defaultSelector = NSSelectorFromString("defaultWorkspace")
        guard LSApplicationWorkspaceClass.responds(to: defaultSelector) else {
            return nil
        }

        guard let method = class_getClassMethod(LSApplicationWorkspaceClass, defaultSelector) else {
            return nil
        }
        let imp = method_getImplementation(method)
        typealias GetDefaultFunc = @convention(c) (AnyClass, Selector) -> AnyObject?
        let getDefault = unsafeBitCast(imp, to: GetDefaultFunc.self)
        guard let obj = getDefault(LSApplicationWorkspaceClass, defaultSelector) else {
            return nil
        }

        self.instance = obj
        super.init()
    }

    func allApplications() -> NSArray? {
        let selector = NSSelectorFromString("allApplications")
        guard instance.responds(to: selector) else {
            return nil
        }

        let instanceType: AnyClass = type(of: instance)
        guard let method = class_getInstanceMethod(instanceType, selector) else {
            return nil
        }
        let imp = method_getImplementation(method)
        typealias GetAllAppsFunc = @convention(c) (AnyObject, Selector) -> Unmanaged<NSArray>?
        let getAllApps = unsafeBitCast(imp, to: GetAllAppsFunc.self)
        return getAllApps(instance, selector)?.takeUnretainedValue() as NSArray?
    }
}
