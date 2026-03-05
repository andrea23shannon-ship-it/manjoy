#!/bin/bash
# LyricsCaster Mac App 打包 DMG 脚本
# 使用方法：在 MacApp 目录下运行 ./create_dmg.sh

APP_NAME="LyricsCaster"
DMG_NAME="LyricsCaster_Installer"
VERSION="1.0"
BUILD_DIR="build"
DMG_DIR="$BUILD_DIR/dmg"
DMG_PATH="$BUILD_DIR/${DMG_NAME}_v${VERSION}.dmg"

echo "🎵 LyricsCaster DMG 打包工具"
echo "=============================="

# 检查是否有编译好的 app
APP_PATH=""

# 优先查找 Archive 导出的 app
if [ -d "${APP_NAME}.app" ]; then
    APP_PATH="${APP_NAME}.app"
# 查找 Xcode DerivedData 中的 app
elif [ -d "$HOME/Library/Developer/Xcode/DerivedData" ]; then
    FOUND=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "${APP_NAME}.app" -path "*/Build/Products/Release/*" -maxdepth 6 2>/dev/null | head -1)
    if [ -n "$FOUND" ]; then
        APP_PATH="$FOUND"
    fi
fi

if [ -z "$APP_PATH" ]; then
    echo ""
    echo "❌ 未找到编译好的 ${APP_NAME}.app"
    echo ""
    echo "请先在 Xcode 中编译："
    echo "  1. 打开 LyricsCaster.xcodeproj"
    echo "  2. 选择 Product → Build (或 ⌘B)"
    echo "  3. 或使用命令行编译："
    echo "     xcodebuild -project LyricsCaster.xcodeproj -scheme LyricsCaster -configuration Release build"
    echo ""
    echo "编译完成后再运行此脚本"
    exit 1
fi

echo "✅ 找到 App: $APP_PATH"

# 清理旧文件
rm -rf "$DMG_DIR" "$DMG_PATH"
mkdir -p "$DMG_DIR"

# 复制 app 到 DMG 目录
echo "📦 复制 App..."
cp -R "$APP_PATH" "$DMG_DIR/"

# 创建 Applications 文件夹的快捷方式
ln -s /Applications "$DMG_DIR/Applications"

# 创建安装说明
cat > "$DMG_DIR/.background_readme.txt" << 'EOF'
将 LyricsCaster 拖到 Applications 文件夹即可安装
EOF

# 创建 DMG
echo "💿 创建 DMG..."
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH"

if [ $? -eq 0 ]; then
    # 清理临时文件
    rm -rf "$DMG_DIR"

    DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
    echo ""
    echo "=============================="
    echo "✅ DMG 打包成功！"
    echo "📁 文件: $DMG_PATH"
    echo "📊 大小: $DMG_SIZE"
    echo ""
    echo "安装方式："
    echo "  1. 双击 DMG 文件打开"
    echo "  2. 将 LyricsCaster 拖到 Applications 文件夹"
    echo "  3. 弹出 DMG"
    echo "  4. 从启动台打开 LyricsCaster"
    echo ""
    echo "⚠️  首次打开可能提示"无法验证开发者"："
    echo "  → 系统设置 → 隐私与安全性 → 仍要打开"
else
    echo "❌ DMG 创建失败"
    exit 1
fi
