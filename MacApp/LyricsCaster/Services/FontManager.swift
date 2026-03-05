// FontManager.swift
// Mac端 - 自定义字体管理器
// 支持导入 .ttf / .otf 字体文件，注册到系统并持久化

import Foundation
import CoreText
import AppKit
import UniformTypeIdentifiers

class FontManager: ObservableObject {
    static let shared = FontManager()

    /// 已导入的自定义字体列表：[(显示名称, PostScript名/字体名, 文件路径)]
    @Published var customFonts: [CustomFont] = []

    /// 字体文件存储目录
    private var fontDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("LyricsCaster/Fonts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private let savedKey = "customFontPaths"

    init() {
        loadAndRegisterFonts()
    }

    // MARK: - 导入字体

    /// 打开文件选择器让用户选择字体文件
    func importFont(completion: @escaping (Bool, String) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "选择字体文件"
        panel.allowedContentTypes = [
            UTType(filenameExtension: "ttf") ?? .data,
            UTType(filenameExtension: "otf") ?? .data,
            UTType(filenameExtension: "ttc") ?? .data
        ]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        panel.begin { [weak self] response in
            guard response == .OK, let self = self else {
                DispatchQueue.main.async { completion(false, "取消导入") }
                return
            }

            var importedCount = 0
            for url in panel.urls {
                if self.installFont(from: url) {
                    importedCount += 1
                }
            }

            DispatchQueue.main.async {
                if importedCount > 0 {
                    self.saveFontList()
                    completion(true, "成功导入 \(importedCount) 个字体")
                } else {
                    completion(false, "导入失败，字体文件可能已存在或格式不支持")
                }
            }
        }
    }

    /// 安装单个字体文件（复制到 App 目录 + 注册）
    private func installFont(from sourceURL: URL) -> Bool {
        let fileName = sourceURL.lastPathComponent
        let destURL = fontDirectory.appendingPathComponent(fileName)

        // 检查是否已存在
        if customFonts.contains(where: { $0.filePath == destURL.path }) {
            return false
        }

        // 复制到 App 字体目录
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
        } catch {
            print("[FontManager] 复制字体文件失败: \(error)")
            return false
        }

        // 注册字体
        guard let font = registerFont(at: destURL) else {
            try? FileManager.default.removeItem(at: destURL)
            return false
        }

        DispatchQueue.main.async {
            self.customFonts.append(font)
        }
        return true
    }

    /// 注册字体到 CoreText 并返回字体信息
    private func registerFont(at url: URL) -> CustomFont? {
        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)

        if !success {
            // 可能已注册，尝试读取信息
            print("[FontManager] 注册字体失败: \(error?.takeRetainedValue().localizedDescription ?? "未知错误")")
        }

        // 读取字体信息
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let firstDesc = descriptors.first else {
            return nil
        }

        let fontName = CTFontDescriptorCopyAttribute(firstDesc, kCTFontNameAttribute) as? String ?? url.deletingPathExtension().lastPathComponent
        let displayName = CTFontDescriptorCopyAttribute(firstDesc, kCTFontDisplayNameAttribute) as? String ?? fontName
        let familyName = CTFontDescriptorCopyAttribute(firstDesc, kCTFontFamilyNameAttribute) as? String ?? displayName

        return CustomFont(
            displayName: displayName,
            fontName: fontName,
            familyName: familyName,
            filePath: url.path
        )
    }

    // MARK: - 删除字体

    func removeFont(_ font: CustomFont) {
        // 注销字体
        let url = URL(fileURLWithPath: font.filePath)
        CTFontManagerUnregisterFontsForURL(url as CFURL, .process, nil)

        // 删除文件
        try? FileManager.default.removeItem(atPath: font.filePath)

        // 更新列表
        customFonts.removeAll { $0.id == font.id }
        saveFontList()
    }

    // MARK: - 持久化

    private func saveFontList() {
        let paths = customFonts.map { $0.filePath }
        UserDefaults.standard.set(paths, forKey: savedKey)
    }

    private func loadAndRegisterFonts() {
        guard let paths = UserDefaults.standard.stringArray(forKey: savedKey) else { return }

        var loaded: [CustomFont] = []
        for path in paths {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else { continue }
            if let font = registerFont(at: url) {
                loaded.append(font)
            }
        }
        customFonts = loaded
    }
}

// MARK: - 自定义字体模型
struct CustomFont: Identifiable, Equatable {
    let id = UUID()
    let displayName: String   // 显示名称（中文名或英文名）
    let fontName: String      // PostScript 名称（用于 .custom()）
    let familyName: String    // 字体族名
    let filePath: String      // 文件路径

    static func == (lhs: CustomFont, rhs: CustomFont) -> Bool {
        lhs.filePath == rhs.filePath
    }
}
