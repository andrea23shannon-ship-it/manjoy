// SongSearchView.swift
// iOS端 - 歌曲搜索页面
// 歌手搜索歌曲，选择后加载歌词

import SwiftUI

struct SongSearchView: View {
    @EnvironmentObject var searchService: LyricsSearchService
    @EnvironmentObject var client: MultipeerClient
    @Binding var selectedSong: SongInfo?
    @Binding var loadedLyrics: [LyricLine]
    @Binding var showLyricsView: Bool

    @State private var keyword = ""
    @State private var isLoadingLyrics = false
    @FocusState private var isSearchFocused: Bool
    @State private var recentSearches: [RecentSearch] = []

    // 最近搜索持久化 key
    private let recentSearchesKey = "RecentSearches"
    private let maxRecentCount = 20

    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            searchBar
                .padding()

            Divider()

            // 搜索结果
            if searchService.isSearching {
                Spacer()
                ProgressView("搜索中...")
                    .padding()
                Spacer()
            } else if let error = searchService.error {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(error)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else if searchService.searchResults.isEmpty {
                // 没有搜索结果时显示最近搜索 + 演示模式
                if !recentSearches.isEmpty {
                    recentSearchList
                } else {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("搜索歌曲名或歌手名")
                            .foregroundColor(.secondary)
                        Text("当前源：\(searchService.selectedSource.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    Spacer()

                    // 演示模式入口
                    demoModeSection
                }
            } else {
                resultsList
            }
        }
        .navigationTitle("搜索歌曲")
        .onAppear { loadRecentSearches() }
    }

    // MARK: - 搜索栏
    private var searchBar: some View {
        VStack(spacing: 10) {
            // 音乐源选择（切换时自动用当前关键词重新搜索）
            Picker("音乐源", selection: $searchService.selectedSource) {
                Text("QQ音乐").tag(LyricsSource.qqMusic)
                Text("网易云").tag(LyricsSource.netease)
                Text("酷狗").tag(LyricsSource.kugou)
            }
            .pickerStyle(.segmented)
            .onChange(of: searchService.selectedSource) { _ in
                if !keyword.trimmingCharacters(in: .whitespaces).isEmpty {
                    performSearch()
                }
            }

            // 搜索输入
            HStack(spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("歌曲名 / 歌手名", text: $keyword)
                        .textFieldStyle(.plain)
                        .focused($isSearchFocused)
                        .onSubmit { performSearch() }
                        .autocorrectionDisabled()

                    if !keyword.isEmpty {
                        Button(action: { keyword = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)

                if !searchService.searchResults.isEmpty || searchService.isSearching || searchService.error != nil {
                    Button("取消") { cancelSearch() }
                        .foregroundColor(.secondary)
                } else {
                    Button("搜索") { performSearch() }
                        .buttonStyle(.borderedProminent)
                        .disabled(keyword.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - 最近搜索
    private var recentSearchList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("最近搜索")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: clearRecentSearches) {
                    Text("清空")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            List {
                ForEach(recentSearches) { item in
                    Button(action: { selectRecentSearch(item) }) {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text("\(item.artist) · \(item.source)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoadingLyrics)
                }
                .onDelete(perform: deleteRecentSearch)
            }
            .listStyle(.plain)
        }
        .overlay {
            if isLoadingLyrics {
                loadingOverlay
            }
        }
    }

    // MARK: - 搜索结果列表
    private var resultsList: some View {
        List {
            ForEach(searchService.searchResults) { result in
                Button(action: { selectSong(result) }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.title)
                                .font(.body.weight(.medium))
                                .foregroundColor(.primary)
                            HStack(spacing: 6) {
                                Text(result.artist)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let album = result.album, !album.isEmpty {
                                    Text("·")
                                        .foregroundColor(.secondary)
                                    Text(album)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }

                        Spacer()

                        // 来源标识
                        Text(result.source.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(sourceColor(result.source).opacity(0.15))
                            .foregroundColor(sourceColor(result.source))
                            .cornerRadius(4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isLoadingLyrics)
            }
        }
        .listStyle(.plain)
        .overlay {
            if isLoadingLyrics {
                loadingOverlay
            }
        }
    }

    private var loadingOverlay: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("加载歌词中...")
                        .font(.callout)
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
    }

    // MARK: - 操作
    private func performSearch() {
        isSearchFocused = false
        Task {
            await searchService.search(keyword: keyword)
        }
    }

    private func cancelSearch() {
        keyword = ""
        isSearchFocused = false
        searchService.searchResults = []
        searchService.error = nil
    }

    private func selectSong(_ result: SearchResult) {
        isLoadingLyrics = true
        Task {
            if let lyrics = await searchService.fetchLyrics(result: result) {
                let song = SongInfo(title: result.title, artist: result.artist, album: result.album, duration: nil)
                DispatchQueue.main.async {
                    self.selectedSong = song
                    self.loadedLyrics = lyrics
                    self.isLoadingLyrics = false
                    // 保存到最近搜索
                    saveToRecentSearches(result: result)
                    // 发送到Mac
                    self.client.sendSongLoaded(song: song, lyrics: lyrics)
                    // 切换到歌词显示
                    self.showLyricsView = true
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoadingLyrics = false
                    self.searchService.error = "歌词加载失败，请尝试其他源"
                }
            }
        }
    }

    private func selectRecentSearch(_ item: RecentSearch) {
        // 从最近搜索直接加载
        let result = SearchResult(
            id: item.sourceId,
            title: item.title,
            artist: item.artist,
            album: item.album,
            source: item.lyricsSource,
            sourceId: item.sourceId
        )
        selectSong(result)
    }

    // MARK: - 最近搜索持久化
    private func loadRecentSearches() {
        if let data = UserDefaults.standard.data(forKey: recentSearchesKey),
           let items = try? JSONDecoder().decode([RecentSearch].self, from: data) {
            recentSearches = items
        }
    }

    private func saveToRecentSearches(result: SearchResult) {
        // 去重
        recentSearches.removeAll { $0.sourceId == result.sourceId && $0.source == result.source.rawValue }
        // 插到最前
        let item = RecentSearch(
            title: result.title,
            artist: result.artist,
            album: result.album,
            source: result.source.rawValue,
            sourceId: result.sourceId
        )
        recentSearches.insert(item, at: 0)
        // 限制数量
        if recentSearches.count > maxRecentCount {
            recentSearches = Array(recentSearches.prefix(maxRecentCount))
        }
        persistRecentSearches()
    }

    private func clearRecentSearches() {
        recentSearches.removeAll()
        persistRecentSearches()
    }

    private func deleteRecentSearch(at offsets: IndexSet) {
        recentSearches.remove(atOffsets: offsets)
        persistRecentSearches()
    }

    private func persistRecentSearches() {
        if let data = try? JSONEncoder().encode(recentSearches) {
            UserDefaults.standard.set(data, forKey: recentSearchesKey)
        }
    }

    private func sourceColor(_ source: LyricsSource) -> Color {
        switch source {
        case .netease: return .red
        case .qqMusic: return .green
        case .kugou: return .blue
        }
    }

    // MARK: - 演示模式
    private var demoModeSection: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.horizontal)

            HStack {
                Image(systemName: "play.rectangle.fill")
                    .foregroundColor(.teal)
                Text("演示模式")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("无需连接电脑即可体验")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 16)

            ForEach(Array(DemoDataProvider.demoSongs.enumerated()), id: \.offset) { index, item in
                Button(action: { selectDemoSong(index: index) }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.teal.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "music.note")
                                .foregroundColor(.teal)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.song.title)
                                .font(.body.weight(.medium))
                                .foregroundColor(.primary)
                            Text(item.song.artist)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("演示")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.teal.opacity(0.15))
                            .foregroundColor(.teal)
                            .cornerRadius(4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer().frame(height: 16)
        }
    }

    private func selectDemoSong(index: Int) {
        let demoItem = DemoDataProvider.demoSongs[index]
        selectedSong = demoItem.song
        loadedLyrics = demoItem.lyrics
        // 不发送到Mac（演示模式，可能未连接）
        if client.isConnected {
            client.sendSongLoaded(song: demoItem.song, lyrics: demoItem.lyrics)
        }
        showLyricsView = true
    }
}

// MARK: - 最近搜索模型
struct RecentSearch: Codable, Identifiable {
    var id: String { "\(source)_\(sourceId)" }
    let title: String
    let artist: String
    let album: String?
    let source: String       // rawValue of LyricsSource
    let sourceId: String

    var lyricsSource: LyricsSource {
        LyricsSource(rawValue: source) ?? .qqMusic
    }
}
