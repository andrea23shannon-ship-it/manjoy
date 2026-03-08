// APIConfigManager.swift
// iOS端 - API配置远程管理
// 从GitHub拉取最新API配置，本地缓存，支持Mac推送更新

import Foundation

class APIConfigManager: ObservableObject {
    static let shared = APIConfigManager()

    // 配置文件远程URL（多个备选，国内优先用 jsDelivr CDN）
    private let remoteURLs = [
        "https://cdn.jsdelivr.net/gh/andrea23shannon-ship-it/manjoy@main/api_config.json",
        "https://raw.githubusercontent.com/andrea23shannon-ship-it/manjoy/main/api_config.json",
        "https://fastly.jsdelivr.net/gh/andrea23shannon-ship-it/manjoy@main/api_config.json"
    ]
    private let cacheKey = "api_config_cache"
    private let versionKey = "api_config_version"

    @Published var configVersion: Int = 0
    @Published var lastUpdated: String = ""
    @Published var isLoading = false

    // 当前生效的配置
    private(set) var config: [String: Any] = [:]

    // 配置变更回调（通知搜索服务刷新）
    var onConfigUpdated: (() -> Void)?

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
            self.configVersion = json["version"] as? Int ?? 0
            self.lastUpdated = json["lastUpdated"] as? String ?? ""
            print("[APIConfig] 从缓存加载配置 v\(configVersion)")
        }
    }

    // MARK: - 从远程拉取最新配置（多URL回退）
    func fetchRemoteConfig() async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        for urlStr in remoteURLs {
            guard let url = URL(string: urlStr) else { continue }
            print("[APIConfig] 尝试拉取: \(urlStr)")

            do {
                let (data, response) = try await session.data(from: url)
                let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                print("[APIConfig] HTTP \(httpCode), \(data.count) bytes")

                guard httpCode == 200 else {
                    print("[APIConfig] HTTP \(httpCode)，尝试下一个URL...")
                    continue
                }

                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let remoteVersion = json["version"] as? Int ?? 0
                    if remoteVersion >= self.configVersion {
                        applyConfig(json: json, source: "远程")
                        if let jsonStr = String(data: data, encoding: .utf8) {
                            UserDefaults.standard.set(jsonStr, forKey: cacheKey)
                        }
                    } else {
                        print("[APIConfig] 远程版本(\(remoteVersion))不高于本地(\(configVersion))，跳过")
                    }
                    return  // 成功
                }
            } catch {
                print("[APIConfig] \(urlStr) 失败: \(error.localizedDescription)，尝试下一个...")
                continue
            }
        }
        print("[APIConfig] 所有远程URL均失败，使用本地缓存")
    }

    // MARK: - 接收 Mac 推送的配置
    func applyPushedConfig(payload: APIConfigPayload) {
        guard let data = payload.configJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[APIConfig] Mac推送的配置JSON解析失败")
            return
        }

        applyConfig(json: json, source: "Mac推送")
        // 缓存到本地
        UserDefaults.standard.set(payload.configJSON, forKey: cacheKey)
    }

    // MARK: - 应用配置
    private func applyConfig(json: [String: Any], source: String) {
        self.config = json
        let version = json["version"] as? Int ?? 0
        let updated = json["lastUpdated"] as? String ?? ""

        DispatchQueue.main.async {
            self.configVersion = version
            self.lastUpdated = updated
        }
        print("[APIConfig] 已应用\(source)配置 v\(version) (\(updated))")

        // 通知依赖方配置已更新
        onConfigUpdated?()
    }

    /// 获取配置中的额外查询参数
    func getAPIParams(source: String, endpoint: String) -> [String: String]? {
        guard let config = getAPIConfig(source: source, endpoint: endpoint),
              let params = config["params"] as? [String: String] else {
            return nil
        }
        return params
    }

    // MARK: - 获取特定API的配置
    func getAPIConfig(source: String, endpoint: String) -> [String: Any]? {
        guard let apis = config["apis"] as? [String: Any],
              let sourceConfig = apis[source] as? [String: Any],
              let endpointConfig = sourceConfig[endpoint] as? [String: Any] else {
            return nil
        }
        return endpointConfig
    }

    /// 获取通用 User-Agent
    func getUserAgent() -> String {
        return (config["userAgent"] as? String)
            ?? "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
    }

    /// 获取完整配置的JSON字符串（用于显示或传输）
    func getConfigJSON() -> String? {
        guard !config.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
