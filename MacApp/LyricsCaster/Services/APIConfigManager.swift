// APIConfigManager.swift
// Mac端 - API配置管理 + 健康检测 + 推送给iOS
// 启动时从GitHub拉取最新配置，检测各API是否可用，一键推送给已连接的手机

import Foundation
import SwiftUI

class APIConfigManager: ObservableObject {
    // 配置文件远程URL（多个备选，国内优先用 jsDelivr CDN）
    private let remoteURLs = [
        "https://cdn.jsdelivr.net/gh/andrea23shannon-ship-it/manjoy@main/api_config.json",
        "https://raw.githubusercontent.com/andrea23shannon-ship-it/manjoy/main/api_config.json",
        "https://fastly.jsdelivr.net/gh/andrea23shannon-ship-it/manjoy@main/api_config.json"
    ]
    private let cacheKey = "api_config_cache"

    @Published var configVersion: Int = 0
    @Published var lastUpdated: String = ""
    @Published var isLoading = false
    @Published var isPushing = false

    // 各API健康状态
    @Published var qqMusicSearchOK: Bool? = nil   // nil=未检测, true=正常, false=异常
    @Published var qqMusicLyricsOK: Bool? = nil
    @Published var neteaseSearchOK: Bool? = nil
    @Published var neteaseLyricsOK: Bool? = nil
    @Published var kugouSearchOK: Bool? = nil
    @Published var kugouLyricsOK: Bool? = nil
    @Published var isChecking = false
    @Published var lastCheckTime: Date? = nil

    // 当前生效的配置
    private(set) var config: [String: Any] = [:]
    @Published private(set) var configJSON: String = ""

    // MultipeerServer 引用（用于推送）
    weak var server: MultipeerServer?

    private lazy var session: URLSession = {
        let c = URLSessionConfiguration.default
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.timeoutIntervalForRequest = 15
        c.timeoutIntervalForResource = 30
        return URLSession(configuration: c)
    }()

    init() {
        loadCachedConfig()
    }

    // MARK: - 从缓存加载
    private func loadCachedConfig() {
        if let cached = UserDefaults.standard.string(forKey: cacheKey),
           let data = cached.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            self.config = json
            self.configJSON = cached
            self.configVersion = json["version"] as? Int ?? 0
            self.lastUpdated = json["lastUpdated"] as? String ?? ""
            print("[APIConfig-Mac] 从缓存加载配置 v\(configVersion)")
        }
    }

    // MARK: - 从远程拉取（多URL回退）
    func fetchRemoteConfig() async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        for urlStr in remoteURLs {
            guard let url = URL(string: urlStr) else { continue }
            print("[APIConfig-Mac] 尝试拉取: \(urlStr)")

            do {
                let (data, response) = try await session.data(from: url)
                let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0

                guard httpCode == 200,
                      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let jsonStr = String(data: data, encoding: .utf8) else {
                    print("[APIConfig-Mac] HTTP \(httpCode)，尝试下一个URL...")
                    continue
                }

                let remoteVersion = json["version"] as? Int ?? 0
                self.config = json
                self.configJSON = jsonStr

                await MainActor.run {
                    self.configVersion = remoteVersion
                    self.lastUpdated = json["lastUpdated"] as? String ?? ""
                }

                // 缓存
                UserDefaults.standard.set(jsonStr, forKey: cacheKey)
                print("[APIConfig-Mac] 远程配置已更新 v\(remoteVersion) (来源: \(urlStr))")
                return  // 成功，不需要尝试下一个URL
            } catch {
                print("[APIConfig-Mac] \(urlStr) 失败: \(error.localizedDescription)，尝试下一个...")
                continue
            }
        }
        print("[APIConfig-Mac] 所有远程URL均失败，使用本地缓存")
    }

    // MARK: - 健康检测
    func checkAllAPIs() async {
        await MainActor.run {
            isChecking = true
            qqMusicSearchOK = nil
            qqMusicLyricsOK = nil
            neteaseSearchOK = nil
            neteaseLyricsOK = nil
            kugouSearchOK = nil
            kugouLyricsOK = nil
        }

        // 并行检测所有API
        async let qq1 = checkQQMusicSearch()
        async let qq2 = checkQQMusicLyrics()
        async let ne1 = checkNeteaseSearch()
        async let ne2 = checkNeteaseLyrics()
        async let kg1 = checkKugouSearch()
        async let kg2 = checkKugouLyrics()

        let results = await (qq1, qq2, ne1, ne2, kg1, kg2)

        await MainActor.run {
            qqMusicSearchOK = results.0
            qqMusicLyricsOK = results.1
            neteaseSearchOK = results.2
            neteaseLyricsOK = results.3
            kugouSearchOK = results.4
            kugouLyricsOK = results.5
            isChecking = false
            lastCheckTime = Date()
        }

        print("[APIConfig-Mac] 健康检测完成: QQ搜索=\(results.0) QQ歌词=\(results.1) 网易搜索=\(results.2) 网易歌词=\(results.3) 酷狗搜索=\(results.4) 酷狗歌词=\(results.5)")
    }

    // MARK: - 推送配置到手机
    func pushConfigToPhone() {
        guard !configJSON.isEmpty else {
            print("[APIConfig-Mac] 无配置可推送")
            return
        }
        guard let server = server, !server.connectedPeers.isEmpty else {
            print("[APIConfig-Mac] 无已连接设备，无法推送")
            return
        }

        isPushing = true
        let message = PeerMessage.apiConfigUpdate(configJSON: configJSON, version: configVersion)
        if let data = try? JSONEncoder().encode(message) {
            server.sendToAllPeers(data)
            print("[APIConfig-Mac] 已推送配置 v\(configVersion) 到 \(server.connectedPeers.count) 台设备")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isPushing = false
        }
    }

    // MARK: - 单项检测方法
    private func checkQQMusicSearch() async -> Bool {
        let urlStr = "https://u.y.qq.com/cgi-bin/musicu.fcg"
        guard let url = URL(string: urlStr) else {
            print("[APICheck] QQ搜索URL无效")
            return false
        }

        let body: [String: Any] = [
            "req_0": [
                "module": "music.search.SearchCgiService",
                "method": "DoSearchForQQMusicDesktop",
                "param": [
                    "query": "周杰伦",
                    "page_num": 1,
                    "num_per_page": 1,
                    "search_type": 0,
                    "remoteplace": "txt.mac.search",
                    "searchid": ""
                ] as [String: Any]
            ] as [String: Any],
            "comm": [
                "uin": 0,
                "format": "json",
                "ct": 19,
                "cv": 1859
            ] as [String: Any]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://y.qq.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, resp) = try await session.data(for: request)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            print("[APICheck] QQ搜索 HTTP \(code), \(data.count) bytes")
            guard code == 200 else { return false }
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let req0 = json["req_0"] as? [String: Any] {
                let reqCode = req0["code"] as? Int ?? -1
                print("[APICheck] QQ搜索 req_0.code=\(reqCode)")
                if let d = req0["data"] as? [String: Any] {
                    // 尝试路径1: data.body.song.list
                    if let bodyObj = d["body"] as? [String: Any],
                       let song = bodyObj["song"] as? [String: Any],
                       let list = song["list"] as? [[String: Any]] {
                        print("[APICheck] QQ搜索找到 \(list.count) 首歌")
                        return !list.isEmpty
                    }
                    // 尝试路径2: data.song.list（旧版响应格式）
                    if let song = d["song"] as? [String: Any],
                       let list = song["list"] as? [[String: Any]] {
                        print("[APICheck] QQ搜索(旧路径)找到 \(list.count) 首歌")
                        return !list.isEmpty
                    }
                    print("[APICheck] QQ搜索 data keys: \(d.keys.sorted())")
                }
            }
            if let text = String(data: data, encoding: .utf8) {
                print("[APICheck] QQ搜索响应: \(String(text.prefix(500)))")
            }
        } catch {
            print("[APICheck] QQ搜索失败: \(error.localizedDescription)")
        }
        return false
    }

    private func checkQQMusicLyrics() async -> Bool {
        // 用一个已知的歌曲mid测试: 周杰伦-晴天 003OUlho2HcRHC
        let urlStr = "https://u.y.qq.com/cgi-bin/musicu.fcg"
        guard let url = URL(string: urlStr) else { return false }

        let body: [String: Any] = [
            "req_0": [
                "module": "music.musichallSong.PlayLyricInfo",
                "method": "GetPlayLyricInfo",
                "param": ["songMID": "003OUlho2HcRHC", "songID": 0] as [String: Any]
            ] as [String: Any],
            "comm": ["uin": 0, "format": "json", "ct": 24, "cv": 0] as [String: Any]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://y.qq.com", forHTTPHeaderField: "Referer")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, resp) = try await session.data(for: request)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            print("[APICheck] QQ歌词 HTTP \(code), \(data.count) bytes")
            guard code == 200 else { return false }
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let req0 = json["req_0"] as? [String: Any],
               let d = req0["data"] as? [String: Any],
               let lyric = d["lyric"] as? String {
                return !lyric.isEmpty
            } else {
                if let text = String(data: data, encoding: .utf8) {
                    print("[APICheck] QQ歌词响应: \(String(text.prefix(300)))")
                }
            }
        } catch {
            print("[APICheck] QQ歌词失败: \(error.localizedDescription)")
        }
        return false
    }

    private func checkNeteaseSearch() async -> Bool {
        var neteaseComponents = URLComponents(string: "https://music.163.com/api/search/get/web")
        neteaseComponents?.queryItems = [
            URLQueryItem(name: "s", value: "周杰伦"),
            URLQueryItem(name: "type", value: "1"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = neteaseComponents?.url else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")

        do {
            let (data, resp) = try await session.data(for: request)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            print("[APICheck] 网易搜索 HTTP \(code), \(data.count) bytes")
            guard code == 200 else { return false }
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["result"] as? [String: Any],
               let songs = result["songs"] as? [[String: Any]] {
                return !songs.isEmpty
            } else {
                if let text = String(data: data, encoding: .utf8) {
                    print("[APICheck] 网易搜索响应: \(String(text.prefix(300)))")
                }
            }
        } catch {
            print("[APICheck] 网易搜索失败: \(error.localizedDescription)")
        }
        return false
    }

    private func checkNeteaseLyrics() async -> Bool {
        // 周杰伦-晴天 id=186016
        guard let url = URL(string: "https://music.163.com/api/song/lyric?id=186016&lv=1&tv=1") else { return false }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")

        do {
            let (data, resp) = try await session.data(for: request)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            print("[APICheck] 网易歌词 HTTP \(code), \(data.count) bytes")
            guard code == 200 else { return false }
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let lrc = json["lrc"] as? [String: Any],
               let lyric = lrc["lyric"] as? String {
                return !lyric.isEmpty
            } else {
                if let text = String(data: data, encoding: .utf8) {
                    print("[APICheck] 网易歌词响应: \(String(text.prefix(300)))")
                }
            }
        } catch {
            print("[APICheck] 网易歌词失败: \(error.localizedDescription)")
        }
        return false
    }

    private func checkKugouSearch() async -> Bool {
        // 使用URLComponents确保中文正确编码
        var components = URLComponents(string: "https://mobilecdn.kugou.com/api/v3/search/song")
        components?.queryItems = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "keyword", value: "周杰伦"),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "pagesize", value: "1")
        ]
        guard let url = components?.url else {
            print("[APICheck] 酷狗搜索URL构建失败")
            return false
        }
        print("[APICheck] 酷狗搜索URL: \(url.absoluteString)")
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")

        do {
            let (data, resp) = try await session.data(for: request)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            print("[APICheck] 酷狗搜索 HTTP \(code), \(data.count) bytes")
            guard code == 200 else { return false }
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let status = json["status"] as? Int ?? -1
                let errcode = json["errcode"] as? Int ?? -1
                print("[APICheck] 酷狗搜索 status=\(status), errcode=\(errcode)")
                if let d = json["data"] as? [String: Any],
                   let info = d["info"] as? [[String: Any]] {
                    print("[APICheck] 酷狗搜索找到 \(info.count) 首歌")
                    return !info.isEmpty
                } else {
                    print("[APICheck] 酷狗搜索 data keys: \(json.keys.sorted())")
                }
            }
            if let text = String(data: data, encoding: .utf8) {
                print("[APICheck] 酷狗搜索响应: \(String(text.prefix(500)))")
            }
        } catch {
            print("[APICheck] 酷狗搜索失败: \(error.localizedDescription)")
        }
        return false
    }

    private func checkKugouLyrics() async -> Bool {
        // 方案：先通过搜索获取一个有效hash，再检测歌词接口
        // 先搜索"周杰伦 晴天"获取hash
        var components = URLComponents(string: "https://mobilecdn.kugou.com/api/v3/search/song")
        components?.queryItems = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "keyword", value: "周杰伦 晴天"),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "pagesize", value: "1")
        ]
        guard let searchUrl = components?.url else {
            print("[APICheck] 酷狗歌词-搜索URL构建失败")
            return false
        }

        var searchReq = URLRequest(url: searchUrl)
        searchReq.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")

        do {
            let (searchData, searchResp) = try await session.data(for: searchReq)
            let searchCode = (searchResp as? HTTPURLResponse)?.statusCode ?? 0
            print("[APICheck] 酷狗歌词-搜索 HTTP \(searchCode)")
            guard searchCode == 200 else { return false }

            guard let searchJson = try JSONSerialization.jsonObject(with: searchData) as? [String: Any],
                  let d = searchJson["data"] as? [String: Any],
                  let info = d["info"] as? [[String: Any]],
                  let first = info.first,
                  let hash = first["hash"] as? String else {
                print("[APICheck] 酷狗歌词-搜索无法获取hash")
                if let text = String(data: searchData, encoding: .utf8) {
                    print("[APICheck] 酷狗歌词-搜索响应: \(String(text.prefix(300)))")
                }
                return false
            }

            print("[APICheck] 酷狗歌词-获取到hash: \(hash)")

            // 用hash查询歌词
            guard let lyricsUrl = URL(string: "https://krcs.kugou.com/search?ver=1&man=yes&client=mobi&keyword=&duration=&hash=\(hash)") else {
                return false
            }
            var lyricsReq = URLRequest(url: lyricsUrl)
            lyricsReq.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")

            let (lyricsData, lyricsResp) = try await session.data(for: lyricsReq)
            let lyricsCode = (lyricsResp as? HTTPURLResponse)?.statusCode ?? 0
            print("[APICheck] 酷狗歌词 HTTP \(lyricsCode), \(lyricsData.count) bytes")
            guard lyricsCode == 200 else { return false }

            if let json = try JSONSerialization.jsonObject(with: lyricsData) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]] {
                print("[APICheck] 酷狗歌词找到 \(candidates.count) 个候选")
                return !candidates.isEmpty
            } else {
                if let text = String(data: lyricsData, encoding: .utf8) {
                    print("[APICheck] 酷狗歌词响应: \(String(text.prefix(300)))")
                }
            }
        } catch {
            print("[APICheck] 酷狗歌词失败: \(error.localizedDescription)")
        }
        return false
    }

    private var userAgent: String {
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36"
    }
}
