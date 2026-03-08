// SettingsSheet.swift
// Mac端 - 设置页面
// 包含API接口管理等设置项

import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var apiConfigManager: APIConfigManager
    @EnvironmentObject var server: MultipeerServer

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("设置")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // API 接口管理
                    apiConfigSection

                    // 关于
                    aboutSection
                }
                .padding()
            }
        }
        .frame(width: 560, height: 480)
    }

    // MARK: - API 接口管理
    private var apiConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.teal)
                    .font(.title3)
                Text("API 接口管理")
                    .font(.headline)

                Spacer()

                if apiConfigManager.configVersion > 0 {
                    Text("v\(apiConfigManager.configVersion) · \(apiConfigManager.lastUpdated)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("未加载配置")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Divider()

            // 健康检测结果
            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    apiStatusRow("QQ音乐 搜索", status: apiConfigManager.qqMusicSearchOK)
                    apiStatusRow("QQ音乐 歌词", status: apiConfigManager.qqMusicLyricsOK)
                }
                HStack(spacing: 0) {
                    apiStatusRow("网易云 搜索", status: apiConfigManager.neteaseSearchOK)
                    apiStatusRow("网易云 歌词", status: apiConfigManager.neteaseLyricsOK)
                }
                HStack(spacing: 0) {
                    apiStatusRow("酷狗 搜索", status: apiConfigManager.kugouSearchOK)
                    apiStatusRow("酷狗 歌词", status: apiConfigManager.kugouLyricsOK)
                }
            }

            if let time = apiConfigManager.lastCheckTime {
                Text("最近检测: \(formatCheckTime(time))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // 操作按钮
            HStack(spacing: 12) {
                Button(action: {
                    Task { await apiConfigManager.fetchRemoteConfig() }
                }) {
                    Label("刷新配置", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(apiConfigManager.isLoading)

                Button(action: {
                    Task { await apiConfigManager.checkAllAPIs() }
                }) {
                    if apiConfigManager.isChecking {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 60)
                    } else {
                        Label("检测接口", systemImage: "stethoscope")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(apiConfigManager.isChecking)

                Spacer()

                Button(action: {
                    apiConfigManager.pushConfigToPhone()
                }) {
                    if apiConfigManager.isPushing {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 80)
                    } else {
                        Label("推送到手机", systemImage: "iphone.and.arrow.forward")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .disabled(server.connectedPeers.isEmpty || apiConfigManager.isPushing || apiConfigManager.configJSON.isEmpty)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
    }

    // MARK: - 关于
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                    .font(.title3)
                Text("关于")
                    .font(.headline)
                Spacer()
            }

            Divider()

            HStack {
                Text("LyricsCaster 歌词投屏")
                    .font(.subheadline)
                Spacer()
                Text("v1.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("iOS搜索歌词 → Mac投影显示，支持QQ音乐、网易云、酷狗三大平台")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
    }

    // MARK: - 辅助
    @ViewBuilder
    private func apiStatusRow(_ name: String, status: Bool?) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status == nil ? Color.gray : (status! ? Color.green : Color.red))
                .frame(width: 8, height: 8)
            Text(name)
                .font(.callout)
            Spacer()
            Text(status == nil ? "未检测" : (status! ? "正常" : "异常"))
                .font(.caption)
                .foregroundColor(status == nil ? .secondary : (status! ? .green : .red))
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
    }

    private func formatCheckTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
