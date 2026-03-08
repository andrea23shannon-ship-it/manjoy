// LyricsSearchService.swift
// iOS端 - 在线歌词搜索服务
// 支持网易云、QQ音乐、酷狗三大源
// 所有API的URL/headers/参数均从远程配置动态读取，支持热更新

import Foundation

class LyricsSearchService: ObservableObject {
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var error: String?
    @Published var selectedSource: LyricsSource = .qqMusic  // 默认QQ音乐

    // API配置管理器（远程配置）
    var configManager: APIConfigManager = .shared

    // 自定义 URLSession，忽略缓存
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    // MARK: - 配置读取辅助方法

    /// 从配置获取API的URL，如果配置不存在则使用默认值
    private func apiURL(source: String, endpoint: String, fallback: String) -> String {
        return (configManager.getAPIConfig(source: source, endpoint: endpoint)?["url"] as? String) ?? fallback
    }

    /// 从配置获取headers（自动包含UserAgent）
    private func apiHeaders(source: String, endpoint: String) -> [String: String] {
        var headers: [String: String] = ["User-Agent": configManager.getUserAgent()]
        if let configHeaders = configManager.getAPIConfig(source: source, endpoint: endpoint)?["headers"] as? [String: String] {
            headers.merge(configHeaders) { _, new in new }
        }
        return headers
    }

    /// 从配置获取额外的固定查询参数
    private func apiParams(source: String, endpoint: String) -> [String: String] {
        return (configManager.getAPIConfig(source: source, endpoint: endpoint)?["params"] as? [String: String]) ?? [:]
    }

    /// 从配置获取 QQ 音乐的 comm 参数
    private func qqComm(endpoint: String) -> [String: Any] {
        if let config = configManager.getAPIConfig(source: "qqMusic", endpoint: endpoint),
           let comm = config["comm"] as? [String: Any] {
            return comm
        }
        return ["uin": 0, "format": "json", "ct": 19, "cv": 1859]
    }

    /// 构建带查询参数的URL（使用URLComponents保证中文编码正确）
    private func buildURL(base: String, queryItems: [URLQueryItem]) -> URL? {
        var components = URLComponents(string: base)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        return components?.url
    }

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
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
        if let text = String(data: data, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
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

    // MARK: - 网易云搜索（从远程配置读取URL和参数）
    private func searchNetease(keyword: String) async -> [SearchResult] {
        let baseURL = apiURL(source: "netease", endpoint: "search", fallback: "https://music.163.com/api/search/get/web")
        let extraParams = apiParams(source: "netease", endpoint: "search")

        // 构建查询参数：s=keyword + 配置中的固定参数（type, limit等）
        var queryItems = [URLQueryItem(name: "s", value: keyword)]
        for (key, value) in extraParams {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        // 确保有默认参数
        if extraParams["type"] == nil { queryItems.append(URLQueryItem(name: "type", value: "1")) }
        queryItems.append(URLQueryItem(name: "limit", value: "20"))

        guard let url = buildURL(base: baseURL, queryItems: queryItems) else {
            print("[LyricsSearch] 网易云搜索URL构建失败")
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let headers = apiHeaders(source: "netease", endpoint: "search")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

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
            } else {
                if let text = String(data: data, encoding: .utf8) {
                    print("[LyricsSearch] 网易云搜索响应: \(String(text.prefix(500)))")
                }
            }
        } catch {
            print("[LyricsSearch] 网易云搜索失败: \(error)")
        }
        return []
    }

    // MARK: - QQ音乐搜索（新版 musicu.fcg 接口，支持远程配置）
    private func searchQQMusic(keyword: String) async -> [SearchResult] {
        let searchConfig = configManager.getAPIConfig(source: "qqMusic", endpoint: "search")
        let searchURL = searchConfig?["url"] as? String ?? "https://u.y.qq.com/cgi-bin/musicu.fcg"
        let module = searchConfig?["module"] as? String ?? "music.search.SearchCgiService"
        let apiMethod = searchConfig?["apiMethod"] as? String ?? "DoSearchForQQMusicDesktop"
        let comm = qqComm(endpoint: "search")

        guard let url = URL(string: searchURL) else { return [] }

        let requestBody: [String: Any] = [
            "req_0": [
                "module": module,
                "method": apiMethod,
                "param": [
                    "query": keyword,
                    "page_num": 1,
                    "num_per_page": 20,
                    "search_type": 0,
                    "remoteplace": "txt.mac.search",
                    "searchid": ""
                ] as [String: Any]
            ] as [String: Any],
            "comm": comm
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let headers = apiHeaders(source: "qqMusic", endpoint: "search")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("[LyricsSearch] QQ音乐搜索请求序列化失败: \(error)")
            return []
        }

        do {
            let (data, response) = try await session.data(for: request)
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[LyricsSearch] QQ音乐搜索(新版) HTTP \(httpCode), 数据大小: \(data.count)")

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let req0 = json["req_0"] as? [String: Any] {
                if let dataObj = req0["data"] as? [String: Any] {
                    // 路径1: data.body.song.list
                    if let body = dataObj["body"] as? [String: Any],
                       let songData = body["song"] as? [String: Any],
                       let songs = songData["list"] as? [[String: Any]] {
                        return parseQQSongList(songs)
                    }
                    // 路径2: data.song.list
                    if let songData = dataObj["song"] as? [String: Any],
                       let songs = songData["list"] as? [[String: Any]] {
                        return parseQQSongList(songs)
                    }
                    print("[LyricsSearch] QQ音乐搜索 data keys: \(dataObj.keys.sorted())")
                }
            }
            if let text = String(data: data, encoding: .utf8) {
                print("[LyricsSearch] QQ音乐搜索(新版)响应: \(String(text.prefix(800)))")
            }
        } catch {
            print("[LyricsSearch] QQ音乐搜索(新版)失败: \(error)")
        }

        // 回退到旧版接口
        print("[LyricsSearch] 尝试QQ音乐旧版搜索接口...")
        return await searchQQMusicLegacy(keyword: keyword)
    }

    /// 解析 QQ 音乐歌曲列表（新旧格式兼容）
    private func parseQQSongList(_ songs: [[String: Any]]) -> [SearchResult] {
        return songs.compactMap { song in
            let mid = (song["mid"] as? String) ?? (song["songmid"] as? String) ?? ""
            guard !mid.isEmpty else { return nil }
            let name = (song["name"] as? String) ?? (song["songname"] as? String) ?? "未知"
            let singerName: String
            if let singers = song["singer"] as? [[String: Any]] {
                singerName = singers.compactMap { $0["name"] as? String }.joined(separator: "/")
            } else {
                singerName = "未知"
            }
            let album = (song["album"] as? [String: Any])?["name"] as? String
                ?? (song["albumname"] as? String)
            return SearchResult(
                id: "qq_\(mid)",
                title: name,
                artist: singerName,
                album: album,
                source: .qqMusic,
                sourceId: mid
            )
        }
    }

    // MARK: - QQ音乐搜索（旧版回退）
    private func searchQQMusicLegacy(keyword: String) async -> [SearchResult] {
        let legacyURL = apiURL(source: "qqMusic", endpoint: "searchLegacy", fallback: "https://c.y.qq.com/soso/fcgi-bin/client_search_cp")
        guard let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }

        let urlStr = "\(legacyURL)?w=\(encoded)&format=json&n=20&cr=1&new_json=1"
        guard let url = URL(string: urlStr) else { return [] }

        var request = URLRequest(url: url)
        let headers = apiHeaders(source: "qqMusic", endpoint: "searchLegacy")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, response) = try await session.data(for: request)
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[LyricsSearch] QQ音乐搜索(旧版) HTTP \(httpCode), 数据大小: \(data.count)")

            if let json = extractJSON(from: data),
               let dataObj = json["data"] as? [String: Any],
               let songData = dataObj["song"] as? [String: Any],
               let songs = songData["list"] as? [[String: Any]] {
                return parseQQSongList(songs)
            }
        } catch {
            print("[LyricsSearch] QQ音乐搜索(旧版)失败: \(error)")
        }
        return []
    }

    // MARK: - 酷狗搜索（从远程配置读取URL和参数）
    private func searchKugou(keyword: String) async -> [SearchResult] {
        let baseURL = apiURL(source: "kugou", endpoint: "search", fallback: "https://mobilecdn.kugou.com/api/v3/search/song")
        let extraParams = apiParams(source: "kugou", endpoint: "search")

        // 使用URLComponents保证中文正确编码
        var queryItems = [URLQueryItem(name: "keyword", value: keyword)]
        for (key, value) in extraParams {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        // 确保有默认参数
        if extraParams["format"] == nil { queryItems.append(URLQueryItem(name: "format", value: "json")) }
        queryItems.append(URLQueryItem(name: "page", value: "1"))
        queryItems.append(URLQueryItem(name: "pagesize", value: "20"))

        guard let url = buildURL(base: baseURL, queryItems: queryItems) else {
            print("[LyricsSearch] 酷狗搜索URL构建失败")
            return []
        }

        var request = URLRequest(url: url)
        let headers = apiHeaders(source: "kugou", endpoint: "search")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

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
            } else {
                if let text = String(data: data, encoding: .utf8) {
                    print("[LyricsSearch] 酷狗搜索响应: \(String(text.prefix(500)))")
                }
            }
        } catch {
            print("[LyricsSearch] 酷狗搜索失败: \(error)")
        }
        return []
    }

    // MARK: - 获取网易云歌词（从远程配置读取URL和参数）
    private func fetchNeteaseLyrics(id: String) async -> [LyricLine]? {
        let baseURL = apiURL(source: "netease", endpoint: "lyrics", fallback: "https://music.163.com/api/song/lyric")
        let extraParams = apiParams(source: "netease", endpoint: "lyrics")

        var queryItems = [URLQueryItem(name: "id", value: id)]
        for (key, value) in extraParams {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        // 确保有默认参数
        if extraParams["lv"] == nil { queryItems.append(URLQueryItem(name: "lv", value: "1")) }
        if extraParams["tv"] == nil { queryItems.append(URLQueryItem(name: "tv", value: "1")) }

        guard let url = buildURL(base: baseURL, queryItems: queryItems) else {
            print("[LyricsSearch] 网易云歌词URL构建失败")
            return nil
        }

        var request = URLRequest(url: url)
        let headers = apiHeaders(source: "netease", endpoint: "lyrics")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, response) = try await session.data(for: request)
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[LyricsSearch] 网易云歌词 HTTP \(httpCode), 数据大小: \(data.count)")

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
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

    // MARK: - 获取QQ音乐歌词（新版 musicu.fcg 接口，支持远程配置）
    private func fetchQQLyrics(id: String) async -> [LyricLine]? {
        let lyricsConfig = configManager.getAPIConfig(source: "qqMusic", endpoint: "lyrics")
        let lyricsURL = lyricsConfig?["url"] as? String ?? "https://u.y.qq.com/cgi-bin/musicu.fcg"
        let module = lyricsConfig?["module"] as? String ?? "music.musichallSong.PlayLyricInfo"
        let apiMethod = lyricsConfig?["apiMethod"] as? String ?? "GetPlayLyricInfo"
        let comm = qqComm(endpoint: "lyrics")

        guard let url = URL(string: lyricsURL) else { return nil }

        let requestBody: [String: Any] = [
            "req_0": [
                "module": module,
                "method": apiMethod,
                "param": [
                    "songMID": id,
                    "songID": 0
                ] as [String: Any]
            ] as [String: Any],
            "comm": comm
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let headers = apiHeaders(source: "qqMusic", endpoint: "lyrics")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("[LyricsSearch] QQ歌词请求序列化失败: \(error)")
            return nil
        }

        do {
            let (data, response) = try await session.data(for: request)
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[LyricsSearch] QQ歌词(新版) HTTP \(httpCode), 数据大小: \(data.count)")

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let req0 = json["req_0"] as? [String: Any],
               let dataObj = req0["data"] as? [String: Any] {
                var lyricText: String?

                if let lrc = dataObj["lyric"] as? String, !lrc.isEmpty {
                    if lrc.contains("[") {
                        lyricText = lrc
                    } else if let decoded = Data(base64Encoded: lrc),
                              let decodedStr = String(data: decoded, encoding: .utf8) {
                        lyricText = decodedStr
                    } else {
                        lyricText = lrc
                    }
                }

                if let lyricText = lyricText, !lyricText.isEmpty {
                    var lines = LRCParser.parse(lyricText)

                    if lines.isEmpty {
                        print("[LyricsSearch] QQ音乐(新版)LRC解析为空，原文: \(String(lyricText.prefix(200)))")
                    } else {
                        // 尝试翻译
                        if let transRaw = dataObj["trans"] as? String, !transRaw.isEmpty {
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
                    }
                } else {
                    print("[LyricsSearch] QQ音乐(新版)无歌词字段, keys: \(dataObj.keys.sorted())")
                }
            } else {
                if let text = String(data: data, encoding: .utf8) {
                    print("[LyricsSearch] QQ歌词(新版)响应: \(String(text.prefix(500)))")
                }
            }
        } catch {
            print("[LyricsSearch] QQ歌词(新版)失败: \(error)")
        }

        // 回退到旧版接口
        print("[LyricsSearch] 尝试QQ音乐旧版歌词接口...")
        return await fetchQQLyricsLegacy(id: id)
    }

    // MARK: - QQ音乐歌词（旧版回退，URL也从配置读取）
    private func fetchQQLyricsLegacy(id: String) async -> [LyricLine]? {
        let legacyURL = apiURL(source: "qqMusic", endpoint: "lyricsLegacy", fallback: "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg")
        let urlStr = "\(legacyURL)?songmid=\(id)&format=json&nobase64=1"
        guard let url = URL(string: urlStr) else { return nil }

        var request = URLRequest(url: url)
        let headers = apiHeaders(source: "qqMusic", endpoint: "lyricsLegacy")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, response) = try await session.data(for: request)
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[LyricsSearch] QQ歌词(旧版) HTTP \(httpCode), 数据大小: \(data.count)")

            if let json = extractJSON(from: data) {
                var lyricText: String?

                if let lrc = json["lyric"] as? String, !lrc.isEmpty {
                    if lrc.contains("[") {
                        lyricText = lrc
                    } else if let decoded = Data(base64Encoded: lrc),
                              let decodedStr = String(data: decoded, encoding: .utf8) {
                        lyricText = decodedStr
                    } else {
                        lyricText = lrc
                    }
                }

                if let lyricText = lyricText, !lyricText.isEmpty {
                    var lines = LRCParser.parse(lyricText)

                    if lines.isEmpty {
                        print("[LyricsSearch] QQ音乐(旧版)LRC解析为空")
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
                }
            }
        } catch {
            print("[LyricsSearch] QQ歌词(旧版)失败: \(error)")
        }
        return nil
    }

    // MARK: - 获取酷狗歌词（从远程配置读取URL和参数）
    private func fetchKugouLyrics(id: String) async -> [LyricLine]? {
        // 酷狗需要两步：先获取歌词ID，再获取歌词内容
        let searchURL = apiURL(source: "kugou", endpoint: "lyricsSearch", fallback: "https://krcs.kugou.com/search")
        let searchParams = apiParams(source: "kugou", endpoint: "lyricsSearch")

        var queryItems: [URLQueryItem] = []
        // 加入配置中的固定参数
        for (key, value) in searchParams {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        // 确保有默认参数
        if searchParams["ver"] == nil { queryItems.append(URLQueryItem(name: "ver", value: "1")) }
        if searchParams["man"] == nil { queryItems.append(URLQueryItem(name: "man", value: "yes")) }
        if searchParams["client"] == nil { queryItems.append(URLQueryItem(name: "client", value: "mobi")) }
        // 动态参数
        queryItems.append(URLQueryItem(name: "keyword", value: ""))
        queryItems.append(URLQueryItem(name: "duration", value: ""))
        queryItems.append(URLQueryItem(name: "hash", value: id))

        guard let url = buildURL(base: searchURL, queryItems: queryItems) else {
            print("[LyricsSearch] 酷狗歌词搜索URL构建失败")
            return nil
        }

        var request = URLRequest(url: url)
        let headers = apiHeaders(source: "kugou", endpoint: "lyricsSearch")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

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
        let downloadURL = apiURL(source: "kugou", endpoint: "lyricsDownload", fallback: "https://lyrics.kugou.com/download")
        let downloadParams = apiParams(source: "kugou", endpoint: "lyricsDownload")

        var queryItems: [URLQueryItem] = []
        for (key, value) in downloadParams {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        // 确保有默认参数
        if downloadParams["ver"] == nil { queryItems.append(URLQueryItem(name: "ver", value: "1")) }
        if downloadParams["client"] == nil { queryItems.append(URLQueryItem(name: "client", value: "pc")) }
        if downloadParams["fmt"] == nil { queryItems.append(URLQueryItem(name: "fmt", value: "lrc")) }
        if downloadParams["charset"] == nil { queryItems.append(URLQueryItem(name: "charset", value: "utf8")) }
        // 动态参数
        queryItems.append(URLQueryItem(name: "id", value: lrcId))
        queryItems.append(URLQueryItem(name: "accesskey", value: accesskey))

        guard let url = buildURL(base: downloadURL, queryItems: queryItems) else {
            print("[LyricsSearch] 酷狗歌词下载URL构建失败")
            return nil
        }

        var request = URLRequest(url: url)
        let headers = apiHeaders(source: "kugou", endpoint: "lyricsDownload")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, response) = try await session.data(for: request)
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[LyricsSearch] 酷狗歌词下载 HTTP \(httpCode), 数据大小: \(data.count)")

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let status = json["status"] as? Int ?? -1
                print("[LyricsSearch] 酷狗歌词状态: \(status)")

                if let content = json["content"] as? String, !content.isEmpty {
                    if let decoded = Data(base64Encoded: content),
                       let lrcText = String(data: decoded, encoding: .utf8) {
                        let lines = LRCParser.parse(lrcText)
                        print("[LyricsSearch] 酷狗歌词解析: \(lines.count) 行")
                        return lines.isEmpty ? nil : lines
                    } else {
                        print("[LyricsSearch] 酷狗base64解码失败")
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
