// AppState.swift
// Mac端全局状态

import SwiftUI
import Combine

class AppState: ObservableObject {
    // 连接状态
    @Published var isPhoneConnected = false
    @Published var connectedDeviceName: String = ""

    // 当前歌曲
    @Published var currentSong: SongInfo?
    @Published var lyrics: [LyricLine] = []
    @Published var currentLineIndex: Int = -1
    @Published var currentTime: Double = 0
    @Published var lineProgress: Double = 0  // 行内进度 0~1（手机端实时同步，用于逐字动画）
    @Published var isPlaying: Bool = false {
        didSet {
            if isPlaying != oldValue {
                handlePlayingStateChanged(isPlaying)
            }
        }
    }

    // 歌词样式
    @Published var style: LyricsStyle = LyricsStyle() {
        didSet { saveStyle() }
    }

    // 投影状态
    @Published var isProjecting: Bool = false

    // 待机图片分组
    @Published var standbyGroups: [StandbyImageGroup] = []
    @Published var selectedGroupId: UUID? = nil       // UI上当前选中编辑的组
    @Published var standbyDelay: Double = 10          // 暂停/播完后延迟显示（秒）
    @Published var currentStandbyIndex: Int = 0
    @Published var standbyReady: Bool = false          // 延迟结束，可以显示待机图片
    private var standbyTimer: Timer?
    private var standbyDelayTimer: Timer?
    private var songEndCheckTimer: Timer?              // 歌曲结束检测定时器
    private var lastPlaybackUpdateTime: Date = Date()  // 上次收到播放同步的时间

    // 日志
    @Published var logs: [LogEntry] = []

    /// 当前时间匹配的活跃分组（根据时间范围筛选）
    var activeStandbyGroup: StandbyImageGroup? {
        let now = Date()
        let calendar = Calendar.current
        let nowMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

        // 找到当前时间范围内且启用的组
        for group in standbyGroups where group.enabled && !group.imagePaths.isEmpty {
            let startMin = group.startHour * 60 + group.startMinute
            let endMin = group.endHour * 60 + group.endMinute

            if startMin <= endMin {
                // 正常范围，如 09:00 - 18:00
                if nowMinutes >= startMin && nowMinutes < endMin { return group }
            } else {
                // 跨午夜，如 22:00 - 06:00
                if nowMinutes >= startMin || nowMinutes < endMin { return group }
            }
        }

        // 如果没有匹配时间范围的，检查是否有"全天"组（start == end 视为全天）
        for group in standbyGroups where group.enabled && !group.imagePaths.isEmpty {
            let startMin = group.startHour * 60 + group.startMinute
            let endMin = group.endHour * 60 + group.endMinute
            if startMin == endMin { return group }
        }

        return nil
    }

    /// 当前活跃组的图片路径
    var activeStandbyImagePaths: [String] {
        activeStandbyGroup?.imagePaths ?? []
    }

    /// 是否应该显示待机图片
    var shouldShowStandby: Bool {
        !isPlaying && !activeStandbyImagePaths.isEmpty && standbyReady
    }

    init() {
        loadStyle()
        loadStandbyGroups()
    }

    deinit {
        standbyTimer?.invalidate()
        standbyDelayTimer?.invalidate()
        songEndCheckTimer?.invalidate()
    }

    // MARK: - 样式持久化
    private func saveStyle() {
        if let data = try? JSONEncoder().encode(style) {
            UserDefaults.standard.set(data, forKey: "lyricsStyle")
        }
    }

    private func loadStyle() {
        if let data = UserDefaults.standard.data(forKey: "lyricsStyle"),
           let saved = try? JSONDecoder().decode(LyricsStyle.self, from: data) {
            style = saved
        }
    }

    // MARK: - 待机图片分组管理

    func addStandbyGroup(name: String = "新分组") {
        let group = StandbyImageGroup(name: name)
        standbyGroups.append(group)
        selectedGroupId = group.id
        saveStandbyGroups()
    }

    func removeStandbyGroup(id: UUID) {
        standbyGroups.removeAll { $0.id == id }
        if selectedGroupId == id {
            selectedGroupId = standbyGroups.first?.id
        }
        saveStandbyGroups()
    }

    func addImageToGroup(groupId: UUID, path: String) {
        guard let idx = standbyGroups.firstIndex(where: { $0.id == groupId }) else { return }
        standbyGroups[idx].imagePaths.append(path)
        saveStandbyGroups()
    }

    func removeImageFromGroup(groupId: UUID, imageIndex: Int) {
        guard let idx = standbyGroups.firstIndex(where: { $0.id == groupId }) else { return }
        guard imageIndex >= 0 && imageIndex < standbyGroups[idx].imagePaths.count else { return }
        standbyGroups[idx].imagePaths.remove(at: imageIndex)
        if currentStandbyIndex >= standbyGroups[idx].imagePaths.count {
            currentStandbyIndex = 0
        }
        saveStandbyGroups()
    }

    func updateGroupTimeRange(groupId: UUID, startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        guard let idx = standbyGroups.firstIndex(where: { $0.id == groupId }) else { return }
        standbyGroups[idx].startHour = startHour
        standbyGroups[idx].startMinute = startMinute
        standbyGroups[idx].endHour = endHour
        standbyGroups[idx].endMinute = endMinute
        saveStandbyGroups()
    }

    func updateGroupInterval(groupId: UUID, interval: Double) {
        guard let idx = standbyGroups.firstIndex(where: { $0.id == groupId }) else { return }
        standbyGroups[idx].slideInterval = interval
        saveStandbyGroups()
    }

    func toggleGroupEnabled(groupId: UUID) {
        guard let idx = standbyGroups.firstIndex(where: { $0.id == groupId }) else { return }
        standbyGroups[idx].enabled.toggle()
        saveStandbyGroups()
    }

    func renameGroup(groupId: UUID, name: String) {
        guard let idx = standbyGroups.firstIndex(where: { $0.id == groupId }) else { return }
        standbyGroups[idx].name = name
        saveStandbyGroups()
    }

    private func saveStandbyGroups() {
        if let data = try? JSONEncoder().encode(standbyGroups) {
            UserDefaults.standard.set(data, forKey: "standbyGroups")
        }
        UserDefaults.standard.set(standbyDelay, forKey: "standbyDelay")
    }

    private func loadStandbyGroups() {
        if let data = UserDefaults.standard.data(forKey: "standbyGroups"),
           var groups = try? JSONDecoder().decode([StandbyImageGroup].self, from: data) {
            // 过滤掉不存在的图片
            for i in groups.indices {
                groups[i].imagePaths = groups[i].imagePaths.filter { FileManager.default.fileExists(atPath: $0) }
            }
            standbyGroups = groups
            selectedGroupId = groups.first?.id
        }
        // 只在有保存过值时才覆盖默认值（避免首次启动把10覆盖成0）
        if UserDefaults.standard.object(forKey: "standbyDelay") != nil {
            standbyDelay = UserDefaults.standard.double(forKey: "standbyDelay")
        }
    }

    // MARK: - 播放状态变化处理（由 isPlaying didSet 自动调用）

    private func handlePlayingStateChanged(_ playing: Bool) {
        if playing {
            // 开始播放 → 取消待机，启动歌曲结束检测
            cancelStandbyDelay()
            stopStandbySlideshow()
            startSongEndCheck()
        } else {
            // 停止/暂停 → 触发待机延迟，启动轮播
            stopSongEndCheck()
            triggerStandbyDelay()
            startStandbySlideshow()
        }
    }

    /// 暂停/播完后触发待机延迟计时
    func triggerStandbyDelay() {
        standbyDelayTimer?.invalidate()
        standbyDelayTimer = nil
        if standbyDelay <= 0 {
            standbyReady = true
            addLog("待机图片：立即显示")
            return
        }
        standbyReady = false
        addLog("待机图片：\(Int(standbyDelay))秒后显示")
        standbyDelayTimer = Timer.scheduledTimer(withTimeInterval: standbyDelay, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.standbyReady = true
                self?.addLog("待机图片：延迟结束，开始显示")
            }
        }
    }

    /// 播放恢复时取消延迟
    func cancelStandbyDelay() {
        standbyDelayTimer?.invalidate()
        standbyDelayTimer = nil
        standbyReady = false
    }

    func startStandbySlideshow() {
        stopStandbySlideshow()
        guard let group = activeStandbyGroup, group.imagePaths.count > 1 else { return }
        currentStandbyIndex = 0
        standbyTimer = Timer.scheduledTimer(withTimeInterval: group.slideInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let paths = self.activeStandbyImagePaths
                guard paths.count > 1 else { return }
                self.currentStandbyIndex = (self.currentStandbyIndex + 1) % paths.count
            }
        }
    }

    func stopStandbySlideshow() {
        standbyTimer?.invalidate()
        standbyTimer = nil
    }

    // MARK: - 歌曲结束检测
    // 每2秒检查一次：如果已经在最后一行歌词且超过一定时间，或currentTime >= 歌曲时长，
    // 或者长时间没收到手机同步消息，则判定歌曲已结束，自动切换待机

    private func startSongEndCheck() {
        stopSongEndCheck()
        lastPlaybackUpdateTime = Date()
        songEndCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.checkSongEnd()
            }
        }
    }

    private func stopSongEndCheck() {
        songEndCheckTimer?.invalidate()
        songEndCheckTimer = nil
    }

    private func checkSongEnd() {
        guard isPlaying else { return }

        var songEnded = false

        // 方式1：currentTime >= 歌曲时长（有duration信息时）
        if let duration = currentSong?.duration, duration > 0, currentTime >= duration - 0.5 {
            songEnded = true
            addLog("检测到歌曲播放完毕（时间到达）")
        }

        // 方式2：在最后一行歌词，且已经超过最后一行时间10秒以上
        if !songEnded && !lyrics.isEmpty && currentLineIndex >= lyrics.count - 1 {
            let lastLineTime = lyrics.last?.time ?? 0
            if currentTime > lastLineTime + 10 {
                songEnded = true
                addLog("检测到歌曲播放完毕（超过最后一行歌词10秒）")
            }
        }

        // 方式3：长时间（15秒）没收到手机同步消息，且在最后一行
        if !songEnded && currentLineIndex >= lyrics.count - 1 {
            let timeSinceLastUpdate = Date().timeIntervalSince(lastPlaybackUpdateTime)
            if timeSinceLastUpdate > 15 {
                songEnded = true
                addLog("检测到歌曲可能已结束（\(Int(timeSinceLastUpdate))秒无同步消息）")
            }
        }

        if songEnded {
            isPlaying = false  // 这会触发 didSet → handlePlayingStateChanged
        }
    }

    // MARK: - 日志
    func addLog(_ message: String) {
        let entry = LogEntry(time: Date(), message: message)
        DispatchQueue.main.async {
            self.logs.append(entry)
            if self.logs.count > 200 { self.logs.removeFirst(50) }
        }
    }

    // MARK: - 处理来自手机的消息
    func handleMessage(_ message: PeerMessage) {
        DispatchQueue.main.async {
            switch message.type {
            case .songLoaded:
                do {
                    let payload = try JSONDecoder().decode(SongLoadedPayload.self, from: message.payload)
                    self.currentSong = payload.song
                    self.lyrics = payload.lyrics
                    self.currentLineIndex = -1
                    self.currentTime = 0
                    self.isPlaying = false
                    self.addLog("收到歌曲: \(payload.song.title) - \(payload.song.artist), 共\(payload.lyrics.count)行歌词")
                } catch {
                    self.addLog("[错误] songLoaded 解码失败: \(error.localizedDescription)")
                    print("[AppState] songLoaded 解码失败: \(error)")
                }

            case .playbackSync:
                do {
                    let payload = try JSONDecoder().decode(PlaybackSyncPayload.self, from: message.payload)
                    self.currentTime = payload.currentTime
                    self.isPlaying = payload.isPlaying
                    self.lineProgress = payload.lineProgress
                    self.lastPlaybackUpdateTime = Date()
                } catch {
                    print("[AppState] playbackSync 解码失败: \(error)")
                }

            case .lineChanged:
                do {
                    let payload = try JSONDecoder().decode(LineChangedPayload.self, from: message.payload)
                    self.currentLineIndex = payload.lineIndex
                    self.currentTime = payload.currentTime
                    self.lineProgress = 0  // 换行时重置进度
                    self.lastPlaybackUpdateTime = Date()
                } catch {
                    self.addLog("[错误] lineChanged 解码失败: \(error.localizedDescription)")
                    print("[AppState] lineChanged 解码失败: \(error)")
                }

            case .playbackControl:
                do {
                    let payload = try JSONDecoder().decode(PlaybackControlPayload.self, from: message.payload)
                    switch payload.action {
                    case .play:
                        self.isPlaying = true
                        self.addLog("播放")
                    case .pause:
                        self.isPlaying = false
                        self.addLog("暂停")
                    case .stop:
                        self.isPlaying = false
                        self.currentTime = 0
                        self.currentLineIndex = -1
                        self.addLog("停止")
                    }
                } catch {
                    self.addLog("[错误] playbackControl 解码失败: \(error.localizedDescription)")
                    print("[AppState] playbackControl 解码失败: \(error)")
                }

            case .apiConfigUpdate:
                // API配置更新由 APIConfigManager 处理，AppState 不需要处理
                break
            }
        }
    }

    private func updateCurrentLine() {
        guard !lyrics.isEmpty else { return }
        var newIndex = -1
        for (i, line) in lyrics.enumerated() {
            if currentTime >= line.time {
                newIndex = i
            } else {
                break
            }
        }
        if newIndex != currentLineIndex {
            currentLineIndex = newIndex
        }
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let time: Date
    let message: String

    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: time)
    }
}

// MARK: - 待机图片分组模型
struct StandbyImageGroup: Identifiable, Codable {
    var id = UUID()
    var name: String = "新分组"
    var imagePaths: [String] = []
    var enabled: Bool = true
    var startHour: Int = 0          // 显示开始时间 - 小时
    var startMinute: Int = 0        // 显示开始时间 - 分钟
    var endHour: Int = 0            // 显示结束时间 - 小时（start==end 表示全天）
    var endMinute: Int = 0          // 显示结束时间 - 分钟
    var slideInterval: Double = 5.0 // 本组轮播间隔（秒）

    /// 时间范围的可读字符串
    var timeRangeString: String {
        let startMin = startHour * 60 + startMinute
        let endMin = endHour * 60 + endMinute
        if startMin == endMin { return "全天" }
        return String(format: "%02d:%02d - %02d:%02d", startHour, startMinute, endHour, endMinute)
    }
}
