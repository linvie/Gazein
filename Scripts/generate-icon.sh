#!/bin/bash
# 生成 App 图标

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET_DIR="$PROJECT_DIR/Resources/AppIcon.iconset"
ICNS_FILE="$PROJECT_DIR/Resources/AppIcon.icns"

# 如果已经有图标，跳过
if [ -f "$ICNS_FILE" ]; then
    echo "图标已存在: $ICNS_FILE"
    exit 0
fi

echo "🎨 生成 App 图标..."

# 创建 iconset 目录
mkdir -p "$ICONSET_DIR"

# 使用 Swift 生成图标
swift << 'SWIFT'
import AppKit

func createIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    // 背景渐变
    let gradient = NSGradient(colors: [
        NSColor(red: 0.29, green: 0.56, blue: 0.85, alpha: 1.0),
        NSColor(red: 0.17, green: 0.35, blue: 0.63, alpha: 1.0)
    ])

    let margin = CGFloat(size) * 0.05
    let cornerRadius = CGFloat(size) * 0.18
    let bgRect = NSRect(x: margin, y: margin, width: CGFloat(size) - margin * 2, height: CGFloat(size) - margin * 2)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)
    gradient?.draw(in: bgPath, angle: -45)

    // 眼睛 - 白色
    let eyeCenterX = CGFloat(size) / 2
    let eyeCenterY = CGFloat(size) * 0.58
    let eyeRx = CGFloat(size) * 0.22
    let eyeRy = CGFloat(size) * 0.15

    let eyePath = NSBezierPath(ovalIn: NSRect(
        x: eyeCenterX - eyeRx,
        y: eyeCenterY - eyeRy,
        width: eyeRx * 2,
        height: eyeRy * 2
    ))
    NSColor.white.setFill()
    eyePath.fill()

    // 瞳孔 - 深蓝
    let pupilR = CGFloat(size) * 0.08
    let pupilPath = NSBezierPath(ovalIn: NSRect(
        x: eyeCenterX - pupilR,
        y: eyeCenterY - pupilR,
        width: pupilR * 2,
        height: pupilR * 2
    ))
    NSColor(red: 0.17, green: 0.35, blue: 0.63, alpha: 1.0).setFill()
    pupilPath.fill()

    // 高光
    let highlightR = CGFloat(size) * 0.025
    let highlightPath = NSBezierPath(ovalIn: NSRect(
        x: eyeCenterX - pupilR * 0.3 - highlightR,
        y: eyeCenterY + pupilR * 0.3 - highlightR,
        width: highlightR * 2,
        height: highlightR * 2
    ))
    NSColor.white.setFill()
    highlightPath.fill()

    // 下方弧形 (眼睛下眼睑效果)
    let lowerY = CGFloat(size) * 0.32
    let lowerPath = NSBezierPath(ovalIn: NSRect(
        x: eyeCenterX - eyeRx * 1.2,
        y: lowerY - eyeRy * 0.6,
        width: eyeRx * 2.4,
        height: eyeRy * 1.2
    ))
    NSColor.white.withAlphaComponent(0.8).setFill()
    lowerPath.fill()

    image.unlockFocus()
    return image
}

func saveIcon(image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        return
    }
    try? pngData.write(to: URL(fileURLWithPath: path))
}

let iconsetPath = ProcessInfo.processInfo.environment["ICONSET_DIR"] ?? "/tmp/AppIcon.iconset"

let sizes = [16, 32, 64, 128, 256, 512, 1024]
for size in sizes {
    let icon = createIcon(size: size)
    saveIcon(image: icon, to: "\(iconsetPath)/icon_\(size)x\(size).png")

    if size <= 512 {
        let icon2x = createIcon(size: size * 2)
        saveIcon(image: icon2x, to: "\(iconsetPath)/icon_\(size)x\(size)@2x.png")
    }
}

print("Icons generated in: \(iconsetPath)")
SWIFT

# 检查是否成功生成
if [ -d "$ICONSET_DIR" ] && [ "$(ls -A $ICONSET_DIR 2>/dev/null)" ]; then
    # 转换为 icns
    iconutil -c icns "$ICONSET_DIR" -o "$ICNS_FILE"
    rm -rf "$ICONSET_DIR"
    echo "✅ 图标已生成: $ICNS_FILE"
else
    echo "⚠️  图标生成失败，使用系统默认图标"
fi
