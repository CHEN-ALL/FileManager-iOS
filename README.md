# iPhone 文件管理器（企业签名版）

支持访问其他 App 数据容器的 iOS 文件管理器，基于 MobileContainerManager 漏洞技术。

## 功能特性

### 三个 Tab 页面

**1. 我的文件**
- 浏览自身 Documents 沙盒目录
- 新建文件夹/文本文件、复制/移动/删除/重命名
- 从文件 App 导入、系统分享导出
- 排序、批量选择、QuickLook 预览

**2. 应用数据**
- 列出所有已安装的第三方应用
- 点击进入其他 App 的数据容器目录
- 浏览 Documents / Library / Caches 等子目录
- 搜索应用名称或 Bundle ID

**3. 清理**
- 一键扫描并清理缓存和临时文件

## 技术原理

本项目参考 3105 项目的实现方式：

- **Bundle ID 伪装**：使用 `com.apple.mobile.MobileHouseArrest` 作为 Bundle Identifier
- **MCM 信任漏洞**：MobileContainerManager 在分配容器时信任调用者的 CodeDirectory identifier
- **私有框架调用**：通过 `NSClassFromString` 动态加载 `MobileContainerManager.framework`
- **特殊 Entitlements**：包含 `platform-application`、`no-sandbox`、`container-manager` 等权限

## 安装要求

### 必须条件

| 项目 | 要求 |
|------|------|
| 证书 | **企业开发者证书**（$299/年），普通免费 Apple ID 无效 |
| 系统 | iOS 17.0 - iOS 26.6.1 / iOS 27 beta（利用的漏洞在 iOS 27 beta 5 已修复） |
| 签名方式 | 手动签名（Manual Signing），不能用 AltStore/Sideloadly |
| Bundle ID | 必须是 `com.apple.mobile.MobileHouseArrest` |

### 不支持的安装方式
- ❌ AltStore / SideStore
- ❌ Sideloadly（免费账号）
- ❌ 3uTools
- ❌ LiveContainer

## 企业签名步骤

### 1. 编译 IPA
通过 GitHub Actions 编译出未签名的 IPA（配置已在 `.github/workflows/build-ipa.yml`）

### 2. 用企业证书重签名
使用 `codesign` 或 `ldid` 注入 entitlements 并用企业证书签名：

```bash
# 安装 ldid（用于注入 entitlements）
brew install ldid

# 解压 IPA
unzip FileManagerApp.ipa -d ipa_payload
cd ipa_payload/Payload/FileManagerApp.app

# 注入 entitlements
ldid -SFileManagerApp/Resources/FileManagerApp.entitlements FileManagerApp

# 用企业证书签名
codesign --force --sign "iPhone Distribution: Your Company Name" \
    --entitlements FileManagerApp.entitlements \
    --timestamp=none \
    .

# 重新打包
cd ../..
zip -r FileManagerApp-signed.zip Payload
```

### 3. 安装到设备
通过 MDM 或企业签名工具安装到 iPhone。

## 项目结构

```
FileManagerApp/
├── FileManagerApp.xcodeproj/
└── FileManagerApp/
    ├── FileManagerApp.swift          # 主入口（TabView）
    ├── Models/FileItem.swift
    ├── Services/
    │   ├── FileManagerService.swift   # 自身文件操作
    │   └── AppContainerManager.swift  # ★ 跨 App 容器访问
    ├── Views/
    │   ├── FileListView.swift
    │   ├── InstalledAppsView.swift    # ★ 已安装应用列表
    │   ├── AppDataContainerView.swift # ★ 其他 App 数据浏览
    │   └── MoveDestinationView.swift
    └── Resources/
        ├── Info.plist
        └── FileManagerApp.entitlements # ★ 特殊权限
```

## 注意事项

- **数据安全**：只修改自己拥有或有权访问的数据
- **备份**：操作重要数据前先备份
- **漏洞有效期**：Apple 可能随时通过系统更新修复该漏洞
- **证书风险**：企业证书可能被 Apple 吊销
