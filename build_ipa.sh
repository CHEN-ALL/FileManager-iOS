#!/bin/bash
#
# build_ipa.sh
# 在 macOS 上一键编译 FileManagerApp 为 IPA
#
# 使用方法：
#   1. 把整个 FileManagerApp 文件夹拷到 Mac 上
#   2. 打开终端，cd 到项目根目录
#   3. 运行: chmod +x build_ipa.sh && ./build_ipa.sh
#
# 前置要求：
#   - macOS 12+
#   - Xcode 15+（App Store 免费安装）
#   - 命令行工具: xcode-select --install
#

set -e

PROJECT_NAME="FileManagerApp"
SCHEME="FileManagerApp"
CONFIGURATION="Release"
BUILD_DIR="./build"
ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/ipa_output"

echo "========================================="
echo "  编译 ${PROJECT_NAME} -> IPA"
echo "========================================="

# 检查 Xcode 是否安装
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 未找到 xcodebuild，请先安装 Xcode"
    echo "   App Store 搜索 Xcode 安装，或运行: xcode-select --install"
    exit 1
fi

# 检查项目文件
if [ ! -d "${PROJECT_NAME}.xcodeproj" ]; then
    echo "❌ 未找到 ${PROJECT_NAME}.xcodeproj，请在项目根目录运行此脚本"
    exit 1
fi

echo ""
echo "[1/4] 清理旧的构建..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

echo ""
echo "[2/4] 编译 Archive（Release 模式）..."
xcodebuild archive \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -destination "generic/platform=iOS" \
    -archivePath "${ARCHIVE_PATH}" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    DEVELOPMENT_TEAM="" \
    | xcpretty 2>/dev/null || xcodebuild archive \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -destination "generic/platform=iOS" \
    -archivePath "${ARCHIVE_PATH}" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    DEVELOPMENT_TEAM=""

echo ""
echo "[3/4] 打包为 IPA（不签名）..."
mkdir -p "${EXPORT_PATH}/Payload"
cp -R "${ARCHIVE_PATH}/Products/Applications/${PROJECT_NAME}.app" "${EXPORT_PATH}/Payload/"

cd "${EXPORT_PATH}"
zip -r "${PROJECT_NAME}.ipa" Payload
cd - > /dev/null

IPA_PATH="${EXPORT_PATH}/${PROJECT_NAME}.ipa"

echo ""
echo "[4/4] 完成！"
echo "========================================="
echo "  IPA 路径: ${IPA_PATH}"
echo "  文件大小: $(du -h "${IPA_PATH}" | cut -f1)"
echo "========================================="
echo ""
echo "下一步："
echo "  • 用 Sideloadly / AltStore 签名安装到 iPhone"
echo "  • 或用 TrollStore 直接安装（如果设备支持）"
echo "  • 或用 Xcode 连接设备直接运行（调试模式）"
