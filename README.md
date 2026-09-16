# iPhone 自签文件管理器

一个支持自签安装的 iOS 文件管理器应用，可以访问应用沙盒数据，提供完整的文件操作功能。

## 功能特性

### 文件浏览
- 📁 浏览应用 Documents 沙盒目录
- 📂 文件夹层级导航，支持返回上级
- 🔄 多种排序方式（名称/修改时间/大小/类型）
- 📊 文件大小、修改时间显示

### 文件操作
- ✏️ **新建文件夹** — 在当前目录创建新文件夹
- 📄 **新建文本文件** — 创建 .txt 文本文件
- 📋 **复制** — 复制文件/文件夹（自动处理重名）
- 📂 **移动** — 将选中项移动到指定目录
- 🗑️ **删除** — 滑动删除或批量删除（带确认提示）
- 🏷️ **重命名** — 滑动操作重命名文件/文件夹
- 📥 **导入文件** — 从"文件"App 或其他 App 导入文件
- 📤 **分享** — 通过系统分享 sheet 分享文件

### 批量操作
- 长按进入选择模式
- 多选后可批量复制/移动/删除/分享
- 底部操作栏快速执行批量操作

### 文件预览
- 图片、视频、音频、PDF 等系统快速预览（QuickLook）
- 文本文件内容内联预览
- 文件详情页（大小/路径/创建修改时间）

## 项目结构

```
FileManagerApp/
├── FileManagerApp.xcodeproj/       # Xcode 项目文件
│   ├── project.pbxproj
│   └── xcshareddata/xcschemes/
│       └── FileManagerApp.xcscheme
└── FileManagerApp/
    ├── FileManagerApp.swift         # App 入口
    ├── Assets.xcassets/            # 资源目录
    ├── Resources/
    │   └── Info.plist              # 应用配置
    ├── Models/
    │   └── FileItem.swift          # 文件数据模型
    ├── Services/
    │   └── FileManagerService.swift # 文件操作核心服务
    └── Views/
        ├── FileListView.swift       # 文件列表主界面
        ├── FileDetailView.swift     # 文件详情页
        └── MoveDestinationView.swift # 移动目标选择
```

## 环境要求

- Xcode 15.0+
- iOS 16.0+（部署目标）
- Swift 5.0

---

## 自签安装方法

### 方法一：Xcode 直接安装（最简单）

**适合：有 Mac，可连接 iPhone 的用户**

1. 安装 [Xcode](https://apps.apple.com/cn/app/xcode/id497799835)（App Store 免费下载）
2. 用数据线连接 iPhone 到 Mac
3. 双击 `FileManagerApp.xcodeproj` 打开项目
4. 在 Xcode 顶部选择你的 iPhone 作为运行目标
5. 点击运行按钮（▶️）
6. **首次运行需要**：
   - 打开 iPhone → 设置 → 通用 → VPN与设备管理
   - 信任你的开发者证书
   - 如提示"开发者未受信任"，去设置中信任即可

> **免费账号限制**：7 天后证书过期，需要重新连接 Xcode 运行一次。

---

### 方法二：Sideloadly（Windows / Mac 通用）

**适合：没有 Mac 但想自签的用户**

1. 先在 Xcode 中编译出 `.ipa` 文件：
   - 打开项目 → Product → Archive
   - 导出为 IPA 文件

2. 下载安装 [Sideloadly](https://sideloadly.io/)

3. 操作步骤：
   - 用数据线连接 iPhone
   - 打开 Sideloadly
   - 拖入编译好的 `.ipa` 文件
   - 输入你的 Apple ID（免费账号即可）
   - 点击 Start，等待安装完成
   - iPhone 上信任证书（设置 → 通用 → VPN与设备管理）

> **注意**：免费 Apple ID 签名的应用 7 天过期，需要重新安装。
> 付费开发者账号（$99/年）有效期为 1 年。

---

### 方法三：AltStore（自动续期）

**适合：希望自动续期、不想每周重新签的用户**

1. 下载 [AltServer](https://altstore.io/)（Windows / Mac）
2. 安装 AltServer 到电脑
3. 连接 iPhone，通过 AltServer 安装 AltStore
4. 在 iPhone 上打开 AltStore
5. 将编译好的 `.ipa` 文件通过 AirDrop 或文件分享发送到 AltStore
6. 在 AltStore 中点击 "+" 号安装应用

> AltServer 会在同一 Wi-Fi 下自动续期，只要电脑和手机在同一网络，就不会过期。

---

### 方法四：TrollStore（永久签名，无需证书）

**适合：iPhone 8 ~ iPhone 15，iOS 14.0 ~ 16.6.1 / 17.0**

如果你的设备支持 TrollStore，可以**永久安装**应用，无需证书、无需电脑。

1. 先确认你的 iOS 版本是否支持 [TrollStore](https://github.com/opa334/TrollStore)
2. 按照官方教程安装 TrollStore
3. 将编译好的 `.ipa` 文件传到 iPhone
4. 在 TrollStore 中点击 IPA 文件 → 安装

> **TrollStore 安装的应用永久有效**，不需要重新签名。

---

### 方法五：在线签名网站（免电脑）

**适合：不想装软件、临时使用的用户**

常见的在线签名服务（搜索即可）：
- 爱思助手（PC端）
- 沙漏验机
- 各类企业签名平台

> 注意：企业签名可能随时失效，稳定性不保证。

---

## 编译为 IPA 的步骤（供自签使用）

如果你要用 Sideloadly / AltStore / TrollStore 安装，需要先编译出 IPA 文件：

1. 打开 `FileManagerApp.xcodeproj`
2. 选择 **Any iOS Device (arm64)** 作为目标
3. 菜单 → Product → Archive
4. 等待编译完成，在 Organizer 中选择刚刚的 Archive
5. 点击 **Distribute App** → **Custom** → **Copy from iOS App**
6. 导出得到 `.ipa` 文件

---

## 关于沙盒访问

本应用访问的是**应用自身的沙盒目录**：

| 目录 | 路径 | 用途 |
|------|------|------|
| Documents | `~/Documents/` | 用户文件，iTunes/Finder 可访问 |
| Library | `~/Library/` | 应用支持文件 |
| tmp | `~/tmp/` | 临时文件，系统会自动清理 |

应用已开启 **UIFileSharingEnabled**（iTunes 文件共享）和 **LSSupportsOpeningDocumentsInPlace**，你可以通过：
- iTunes / Finder 直接拖拽文件到应用
- iOS"文件"App 中看到本应用的 Documents 目录
- 其他 App 通过"打开方式"导入文件到本应用

---

## 技术说明

- **UI 框架**：SwiftUI（iOS 16+）
- **架构模式**：MVVM（ObservableObject 服务层）
- **文件操作**：NSFileManager
- **文件预览**：QuickLook 框架
- **文件导入**：UIDocumentPicker
- **最低系统**：iOS 16.0
- **支持设备**：iPhone / iPad

---

## 常见问题

**Q：安装后打开闪退？**
A：请到 设置 → 通用 → VPN与设备管理 中信任开发者证书。

**Q：免费账号签名多久过期？**
A：7 天。需要重新连接 Xcode 运行，或用 AltStore 自动续期。

**Q：为什么看不到其他 App 的数据？**
A：iOS 沙盒机制限制，每个 App 只能访问自己的沙盒目录。这是系统安全设计，无法绕过（除非越狱）。

**Q：如何从电脑往这个 App 传文件？**
A：连接 iPhone 到电脑 → 打开 iTunes/Finder → 选择你的设备 → 文件共享 → 选择"文件管理器" → 拖拽文件即可。
