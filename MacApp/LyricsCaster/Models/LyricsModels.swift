// LyricsModels.swift
// 数据模型 - Mac端和iOS端共享

import Foundation
import SwiftUI

// MARK: - 歌词行
struct LyricLine: Codable, Identifiable, Equatable {
    let id: UUID
    let time: Double      // 秒数（如 63.5 = 1:03.5）
    let text: String      // 歌词文本
    var translation: String? // 翻译（可选）

    init(id: UUID = UUID(), time: Double, text: String, translation: String? = nil) {
        self.id = id
        self.time = time
        self.text = text
        self.translation = translation
    }
}

// MARK: - 歌曲信息
struct SongInfo: Codable {
    let title: String
    let artist: String
    let album: String?
    let duration: Double?  // 总时长（秒）
}

// MARK: - 手机→Mac 消息协议
enum PeerMessageType: String, Codable {
    case songLoaded       // 歌曲加载完成，附带完整歌词
    case playbackSync     // 播放进度同步
    case lineChanged      // 当前行变化
    case playbackControl  // 播放/暂停/停止
}

struct PeerMessage: Codable {
    let type: PeerMessageType
    let payload: Data

    // 构造函数
    static func songLoaded(song: SongInfo, lyrics: [LyricLine]) -> PeerMessage {
        let data = SongLoadedPayload(song: song, lyrics: lyrics)
        let payload = (try? JSONEncoder().encode(data)) ?? Data()
        return PeerMessage(type: .songLoaded, payload: payload)
    }

    static func playbackSync(currentTime: Double, isPlaying: Bool, lineProgress: Double = 0) -> PeerMessage {
        let data = PlaybackSyncPayload(currentTime: currentTime, isPlaying: isPlaying, lineProgress: lineProgress)
        let payload = (try? JSONEncoder().encode(data)) ?? Data()
        return PeerMessage(type: .playbackSync, payload: payload)
    }

    static func lineChanged(lineIndex: Int, currentTime: Double) -> PeerMessage {
        let data = LineChangedPayload(lineIndex: lineIndex, currentTime: currentTime)
        let payload = (try? JSONEncoder().encode(data)) ?? Data()
        return PeerMessage(type: .lineChanged, payload: payload)
    }

    static func playbackControl(action: PlaybackAction) -> PeerMessage {
        let data = PlaybackControlPayload(action: action)
        let payload = (try? JSONEncoder().encode(data)) ?? Data()
        return PeerMessage(type: .playbackControl, payload: payload)
    }
}

struct SongLoadedPayload: Codable {
    let song: SongInfo
    let lyrics: [LyricLine]
}

struct PlaybackSyncPayload: Codable {
    let currentTime: Double
    let isPlaying: Bool
    var lineProgress: Double = 0  // 行内进度 0~1（逐字动画同步用）
}

struct LineChangedPayload: Codable {
    let lineIndex: Int
    let currentTime: Double
}

enum PlaybackAction: String, Codable {
    case play, pause, stop
}

struct PlaybackControlPayload: Codable {
    let action: PlaybackAction
}

// MARK: - 歌词样式配置
struct LyricsStyle: Codable {
    // 字体
    var fontName: String = "PingFang SC"
    var fontSize: CGFloat = 48
    var fontWeight: FontWeight = .bold

    // 当前行颜色
    var currentLineColor: CodableColor = CodableColor(r: 1, g: 0.85, b: 0)     // 金色
    var currentLineGlow: Bool = true

    // 其他行颜色
    var otherLineColor: CodableColor = CodableColor(r: 1, g: 1, b: 1, a: 0.5)  // 半透明白

    // 已唱过行颜色
    var pastLineColor: CodableColor = CodableColor(r: 0.6, g: 0.6, b: 0.6, a: 0.4)

    // 背景
    var backgroundColor: CodableColor = CodableColor(r: 0, g: 0, b: 0)          // 黑色
    var backgroundOpacity: Double = 1.0
    var backgroundImage: String? = nil  // 背景图片路径

    // 动画
    var animationStyle: AnimationStyleType = .smooth
    var animationSpeed: Double = 0.5  // 0.1~1.0

    // 布局
    var alignment: TextAlignmentType = .center
    var lineSpacing: CGFloat = 20
    var showTranslation: Bool = true
    var visibleLineCount: Int = 5     // 可见行数（当前行上下各几行）
    var padding: CGFloat = 40

    enum FontWeight: String, Codable, CaseIterable {
        case regular, medium, semibold, bold, heavy
        var swiftUI: Font.Weight {
            switch self {
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            case .heavy: return .heavy
            }
        }
    }

    enum AnimationStyleType: String, Codable, CaseIterable {
        case none = "无动画"
        case smooth = "平滑滚动"
        case fade = "淡入淡出"
        case scale = "缩放高亮"
        case karaoke = "卡拉OK逐字"
        case bounce = "弹跳节拍"
        case wave = "波浪律动"
        case pulse = "脉冲呼吸"
        case typewriter = "打字机"
        case slideIn = "滑入聚焦"
        case charBounce = "逐字弹入"
        case scatter = "散落歌词"
        case float3D = "3D浮现"
        case randomSize = "随机大小"
    }

    enum TextAlignmentType: String, Codable, CaseIterable {
        case leading = "左对齐"
        case center = "居中"
        case trailing = "右对齐"
        var swiftUI: TextAlignment {
            switch self {
            case .leading: return .leading
            case .center: return .center
            case .trailing: return .trailing
            }
        }
        var horizontal: HorizontalAlignment {
            switch self {
            case .leading: return .leading
            case .center: return .center
            case .trailing: return .trailing
            }
        }
    }
}

// 可编码的颜色
struct CodableColor: Codable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double = 1.0

    var color: Color { Color(red: r, green: g, blue: b, opacity: a) }
    var nsColor: NSColor { NSColor(red: r, green: g, blue: b, alpha: a) }

    init(r: Double, g: Double, b: Double, a: Double = 1.0) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    init(from nsColor: NSColor) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        let c = nsColor.usingColorSpace(.sRGB) ?? nsColor
        c.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.r = Double(red); self.g = Double(green); self.b = Double(blue); self.a = Double(alpha)
    }
}
