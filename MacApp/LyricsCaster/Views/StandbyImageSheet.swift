// StandbyImageSheet.swift
// Mac端 - 待机图片管理二级页面
// 分组管理、图片上传、时间段设置、轮播间隔

import SwiftUI
import UniformTypeIdentifiers

struct StandbyImageSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("返回")
                    }
                }
                .buttonStyle(.borderless)

                Spacer()

                Text("待机图片管理")
                    .font(.headline)

                Spacer()

                Button(action: { appState.addStandbyGroup() }) {
                    Label("添加分组", systemImage: "plus.rectangle.on.folder")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)

            Divider()

            // 内容
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // MARK: - 全局设置
                    GroupBox("全局设置") {
                        VStack(alignment: .leading, spacing: 12) {
                            // 暂停延迟
                            HStack(spacing: 6) {
                                Text("暂停延迟:")
                                    .frame(width: 70, alignment: .trailing)
                                Slider(value: Binding(
                                    get: { appState.standbyDelay },
                                    set: {
                                        appState.standbyDelay = $0
                                        UserDefaults.standard.set($0, forKey: "standbyDelay")
                                    }
                                ), in: 0...60, step: 1)
                                Text(appState.standbyDelay == 0 ? "立即" : "\(Int(appState.standbyDelay))秒")
                                    .monospacedDigit()
                                    .frame(width: 40)
                            }

                            Text("歌曲暂停或播放完毕后，等待指定秒数再显示待机图片")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            // 当前活跃组
                            if let group = appState.activeStandbyGroup {
                                HStack(spacing: 6) {
                                    Text("当前活跃:")
                                        .frame(width: 70, alignment: .trailing)
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text(group.name)
                                        .font(.callout.weight(.medium))
                                    Text("(\(group.timeRangeString))")
                                        .font(.caption)
                                        .foregroundColor(.purple)
                                }
                            } else {
                                HStack(spacing: 6) {
                                    Text("当前活跃:")
                                        .frame(width: 70, alignment: .trailing)
                                    Text("无（当前时间无匹配分组）")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // MARK: - 分组列表
                    if appState.standbyGroups.isEmpty {
                        GroupBox("图片分组") {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 30))
                                        .foregroundColor(.secondary.opacity(0.4))
                                    Text("暂无分组")
                                        .font(.callout)
                                        .foregroundColor(.secondary)
                                    Text("点击右上角「添加分组」创建图片组")
                                        .font(.caption)
                                        .foregroundColor(.secondary.opacity(0.6))
                                }
                                .padding(.vertical, 20)
                                Spacer()
                            }
                        }
                    } else {
                        ForEach(appState.standbyGroups) { group in
                            standbyGroupSection(group: group)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 480, idealWidth: 560, minHeight: 500, idealHeight: 700)
    }

    // MARK: - 分组区块
    @ViewBuilder
    private func standbyGroupSection(group: StandbyImageGroup) -> some View {
        let isExpanded = appState.selectedGroupId == group.id
        let isActive = appState.activeStandbyGroup?.id == group.id

        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                // 头部
                HStack(spacing: 8) {
                    // 启用开关
                    Button(action: { appState.toggleGroupEnabled(groupId: group.id) }) {
                        Image(systemName: group.enabled ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(group.enabled ? .green : .secondary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)

                    // 展开箭头
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 14)

                    // 分组名
                    Text(group.name)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)

                    // 图片数量
                    Text("\(group.imagePaths.count)张")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))

                    // 时间范围
                    Text(group.timeRangeString)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.purple.opacity(0.1)))

                    // 活跃标识
                    if isActive {
                        Text("活跃")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.green.opacity(0.15)))
                    }

                    Spacer()

                    // 删除
                    Button(action: { appState.removeStandbyGroup(id: group.id) }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.selectedGroupId = isExpanded ? nil : group.id
                    }
                }

                // 展开详情
                if isExpanded {
                    Divider()

                    // 分组名编辑
                    HStack(spacing: 8) {
                        Text("名称:")
                            .frame(width: 60, alignment: .trailing)
                        TextField("分组名称", text: Binding(
                            get: { group.name },
                            set: { appState.renameGroup(groupId: group.id, name: $0) }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }

                    // 时间段设置
                    HStack(spacing: 8) {
                        Text("时段:")
                            .frame(width: 60, alignment: .trailing)

                        Picker("", selection: Binding(
                            get: { group.startHour },
                            set: { appState.updateGroupTimeRange(groupId: group.id, startHour: $0, startMinute: group.startMinute, endHour: group.endHour, endMinute: group.endMinute) }
                        )) {
                            ForEach(0..<24, id: \.self) { h in
                                Text(String(format: "%02d", h)).tag(h)
                            }
                        }
                        .frame(width: 60)

                        Text(":")

                        Picker("", selection: Binding(
                            get: { group.startMinute },
                            set: { appState.updateGroupTimeRange(groupId: group.id, startHour: group.startHour, startMinute: $0, endHour: group.endHour, endMinute: group.endMinute) }
                        )) {
                            ForEach([0, 15, 30, 45], id: \.self) { m in
                                Text(String(format: "%02d", m)).tag(m)
                            }
                        }
                        .frame(width: 60)

                        Text("至")

                        Picker("", selection: Binding(
                            get: { group.endHour },
                            set: { appState.updateGroupTimeRange(groupId: group.id, startHour: group.startHour, startMinute: group.startMinute, endHour: $0, endMinute: group.endMinute) }
                        )) {
                            ForEach(0..<24, id: \.self) { h in
                                Text(String(format: "%02d", h)).tag(h)
                            }
                        }
                        .frame(width: 60)

                        Text(":")

                        Picker("", selection: Binding(
                            get: { group.endMinute },
                            set: { appState.updateGroupTimeRange(groupId: group.id, startHour: group.startHour, startMinute: group.startMinute, endHour: group.endHour, endMinute: $0) }
                        )) {
                            ForEach([0, 15, 30, 45], id: \.self) { m in
                                Text(String(format: "%02d", m)).tag(m)
                            }
                        }
                        .frame(width: 60)
                    }

                    Text("开始与结束时间相同 = 全天显示")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 68)

                    // 轮播间隔
                    if group.imagePaths.count > 1 {
                        HStack(spacing: 8) {
                            Text("轮播:")
                                .frame(width: 60, alignment: .trailing)
                            Slider(value: Binding(
                                get: { group.slideInterval },
                                set: { appState.updateGroupInterval(groupId: group.id, interval: $0) }
                            ), in: 2...30, step: 1)
                            Text("\(Int(group.slideInterval))秒")
                                .monospacedDigit()
                                .frame(width: 35)
                        }
                    }

                    // 图片网格
                    if group.imagePaths.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 6) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.title2)
                                    .foregroundColor(.secondary.opacity(0.4))
                                Text("暂无图片，点击下方添加")
                                    .font(.caption)
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                            .padding(.vertical, 12)
                            Spacer()
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                            ForEach(Array(group.imagePaths.enumerated()), id: \.offset) { imgIdx, path in
                                ZStack(alignment: .topTrailing) {
                                    if let nsImage = NSImage(contentsOfFile: path) {
                                        Image(nsImage: nsImage)
                                            .resizable()
                                            .aspectRatio(16.0/9.0, contentMode: .fill)
                                            .frame(height: 62)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    } else {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.red.opacity(0.1))
                                            .frame(height: 62)
                                            .overlay(
                                                Image(systemName: "exclamationmark.triangle")
                                                    .foregroundColor(.red)
                                            )
                                    }

                                    Button(action: {
                                        appState.removeImageFromGroup(groupId: group.id, imageIndex: imgIdx)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                            .shadow(radius: 2)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(4)
                                }
                            }
                        }
                    }

                    // 添加图片 + 清空
                    HStack {
                        Button(action: { pickImagesForGroup(groupId: group.id) }) {
                            Label("添加图片", systemImage: "plus.rectangle.on.rectangle")
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        if !group.imagePaths.isEmpty {
                            Button(action: {
                                // 清空该组所有图片
                                for i in stride(from: group.imagePaths.count - 1, through: 0, by: -1) {
                                    appState.removeImageFromGroup(groupId: group.id, imageIndex: i)
                                }
                            }) {
                                Text("清空图片")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } label: {
            EmptyView()
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.green.opacity(0.5) : Color.clear, lineWidth: 2)
        )
    }

    // MARK: - 选择图片
    private func pickImagesForGroup(groupId: UUID) {
        let panel = NSOpenPanel()
        panel.title = "选择待机图片（建议16:9比例）"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff, .bmp]

        if panel.runModal() == .OK {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let standbyDir = appSupport.appendingPathComponent("LyricsCaster/StandbyImages", isDirectory: true)
            try? FileManager.default.createDirectory(at: standbyDir, withIntermediateDirectories: true)

            for url in panel.urls {
                let destName = "\(UUID().uuidString)_\(url.lastPathComponent)"
                let destURL = standbyDir.appendingPathComponent(destName)
                do {
                    try FileManager.default.copyItem(at: url, to: destURL)
                    appState.addImageToGroup(groupId: groupId, path: destURL.path)
                } catch {
                    appState.addImageToGroup(groupId: groupId, path: url.path)
                }
            }
        }
    }
}
