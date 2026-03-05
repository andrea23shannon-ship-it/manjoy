// LyricsModels.swift
// iOS端 - 数据模型（与Mac端共享的协议模型）

import Foundation

// MARK: - 歌词行
struct LyricLine: Codable, Identifiable, Equatable {
    let id: UUID
    let time: Double
    let text: String
    var translation: String?

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
    let duration: Double?
}

// MARK: - 搜索结果
struct SearchResult: Identifiable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let source: LyricsSource
    let sourceId: String   // 用于获取歌词的ID
}

enum LyricsSource: String, Codable {
    case netease = "网易云"
    case qqMusic = "QQ音乐"
    case kugou = "酷狗"
}

// MARK: - 消息协议（与Mac端完全一致）
enum PeerMessageType: String, Codable {
    case songLoaded
    case playbackSync
    case lineChanged
    case playbackControl
}

struct PeerMessage: Codable {
    let type: PeerMessageType
    let payload: Data

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

// MARK: - LRC解析器
struct LRCParser {
    /// 解析LRC格式歌词文本
    static func parse(_ lrcText: String) -> [LyricLine] {
        var lines: [LyricLine] = []

        // 支持多种时间格式: [mm:ss.xx], [mm:ss.xxx], [mm:ss:xx], [mm:ss]
        let timePattern = #"\[(\d{1,3}):(\d{2})(?:[\.:](\d{1,3}))?\]"#
        guard let regex = try? NSRegularExpression(pattern: timePattern) else { return [] }

        for rawLine in lrcText.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let matches = regex.matches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))
            guard !matches.isEmpty else { continue }

            // 提取歌词文本（去掉所有时间标签和其他方括号标签）
            var text = trimmed
            // 先去掉所有 [xxx] 形式的标签
            let allTagPattern = #"\[[^\]]*\]"#
            if let allTagRegex = try? NSRegularExpression(pattern: allTagPattern) {
                text = allTagRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
            }
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            // 为每个时间标签创建一行
            for match in matches {
                guard let minRange = Range(match.range(at: 1), in: trimmed),
                      let secRange = Range(match.range(at: 2), in: trimmed) else { continue }

                let minutes = Double(trimmed[minRange]) ?? 0
                let seconds = Double(trimmed[secRange]) ?? 0
                var ms: Double = 0

                if match.range(at: 3).location != NSNotFound,
                   let msRange = Range(match.range(at: 3), in: trimmed) {
                    let msStr = String(trimmed[msRange])
                    let msVal = Double(msStr) ?? 0
                    let msDivisor: Double = msStr.count <= 2 ? 100 : 1000
                    ms = msVal / msDivisor
                }

                let time = minutes * 60 + seconds + ms
                lines.append(LyricLine(time: time, text: text))
            }
        }

        let sorted = lines.sorted { $0.time < $1.time }
        print("[LRCParser] 解析完成: \(sorted.count) 行")
        return sorted
    }
}
