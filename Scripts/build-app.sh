#!/bin/bash
# Gazein App Bundle 构建脚本

set -e

# 配置
APP_NAME="Gazein"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
OUTPUT_DIR="$PROJECT_DIR/build"
APP_DIR="$OUTPUT_DIR/${APP_NAME}.app"

echo "🔨 构建 $APP_NAME..."

# 1. 构建 Release 版本
cd "$PROJECT_DIR"
swift build -c release

# 2. 创建 App Bundle 目录结构
echo "📦 创建 App Bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# 3. 复制可执行文件
cp "$BUILD_DIR/release/$APP_NAME" "$APP_DIR/Contents/MacOS/"

# 4. 复制 Info.plist
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/"

# 5. 创建 PkgInfo
echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"

# 6. 复制图标
if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/"
    echo "✅ 已复制图标"
fi

# 7. 设置权限
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

echo ""
echo "✅ 构建完成!"
echo "   App 位置: $APP_DIR"
echo ""
echo "📝 使用说明:"
echo "   1. 双击打开 $APP_NAME.app"
echo "   2. 首次运行需要在系统设置中授予权限:"
echo "      - 系统设置 → 隐私与安全 → 屏幕录制 → 允许 Gazein"
echo "      - 系统设置 → 隐私与安全 → 辅助功能 → 允许 Gazein"
echo ""
echo "🚀 立即运行:"
echo "   open \"$APP_DIR\""
