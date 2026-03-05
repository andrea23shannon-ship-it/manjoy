// LyricsSearchService.swift
// iOS端 - 在线歌词搜索服务
// 支持网易云、QQ音乐、酷狗三大源

import Foundation

class LyricsSearchService: ObservableObject {
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var error: String?
    @Published var selectedSource: LyricsSource = .qqMusic  // 默认QQ音乐

    // 自定义 URLSession，忽略缓存
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    // MARK: - 搜索歌曲（按选中的源搜索）
    func search(keyword: String) async {
        guard !keyword.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        DispatchQueue.main.async {
            self.isSearching = true
            self.error = nil
            self.searchResults = []
        }

        let source = await MainActor.run { selectedSource }
        var results: [SearchResult] = []

        switch source {
        case .qqMusic:
            results = await searchQQMusic(keyword: keyword)
        case .netease:
            results = await searchNetease(keyword: keyword)
        case .kugou:
            results = await searchKugou(keyword: keyword)
        }

        DispatchQueue.main.async {
            self.searchResults = results
            self.isSearching = false
            if results.isEmpty {
                self.error = "未找到相关歌曲"
            }
        }
    }

    // MARK: - 获取歌词
    func fetchLyrics(result: SearchResult) async -> [LyricLine]? {
        print("[LyricsSearch] 开始获取歌词: \(result.title) - \(result.artist), source=\(result.source.rawValue), id=\(result.sourceId)")
        var lines: [LyricLine]?
        switch result.source {
        case .netease:
            lines = await fetchNeteaseLyrics(id: result.sourceId)
        case .qqMusic:
            lines = await fetchQQLyrics(id: result.sourceId)
        case .kugou:
            lines = await fetchKugouLyrics(id: result.sourceId)
        }

        if let lines = lines {
            print("[LyricsSearch] 歌词获取成功，共 \(lines.count) 行")
        } else {
            print("[LyricsSearch] 歌词获取失败")
        }
        return lines
    }

    // MARK: - 辅助：从可能的JSONP响应中提取JSON
    private func extractJSON(from data: Data) -> [String: Any]? {
        // 先尝试直接解析JSON
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
        // 尝试从JSONP格式提取: callback({...})
        if let text = String(data: data, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            // 找到第一个 ( 和最后一个 )
            if let startIdx = trimmed.firstIndex(of: "("),
               let endIdx = trimmed.lastIndex(of: ")") {
                let jsonStart = trimmed.index(after: startIdx)
                let jsonStr = String(trimmed[jsonStart..<endIdx])
                if let jsonData = jsonStr.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    return json
                }
            }
        }
        return nil
    }

    // MARK: - 网易云搜索
    private func searchNetease(keyword: String) async -> [SearchResult] {
        guard let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://music.163.com/api/search/get/web?s=\(encoded)&type=1&limit=20") else {
            return []
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")

        do {
            let (data, response) = try await session.data(for: request)
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[LyricsSearch] 网易云搜索 HTTP \(httpCode), 数据大小: \(data.count)")

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["result"] as? [String: Any],
               let songs = result["songs"] as? [[String: Any]] {
                return songs.compactMap { song in
                    guard let id = song["id"] as? Int,
                          let name = song["name"] as? String,
                          let artists = song["artists"] as? [[String: Any]],
                          let artistName = artists.first?["name"] as? String else { return nil }
                    let album = (song["album"] as? [String: Any])?["name"] as? String
                    return SearchResult(
                        id: "netease_\(id)",
                        title: name,
                        artist: artistName,
                        album: album,
                        source: .netease,
                        sourceId: "\(id)"
                    )
                }
            }
        } catch {
            print("[LyricsSearch] 网易云搜索失败: \(error)")
        }
        return []
    }

    // MARK: - QQ音乐搜索
    private func searchQQMusic(keyword: String) async -> [SearchResult] {
        guard let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }

        // 使用新版接口
        let urlStr = "https://c.y.qq.com/soso/fcgi-bin/client_search_cp?w=\(encoded)&format=json&n=20&cr=1&new_json=1"
        guard let url = URL(string: urlStr) else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")
        request.setValue("https://y.qq.com", forHTTPHeaderField: "Referer")

        do {
            let (data, response) = try await session.data(for: request)
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[LyricsSearch] QQ音乐搜索 HTTP \(httpCode), 数据大小: \(data.count)")

            if let json = extractJSON(from: data),
               let dataObj = json["data"] as? [String: Any],
               let songData = dataObj["song"] as? [String: Any],
               let songs = songData["list"] as? [[String: Any]] {
                return songs.compactMap { song in
                    // songmid 可能在不同字段
                    let mid = (song["songmid"] as? String) ?? (song["mid"] as? String) ?? ""
                    guard !mid.isEmpty else { return nil }
                    let name = (song["songname"] as? String) ?? (song["name"] as? String) ?? "未知"
                    let singerName: String
                    if let singers = song["singer"] as? [[String: Any]] {
                        singerName = singers.compactMap { $0["name"] as? String }.joined(separator: "/")
                    } else {
                        singerName = "未知"
                    }
                    let album = (song["albumname"] as? String) ?? (song["album"] as? [String: Any])?["name"] as? String
                    return SearchResult(
                        id: "qq_\(mid)",
                        title: name,
                        artist: singerName,
                        album: album,
                        source: .qqMusic,
                        sourceId: mid
                    )
                }
            } else {
                // 打印响应便于调试
                if let text = String(data: data, encoding: .utf8) {
                    print("[LyricsSearch] QQ音乐搜索响应: \(String(text.prefix(500)))")
                }
            }
        } catch {
            print("[LyricsSearch] QQ音乐搜索失败: \(error)")
        }
        return []
    }

    // MARK: - 酷狗搜索
    private func searchKugou(keyword: String) async -> [SearchResult] {
        guard let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://mobilecdn.kugou.com/api/v3/search/song?keyword=\(encoded)&page=1&pagesize=20") else {
            return []
        }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[LyricsSearch] 酷狗搜索 HTTP \(httpCode), 数据大小: \(data.count)")

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataObj = json["data"] as? [String: Any],
               let songs = dataObj["info"] as? [[String: Any]] {
                return songs.compactMap { song in
                    guard let hash = song["hash"] as? String,
                          let songname = song["songname"] as? String else { return nil }
                    // 酷狗的歌名格式常为 "歌手 - 歌名" 或 "歌手、歌手 - 歌名"
                    let parts = songname.components(separatedBy: " - ")
                    let artist: String
                    let title: String
                    if parts.count > 1 {
                        artist = parts[0].trimmingCharacters(in: .whitespaces)
                            .replacingOccurrences(of: "<em>", with: "")
                            .replacingOccurrences(of: "</em>", with: "")
                        title = parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
                            .replacingOccurrences(of: "<em>", with: "")
                            .replacingOccurrences(of: "</em>", with: "")
                    } else {
                        artist = (song["singername"] as? String) ?? "未知"
                        title = songname
                            .replacingOccurrences(of: "<em>", with: "")
                            .replacingOccurrences(of: "</em>", with: "")
                    }
                    let album = song["album_name"] as? String
                    return SearchResult(
                        id: "kugou_\(hash)",
                        title: title,
                        artist: artist,
                        album: album,
                        source: .kugou,
                        sourceId: hash
                    )
                }
            }
        } catch {
            print("[LyricsSearch] 酷狗搜索失败: \(error)")
        }
        return []
    }

    // MARK: - 获取网易云歌词
    private func fetchNeteaseLyrics(id: String) async -> [LyricLine]? {
        guard let url = URL(string: "https://music.163.com/api/song/lyric?id=\(id)&lv=1&tv=1") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")

        do {
            let (data, response) = try await session.data(for: request)
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[LyricsSearch] 网易云歌词 HTTP \(httpCode), 数据大小: \(data.count)")

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // 检查是否有歌词
                if let lrc = json["lrc"] as? [String: Any],
                   let lyricText = lrc["lyric"] as? String,
                   !lyricText.isEmpty {
                    var lines = LRCParser.parse(lyricText)

                    if lines.isEmpty {
                        print("[LyricsSearch] 网易云LRC解析结果为空，原文: \(String(lyricText.prefix(200)))")
                        return nil
                    }

                    // 尝试获取翻译
                    if let tlyric = json["tlyric"] as? [String: Any],
                       let transText = tlyric["lyric"] as? String, !transText.isEmpty {
                        let transLines = LRCParser.parse(transText)
                        for transLine in transLines {
                            if let idx = lines.firstIndex(where: { abs($0.time - transLine.time) < 0.5 }) {
                                lines[idx].translation = transLine.text
                            }
                        }
                    }
                    return lines
                } else {
                    print("[LyricsSearch] 网易云无歌词数据: \(String(data: data, encoding: .utf8)?.prefix(300) ?? "nil")")
                }
            }
        } catch {
            print("[LyricsSearch] 网易云歌词获取失败: \(error)")
        }
        return nil
    }

    // MARK: - 获取QQ音乐歌词
    private func fetchQQLyrics(id: String) async -> [LyricLine]? {
        // 方法1：新版接口
        let urlStr = "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=\(id)&format=json&nobase64=1"
        guard let url = URL(string: urlStr) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")
        request.setValue("https://y.qq.com", forHTTPHeaderField: "Referer")

        do {
            let (data, response) = try await session.data(for: request)
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[LyricsSearch] QQ歌词 HTTP \(httpCode), 数据大小: \(data.count)")

            // QQ音乐可能返回JSONP格式
            if let json = extractJSON(from: data) {
                var lyricText: String?

                // 尝试直接获取（nobase64=1时）
                if let lrc = json["lyric"] as? String, !lrc.isEmpty {
                    // 检查是否是base64编码
                    if lrc.contains("[") {
                        lyricText = lrc  // 已经是LRC格式
                    } else if let decoded = Data(base64Encoded: lrc),
                              let decodedStr = String(data: decoded, encoding: .utf8) {
                        lyricText = decodedStr  // base64解码
                    } else {
                        lyricText = lrc  // 尝试直接使用
                    }
                }

                if let lyricText = lyricText, !lyricText.isEmpty {
                    var lines = LRCParser.parse(lyricText)

                    if lines.isEmpty {
                        print("[LyricsSearch] QQ音乐LRC解析为空，原文: \(String(lyricText.prefix(200)))")
                        return nil
                    }

                    // 尝试翻译
                    if let transRaw = json["trans"] as? String, !transRaw.isEmpty {
                        let transText: String
                        if transRaw.contains("[") {
                            transText = transRaw
                        } else if let decoded = Data(base64Encoded: transRaw),
                                  let decodedStr = String(data: decoded, encoding: .utf8) {
                            transText = decodedStr
                        } else {
                            transText = transRaw
                        }
                        let transLines = LRCParser.parse(transText)
                        for transLine in transLines {
                            if let idx = lines.firstIndex(where: { abs($0.time - transLine.time) < 0.5 }) {
                                lines[idx].translation = transLine.text
                            }
                        }
                    }
                    return lines
                } else {
                    print("[LyricsSearch] QQ音乐无歌词字段，keys: \(json.keys.sorted())")
                }
            } else {
                if let text = String(data: data, encoding: .utf8) {
                    print("[LyricsSearch] QQ歌词响应无法解析: \(String(text.prefix(300)))")
                }
            }
        } catch {
            print("[LyricsSearch] QQ音乐歌词获取失败: \(error)")
        }

        // 方法2：备用旧版接口
        print("[LyricsSearch] 尝试QQ音乐备用接口...")
        return await fetchQQLyricsBackup(id: id)
    }

    private func fetchQQLyricsBackup(id: String) async -> [LyricLine]? {
        let urlStr = "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric.fcg?songmid=\(id)&format=json"
        guard let url = URL(string: urlStr) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")
        request.setValue("https://y.qq.com", forHTTPHeaderField: "Referer")

        do {
            let (data, _) = try await session.data(for: request)
            if let json = extractJSON(from: data),
               let lrcBase64 = json["lyric"] as? String,
               let decoded = Data(base64Encoded: lrcBase64),
               let lrcText = String(data: decoded, encoding: .utf8) {
                let lines = LRCParser.parse(lrcText)
                if !lines.isEmpty { return lines }
            }
        } catch {
            print("[LyricsSearch] QQ备用接口失败: \(error)")
        }
        return nil
    }

    // MARK: - 获取酷狗歌词
    private func fetchKugouLyrics(id: String) async -> [LyricLine]? {
        // 酷狗需要两步：先获取歌词ID，再获取歌词内容
        guard let url = URL(string: "https://krcs.kugou.com/search?ver=1&man=yes&client=mobi&keyword=&duration=&hash=\(id)") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[LyricsSearch] 酷狗歌词搜索 HTTP \(httpCode), 数据大小: \(data.count)")

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let first = candidates.first {
                // id 可能是 Int 或 String
                let lrcId: String
                if let idStr = first["id"] as? String {
                    lrcId = idStr
                } else if let idInt = first["id"] as? Int {
                    lrcId = "\(idInt)"
                } else if let idInt64 = first["id"] as? Int64 {
                    lrcId = "\(idInt64)"
                } else {
                    print("[LyricsSearch] 酷狗歌词id类型无法识别: \(type(of: first["id"] as Any))")
                    return nil
                }

                let accesskey: String
                if let key = first["accesskey"] as? String {
                    accesskey = key
                } else {
                    print("[LyricsSearch] 酷狗歌词缺少accesskey")
                    return nil
                }

                print("[LyricsSearch] 酷狗歌词ID: \(lrcId), accesskey: \(accesskey)")
                return await fetchKugouLyricsContent(lrcId: lrcId, accesskey: accesskey)
            } else {
                if let text = String(data: data, encoding: .utf8) {
                    print("[LyricsSearch] 酷狗歌词搜索响应: \(String(text.prefix(300)))")
                }
            }
        } catch {
            print("[LyricsSearch] 酷狗歌词搜索失败: \(error)")
        }
        return nil
    }

    private func fetchKugouLyricsContent(lrcId: String, accesskey: String) async -> [LyricLine]? {
        guard let url = URL(string: "https://lyrics.kugou.com/download?ver=1&client=pc&id=\(lrcId)&accesskey=\(accesskey)&fmt=lrc&charset=utf8") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[LyricsSearch] 酷狗歌词下载 HTTP \(httpCode), 数据大小: \(data.count)")

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let status = json["status"] as? Int ?? -1
                print("[LyricsSearch] 酷狗歌词状态: \(status)")

                if let content = json["content"] as? String, !content.isEmpty {
                    // content 是 base64 编码的 LRC
                    if let decoded = Data(base64Encoded: content),
                       let lrcText = String(data: decoded, encoding: .utf8) {
                        let lines = LRCParser.parse(lrcText)
                        print("[LyricsSearch] 酷狗歌词解析: \(lines.count) 行")
                        return lines.isEmpty ? nil : lines
                    } else {
                        print("[LyricsSearch] 酷狗base64解码失败")
                        // 尝试直接当LRC解析
                        let lines = LRCParser.parse(content)
                        return lines.isEmpty ? nil : lines
                    }
                } else {
                    print("[LyricsSearch] 酷狗歌词content为空，keys: \(json.keys.sorted())")
                }
            }
        } catch {
            print("[LyricsSearch] 酷狗歌词下载失败: \(error)")
        }
        return nil
    }
}
