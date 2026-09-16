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
        guard let workspace = LSApplicationWorkspace.default() else {
            print("[AppContainer] LSApplicationWorkspace 初始化失败")
            return nil
        }

        guard let appsArray = workspace.allApplications() else {
            print("[AppContainer] allApplications 返回 nil")
            return nil
        }

        print("[AppContainer] 获取到 \(appsArray.count) 个应用")

        var apps: [InstalledApp] = []

        for case let appObj as NSObject in appsArray {
            // LSApplication 对象，用 KVC 读取属性
            var bundleID: String?

            // 尝试 bundleIdentifier
            if appObj.responds(to: NSSelectorFromString("bundleIdentifier")) {
                let result = appObj.perform(NSSelectorFromString("bundleIdentifier"))
                bundleID = result?.takeUnretainedValue() as? String
            }

            guard let bundleID = bundleID else { continue }

            // 获取 Bundle URL
            var bundlePath: String?
            if appObj.responds(to: NSSelectorFromString("bundleURL")) {
                let result = appObj.perform(NSSelectorFromString("bundleURL"))
                if let url = result?.takeUnretainedValue() as? URL {
                    bundlePath = url.path
                } else if let nsurl = result?.takeUnretainedValue() as? NSURL {
                    bundlePath = nsurl.path
                }
            }

            // 获取显示名称
            var displayName = bundleID
            if appObj.responds(to: NSSelectorFromString("localizedName")) {
                let result = appObj.perform(NSSelectorFromString("localizedName"))
                if let name = result?.takeUnretainedValue() as? String {
                    displayName = name
                }
            }

            // 获取版本
            var version = "1.0"
            if appObj.responds(to: NSSelectorFromString("shortVersionString")) {
                let result = appObj.perform(NSSelectorFromString("shortVersionString"))
                if let v = result?.takeUnretainedValue() as? String {
                    version = v
                }
            }

            // 获取数据容器
            let dataURL = getAppDataContainer(bundleID: bundleID)

            // 获取图标
            var icon: UIImage?
            if let bundlePath = bundlePath {
                if let iconFiles = try? FileManager.default.contentsOfDirectory(atPath: bundlePath) {
                    for file in iconFiles {
                        if file.hasPrefix("AppIcon") && file.hasSuffix(".png") {
                            icon = UIImage(contentsOfFile: bundlePath + "/" + file)
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
                    bundleVersion: version,
                    icon: icon
                ))
            }
        }

        print("[AppContainer] 解析出 \(apps.count) 个应用")
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
                print("[AppContainer] 无法访问 \(basePath)")
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

    private init(instance: NSObject) {
        self.instance = instance
        super.init()
    }

    static func `default`() -> LSApplicationWorkspace? {
        guard let LSApplicationWorkspaceClass = NSClassFromString("LSApplicationWorkspace") else {
            print("[LSWorkspace] LSApplicationWorkspace 类不存在")
            return nil
        }

        let defaultSelector = NSSelectorFromString("defaultWorkspace")
        guard LSApplicationWorkspaceClass.responds(to: defaultSelector) else {
            print("[LSWorkspace] defaultWorkspace 方法不存在")
            return nil
        }

        guard let method = class_getClassMethod(LSApplicationWorkspaceClass, defaultSelector) else {
            return nil
        }
        let imp = method_getImplementation(method)
        typealias GetDefaultFunc = @convention(c) (AnyClass, Selector) -> AnyObject?
        let getDefault = unsafeBitCast(imp, to: GetDefaultFunc.self)
        guard let obj = getDefault(LSApplicationWorkspaceClass, defaultSelector) as? NSObject else {
            print("[LSWorkspace] defaultWorkspace 返回 nil")
            return nil
        }

        return LSApplicationWorkspace(instance: obj)
    }

    func allApplications() -> NSArray? {
        let selector = NSSelectorFromString("allApplications")
        guard instance.responds(to: selector) else {
            print("[LSWorkspace] allApplications 方法不存在")
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
