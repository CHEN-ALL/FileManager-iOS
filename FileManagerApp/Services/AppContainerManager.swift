//
//  AppContainerManager.swift
//  FileManagerApp
//
//  跨应用容器访问服务
//  利用 MobileHouseArrest 信任漏洞，通过 MobileContainerManager 获取其他 App 的数据容器
//

import Foundation
import UIKit

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

        // 方法1: 通过 MobileContainerManager 私有框架
        if let apps = listViaMobileContainerManager() {
            results = apps
        }

        // 方法2: 扫描 Bundle 目录兜底
        if results.isEmpty {
            results = scanBundleDirectory()
        }

        return results.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    // MARK: - 方法1: 使用 MobileContainerManager 私有框架

    private func listViaMobileContainerManager() -> [InstalledApp]? {
        // 动态加载 MobileContainerManager
        guard let mcmBundle = Bundle(path: "/System/Library/PrivateFrameworks/MobileContainerManager.framework") else {
            return nil
        }

        do {
            try mcmBundle.loadAndReturnError()
        } catch {
            return nil
        }

        // 获取 MCMContainer 类
        guard let MCMContainer = NSClassFromString(@"MCMContainer") as? NSObject.Type else {
            return nil
        }

        // 获取 MCMAppDataContainer 类
        guard let MCMAppDataContainer = NSClassFromString(@"MCMAppDataContainer") else {
            return nil
        }

        // 获取 MCMAppInfoContainer 类
        guard let MCMAppInfoContainer = NSClassFromString(@"MCMAppInfoContainer") else {
            return nil
        }

        var apps: [InstalledApp] = []

        // 尝试从 containermanagerd 获取所有容器
        // 使用 MCMContainer 的 +allContainers 或类似方法
        let containerClasses: [AnyClass] = [
            MCMAppDataContainer,
            MCMAppInfoContainer
        ]

        for containerClass in containerClasses {
            // 尝试调用 +allContainers
            if containerClass.responds(to: Selector(("allContainers"))) {
                let _ = unsafeBitCast(containerClass, to: NSObject.Type.self)
                    .perform(Selector(("allContainers")))
                // 注意：这里返回的是 NSSet，需要进一步处理
            }
        }

        // 备用方案：通过 LSApplicationWorkspace 获取已安装应用
        if let workspace = LSApplicationWorkspace() {
            let appsDict = workspace.allApplications() as? [[String: Any]] ?? []
            for appInfo in appsDict {
                guard let bundleID = appInfo["ApplicationIdentifier"] as? String ?? appInfo["CFBundleIdentifier"] as? String else {
                    continue
                }

                // 获取应用 Bundle 路径
                var bundlePath: String?
                if let path = appInfo["BundleURL"] as? String {
                    bundlePath = path
                } else if let url = appInfo["BundleURL"] as? URL {
                    bundlePath = url.path
                }

                // 获取显示名称
                var displayName = bundleID
                if let name = appInfo["DisplayName"] as? String {
                    displayName = name
                } else if let name = appInfo["CFBundleDisplayName"] as? String {
                    displayName = name
                }

                // 获取版本
                var version = "1.0"
                if let v = appInfo["BundleVersion"] as? String {
                    version = v
                } else if let v = appInfo["CFBundleVersion"] as? String {
                    version = v
                }

                // 获取数据容器
                var dataURL: URL?
                if let dataContainer = getAppDataContainer(bundleID: bundleID) {
                    dataURL = dataContainer
                }

                // 获取图标
                var icon: UIImage?
                if let bundlePath = bundlePath {
                    let iconPath = bundlePath.appending("/AppIcon60x60@2x.png")
                    if FileManager.default.fileExists(atPath: iconPath) {
                        icon = UIImage(contentsOfFile: iconPath)
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
        }

        return apps.isEmpty ? nil : apps
    }

    // MARK: - 获取指定 App 的数据容器路径

    func getAppDataContainer(bundleID: String) -> URL? {
        // 方法1: 通过 MCMAppDataContainer
        if let containerClass = NSClassFromString(@"MCMAppDataContainer") {
            // MCMAppDataContainer *container = [MCMAppDataContainer containerWithIdentifier:bundleID createIfNecessary:NO existed:nil error:nil];
            let createIfNecessary: Bool = false
            var existed: Bool = false
            var error: NSDictionary?

            typealias ContainerCreateFunc = @convention(c) (AnyClass, Selector, String, Bool, UnsafeMutablePointer<Bool>, UnsafeMutablePointer<NSDictionary?>) -> Any?
            let selector = Selector(("containerWithIdentifier:createIfNecessary:existed:error:"))

            if containerClass.responds(to: selector) {
                let method = class_getClassMethod(containerClass, selector)!
                let imp = method_getImplementation(method)
                let function = unsafeBitCast(imp, to: ContainerCreateFunc.self)

                if let container = function(containerClass, selector, bundleID, createIfNecessary, &existed, &error) {
                    // 获取容器 URL
                    let urlSelector = Selector(("url"))
                    if container.responds(to: urlSelector) {
                        let urlImp = method_getImplementation(class_getInstanceMethod(type(of: container), urlSelector)!)
                        typealias GetURLFunc = @convention(c) (AnyObject, Selector) -> NSURL
                        let getURL = unsafeBitCast(urlImp, to: GetURLFunc.self)
                        let nsurl = getURL(container, urlSelector)
                        return nsurl as URL
                    }
                }
            }
        }

        // 方法2: 通过 MobileHouseArrest 方式
        // 使用 lockdown 的 house_arrest 服务获取 Documents 路径
        if let documentsPath = getDocumentsPathViaHouseArrest(bundleID: bundleID) {
            // Documents 的上级就是数据容器
            return URL(fileURLWithPath: (documentsPath as NSString).deletingLastPathComponent)
        }

        // 方法3: 直接扫描已知路径
        let containersPath = "/var/mobile/Containers/Data/Application/"
        do {
            let containers = try FileManager.default.contentsOfDirectory(atPath: containersPath)
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
        } catch {
            // 沙盒可能不允许直接访问
        }

        return nil
    }

    // MARK: - 通过 House Arrest 获取 Documents 路径

    private func getDocumentsPathViaHouseArrest(bundleID: String) -> String? {
        // 使用 MobileContainerManager 的 house_arrest 接口
        // 这是 iTunes/Finder 访问 App Documents 的正规通道
        guard let MCMContainer = NSClassFromString(@"MCMAppDataContainer") else {
            return nil
        }

        // 尝试通过 container 的 relativePath 属性
        let selector = Selector(("containerWithIdentifier:createIfNecessary:existed:error:"))
        if MCMContainer.responds(to: selector) {
            // 同上，调用方式略
            // 成功后返回 container 的 url
        }

        return nil
    }

    // MARK: - 方法2: 扫描 Bundle 目录（兜底）

    private func scanBundleDirectory() -> [InstalledApp] {
        var apps: [InstalledApp] = []

        // 扫描 /var/containers/Bundle/Application/
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
                // 查找 .app 文件
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

                        // 尝试获取数据容器
                        let dataURL = getAppDataContainer(bundleID: bundleID)

                        // 尝试获取图标
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
        guard let LSApplicationWorkspaceClass = NSClassFromString(@"LSApplicationWorkspace") else {
            return nil
        }

        let defaultSelector = Selector(("defaultWorkspace"))
        guard LSApplicationWorkspaceClass.responds(to: defaultSelector) else {
            return nil
        }

        let method = class_getClassMethod(LSApplicationWorkspaceClass, defaultSelector)!
        let imp = method_getImplementation(method)
        typealias GetDefaultFunc = @convention(c) (AnyClass, Selector) -> AnyObject
        let getDefault = unsafeBitCast(imp, to: GetDefaultFunc.self)
        guard let instance = getDefault(LSApplicationWorkspaceClass, defaultSelector) as? NSObject else {
            return nil
        }

        self.instance = instance
        super.init()
    }

    func allApplications() -> NSArray? {
        let selector = Selector(("allApplications"))
        guard instance.responds(to: selector) else {
            return nil
        }

        let method = class_getMethodDescription(type(of: instance), selector, false, true)
        let imp = method_getImplementation(class_getInstanceMethod(type(of: instance), selector)!)
        typealias GetAllAppsFunc = @convention(c) (AnyObject, Selector) -> NSArray
        let getAllApps = unsafeBitCast(imp, to: GetAllAppsFunc.self)
        return getAllApps(instance, selector)
    }
}
