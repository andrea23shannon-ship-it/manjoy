// StyleEditorView.swift
// Mac端 - 歌词样式编辑器
// 控制字体、颜色、背景、动画等所有视觉参数

import SwiftUI

struct StyleEditorView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var fontManager = FontManager.shared
    @State private var showingBGPicker = false
    @State private var pendingTheme: ThemeInfo? = nil  // 待确认的主题
    @State private var fontImportMessage: String? = nil
    @State private var showThemeConfirm = false

    // 动画预览状态
    @State private var previewCurrentLine: Int = 1       // 当前高亮行索引 (0-3)
    @State private var previewTimer: Timer? = nil
    @State private var karaokeProgress: CGFloat = 0      // 卡拉OK逐字进度 0~1
    @State private var karaokeTimer: Timer? = nil
    // 新动画预览状态
    @State private var previewPulseScale: CGFloat = 1.0
    @State private var previewWavePhase: Double = 0
    @State private var previewWaveTimer: Timer? = nil
    @State private var previewTypewriterChars: Int = 0
    @State private var previewTypewriterTimer: Timer? = nil
    @State private var previewCharBounceCount: Int = 0
    @State private var previewCharBounceTimer: Timer? = nil
    @State private var previewCharBounceEntryDone: Bool = false   // 整句渐现是否完成
    @State private var previewCharBounceScale: CGFloat = 1.0      // 整句缩放
    @State private var previewCharBounceOpacity: Double = 1.0     // 整句透明度
    // 随机大小预览状态
    @State private var previewRandomSizeScale: CGFloat = 1.0
    @State private var previewRandomSizeOpacity: Double = 1.0
    @State private var previewRandomSizeBlur: CGFloat = 0
    @State private var previewRandomSizeEntryDone: Bool = true
    @State private var previewRandomSizeExitOpacity: Double = 0   // 上一行退场透明度
    @State private var previewRandomSizeExitOffset: CGFloat = 0   // 上一行退场偏移
    @State private var previewRandomSizeExitActive: Bool = false
    @State private var previewRandomSizePrevLine: Int = -1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // MARK: - 字体设置
                GroupBox("字体设置") {
                    VStack(alignment: .leading, spacing: 12) {
                        // 字体选择
                        HStack {
                            Text("字体:")
                                .frame(width: 60, alignment: .trailing)
                            Picker("", selection: $appState.style.fontName) {
                                // 系统内置字体
                                Section(header: Text("系统字体")) {
                                    Text("苹方").tag("PingFang SC")
                                    Text("华文黑体").tag("STHeiti")
                                    Text("华文宋体").tag("STSong")
                                    Text("华文楷体").tag("STKaiti")
                                    Text("Helvetica Neue").tag("Helvetica Neue")
                                    Text("Avenir Next").tag("Avenir Next")
                                    Text("SF Pro").tag(".AppleSystemUIFont")
                                }
                                // 用户导入的字体
                                if !fontManager.customFonts.isEmpty {
                                    Section(header: Text("导入字体")) {
                                        ForEach(fontManager.customFonts) { font in
                                            Text(font.displayName).tag(font.fontName)
                                        }
                                    }
                                }
                            }
                            .frame(width: 160)
                        }

                        // 导入字体按钮
                        HStack {
                            Text("")
                                .frame(width: 60)
                            Button(action: {
                                fontManager.importFont { success, message in
                                    fontImportMessage = message
                                    // 3秒后清除提示
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        if fontImportMessage == message { fontImportMessage = nil }
                                    }
                                }
                            }) {
                                Label("导入字体...", systemImage: "plus.circle")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)

                            if let msg = fontImportMessage {
                                Text(msg)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .transition(.opacity)
                            }

                            Spacer()

                            // 已导入字体管理
                            if !fontManager.customFonts.isEmpty {
                                Menu {
                                    ForEach(fontManager.customFonts) { font in
                                        Button(role: .destructive) {
                                            // 如果当前正在使用该字体，切回默认
                                            if appState.style.fontName == font.fontName {
                                                appState.style.fontName = "PingFang SC"
                                            }
                                            fontManager.removeFont(font)
                                        } label: {
                                            Label("删除 \(font.displayName)", systemImage: "trash")
                                        }
                                    }
                                } label: {
                                    Image(systemName: "gear")
                                        .font(.caption)
                                }
                                .menuStyle(.borderlessButton)
                                .frame(width: 24)
                            }
                        }

                        // 字号
                        HStack {
                            Text("字号:")
                                .frame(width: 60, alignment: .trailing)
                            Slider(value: $appState.style.fontSize, in: 20...200, step: 2)
                            Text("\(Int(appState.style.fontSize))pt")
                                .frame(width: 50)
                                .monospacedDigit()
                        }

                        // 字重
                        HStack {
                            Text("粗细:")
                                .frame(width: 60, alignment: .trailing)
                            Picker("", selection: $appState.style.fontWeight) {
                                ForEach(LyricsStyle.FontWeight.allCases, id: \.self) { w in
                                    Text(w.rawValue).tag(w)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - 颜色设置
                GroupBox("颜色设置") {
                    VStack(alignment: .leading, spacing: 12) {
                        // 当前行颜色
                        HStack {
                            Text("当前行:")
                                .frame(width: 80, alignment: .trailing)
                            ColorPicker("", selection: currentLineColorBinding)
                                .labelsHidden()
                            Toggle("发光效果", isOn: $appState.style.currentLineGlow)
                        }

                        // 其他行颜色
                        HStack {
                            Text("待唱行:")
                                .frame(width: 80, alignment: .trailing)
                            ColorPicker("", selection: otherLineColorBinding)
                                .labelsHidden()
                        }

                        // 已唱行颜色
                        HStack {
                            Text("已唱行:")
                                .frame(width: 80, alignment: .trailing)
                            ColorPicker("", selection: pastLineColorBinding)
                                .labelsHidden()
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - 背景设置
                GroupBox("背景设置") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("背景色:")
                                .frame(width: 80, alignment: .trailing)
                            ColorPicker("", selection: bgColorBinding)
                                .labelsHidden()
                        }

                        HStack {
                            Text("透明度:")
                                .frame(width: 80, alignment: .trailing)
                            Slider(value: $appState.style.backgroundOpacity, in: 0...1)
                            Text("\(Int(appState.style.backgroundOpacity * 100))%")
                                .frame(width: 40)
                                .monospacedDigit()
                        }

                        // 预设背景
                        HStack {
                            Text("预设:")
                                .frame(width: 80, alignment: .trailing)
                            Button("纯黑") { applyPresetBG(r: 0, g: 0, b: 0) }
                            Button("深蓝") { applyPresetBG(r: 0.05, g: 0.05, b: 0.2) }
                            Button("深紫") { applyPresetBG(r: 0.15, g: 0.05, b: 0.2) }
                            Button("深红") { applyPresetBG(r: 0.2, g: 0.02, b: 0.02) }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - 动画设置
                GroupBox("动画设置") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("动画:")
                                .frame(width: 80, alignment: .trailing)
                            Picker("", selection: $appState.style.animationStyle) {
                                ForEach(LyricsStyle.AnimationStyleType.allCases, id: \.self) { s in
                                    Text(s.rawValue).tag(s)
                                }
                            }
                            .frame(width: 160)
                        }

                        HStack {
                            Text("速度:")
                                .frame(width: 80, alignment: .trailing)
                            Slider(value: $appState.style.animationSpeed, in: 0.1...1.0)
                            Text(appState.style.animationSpeed < 0.4 ? "慢" : appState.style.animationSpeed < 0.7 ? "中" : "快")
                                .frame(width: 30)
                        }

                        // MARK: 动画效果预览
                        animationPreviewBox
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - 布局设置
                GroupBox("布局设置") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("对齐:")
                                .frame(width: 80, alignment: .trailing)
                            Picker("", selection: $appState.style.alignment) {
                                ForEach(LyricsStyle.TextAlignmentType.allCases, id: \.self) { a in
                                    Text(a.rawValue).tag(a)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        HStack {
                            Text("行间距:")
                                .frame(width: 80, alignment: .trailing)
                            Slider(value: $appState.style.lineSpacing, in: 5...50, step: 1)
                            Text("\(Int(appState.style.lineSpacing))")
                                .frame(width: 30)
                                .monospacedDigit()
                        }

                        HStack {
                            Text("可见行:")
                                .frame(width: 80, alignment: .trailing)
                            Stepper("\(appState.style.visibleLineCount) 行", value: $appState.style.visibleLineCount, in: 1...10)
                        }

                        HStack {
                            Text("边距:")
                                .frame(width: 80, alignment: .trailing)
                            Slider(value: $appState.style.padding, in: 10...100, step: 5)
                            Text("\(Int(appState.style.padding))")
                                .frame(width: 30)
                                .monospacedDigit()
                        }

                        Toggle("显示翻译", isOn: $appState.style.showTranslation)
                            .padding(.leading, 84)
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - 一键主题（带预览）
                GroupBox("一键主题") {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ], spacing: 10) {
                        ForEach(Self.allThemes, id: \.name) { theme in
                            themePreviewCard(theme: theme)
                        }
                    }
                    .padding(.vertical, 4)
                }

            }
            .padding()
        }
        .alert("切换主题", isPresented: $showThemeConfirm) {
            Button("使用该主题") {
                if let theme = pendingTheme {
                    applyTheme(theme.style)
                }
                pendingTheme = nil
            }
            Button("取消", role: .cancel) {
                pendingTheme = nil
            }
        } message: {
            if let theme = pendingTheme {
                Text("是否切换为「\(theme.name)」主题？颜色、背景和动画将被更新，字体设置保持不变。")
            }
        }
    }

    // MARK: - 动画效果预览
    private let previewLines = ["窗外的麻雀在电线杆上多嘴", "你说这一句很有夏天的感觉", "手中的铅笔在纸上来来回回", "我用几行字形容你是我的谁"]

    private var animationPreviewBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("效果预览")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            // 预览区域
            ZStack {
                appState.style.backgroundColor.color
                    .opacity(appState.style.backgroundOpacity)

                VStack(spacing: appState.style.lineSpacing * 0.4) {
                    ForEach(0..<previewLines.count, id: \.self) { i in
                        previewLineView(index: i, text: previewLines[i])
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .onAppear { startPreviewTimer() }
        .onDisappear { stopPreviewTimer() }
        .onChange(of: appState.style.animationStyle) { _ in
            // 切换动画类型时重置预览
            karaokeProgress = 0
            restartPreviewTimer()
        }
        .onChange(of: appState.style.animationSpeed) { _ in
            restartPreviewTimer()
        }
    }

    @ViewBuilder
    private func previewLineView(index: Int, text: String) -> some View {
        let isCurrent = index == previewCurrentLine
        let isPast = index < previewCurrentLine
        let style = appState.style
        let fontName = style.fontName
        let weight = style.fontWeight.swiftUI
        let animStyle = style.animationStyle
        let speed = style.animationSpeed
        let duration = 0.6 * (1.1 - speed)  // speed 越大动画越快

        Group {
            switch animStyle {
            case .none:
                // 无动画 - 直接切换颜色
                Text(text)
                    .font(.custom(fontName, size: isCurrent ? 16 : 13))
                    .fontWeight(weight)
                    .foregroundColor(
                        isCurrent ? style.currentLineColor.color :
                        isPast ? style.pastLineColor.color :
                        style.otherLineColor.color
                    )

            case .smooth:
                // 平滑滚动 - 颜色渐变过渡
                Text(text)
                    .font(.custom(fontName, size: isCurrent ? 16 : 13))
                    .fontWeight(weight)
                    .foregroundColor(
                        isCurrent ? style.currentLineColor.color :
                        isPast ? style.pastLineColor.color :
                        style.otherLineColor.color
                    )
                    .animation(.easeInOut(duration: duration), value: previewCurrentLine)

            case .fade:
                // 淡入淡出
                Text(text)
                    .font(.custom(fontName, size: isCurrent ? 16 : 13))
                    .fontWeight(weight)
                    .foregroundColor(
                        isCurrent ? style.currentLineColor.color :
                        isPast ? style.pastLineColor.color :
                        style.otherLineColor.color
                    )
                    .opacity(isCurrent ? 1.0 : isPast ? 0.4 : 0.6)
                    .animation(.easeInOut(duration: duration), value: previewCurrentLine)

            case .scale:
                // 缩放高亮
                Text(text)
                    .font(.custom(fontName, size: isCurrent ? 16 : 13))
                    .fontWeight(weight)
                    .foregroundColor(
                        isCurrent ? style.currentLineColor.color :
                        isPast ? style.pastLineColor.color :
                        style.otherLineColor.color
                    )
                    .scaleEffect(isCurrent ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: duration), value: previewCurrentLine)

            case .karaoke:
                // 卡拉OK逐字 - 当前行用 overlay + mask 模拟逐字填色
                if isCurrent {
                    karaokeLineView(text: text, fontName: fontName, weight: weight)
                } else {
                    Text(text)
                        .font(.custom(fontName, size: 13))
                        .fontWeight(weight)
                        .foregroundColor(
                            isPast ? style.pastLineColor.color :
                            style.otherLineColor.color
                        )
                }

            case .bounce:
                // 弹跳节拍 - 当前行弹跳上移
                Text(text)
                    .font(.custom(fontName, size: isCurrent ? 16 : 13))
                    .fontWeight(weight)
                    .foregroundColor(
                        isCurrent ? style.currentLineColor.color :
                        isPast ? style.pastLineColor.color :
                        style.otherLineColor.color
                    )
                    .offset(y: isCurrent ? -6 : 0)
                    .scaleEffect(isCurrent ? 1.1 : 0.92)
                    .opacity(isCurrent ? 1.0 : isPast ? 0.35 : 0.55)
                    .animation(
                        .spring(response: duration * 0.5, dampingFraction: 0.4, blendDuration: 0.05),
                        value: previewCurrentLine
                    )

            case .wave:
                // 波浪律动 - 行带波浪偏移
                let relIdx = index - previewCurrentLine
                let amp: CGFloat = isCurrent ? 4 : 2
                let yOff = amp * CGFloat(sin(previewWavePhase + Double(relIdx) * 0.8))
                Text(text)
                    .font(.custom(fontName, size: isCurrent ? 16 : 13))
                    .fontWeight(weight)
                    .foregroundColor(
                        isCurrent ? style.currentLineColor.color :
                        isPast ? style.pastLineColor.color :
                        style.otherLineColor.color
                    )
                    .offset(y: yOff)
                    .scaleEffect(isCurrent ? 1.05 : 0.92)
                    .opacity(isCurrent ? 1.0 : isPast ? 0.35 : 0.5)

            case .pulse:
                // 脉冲呼吸 - 当前行持续缩放
                Text(text)
                    .font(.custom(fontName, size: isCurrent ? 16 : 13))
                    .fontWeight(weight)
                    .foregroundColor(
                        isCurrent ? style.currentLineColor.color :
                        isPast ? style.pastLineColor.color :
                        style.otherLineColor.color
                    )
                    .scaleEffect(isCurrent ? previewPulseScale : 0.9)
                    .opacity(isCurrent ? 1.0 : isPast ? 0.35 : 0.5)
                    .animation(.easeInOut(duration: duration * 0.5), value: previewCurrentLine)

            case .typewriter:
                // 打字机 - 当前行逐字显现
                if isCurrent {
                    let visibleText = String(text.prefix(previewTypewriterChars))
                    let hiddenText = String(text.dropFirst(previewTypewriterChars))
                    HStack(spacing: 0) {
                        Text(visibleText)
                            .font(.custom(fontName, size: 16))
                            .fontWeight(weight)
                            .foregroundColor(style.currentLineColor.color)
                        Text(hiddenText)
                            .font(.custom(fontName, size: 16))
                            .fontWeight(weight)
                            .foregroundColor(.clear)
                    }
                } else {
                    Text(text)
                        .font(.custom(fontName, size: 13))
                        .fontWeight(weight)
                        .foregroundColor(
                            isPast ? style.pastLineColor.color :
                            style.otherLineColor.color
                        )
                        .opacity(isPast ? 0.35 : 0.5)
                }

            case .slideIn:
                // 滑入聚焦 - 当前行居中，其他行偏移
                Text(text)
                    .font(.custom(fontName, size: isCurrent ? 16 : 13))
                    .fontWeight(weight)
                    .foregroundColor(
                        isCurrent ? style.currentLineColor.color :
                        isPast ? style.pastLineColor.color :
                        style.otherLineColor.color
                    )
                    .offset(x: isCurrent ? 0 : (isPast ? -30 : 30))
                    .opacity(isCurrent ? 1.0 : isPast ? 0.2 : 0.4)
                    .scaleEffect(isCurrent ? 1.05 : 0.88)
                    .animation(
                        .spring(response: duration * 0.6, dampingFraction: 0.65),
                        value: previewCurrentLine
                    )

            case .charBounce:
                // 逐字弹入 - 两阶段：整句渐现 → 逐字弹入
                if isCurrent {
                    let chars = Array(text)
                    let mid = chars.count / 2
                    let part1 = Array(chars[0..<mid])
                    let part2 = Array(chars[mid..<chars.count])

                    ZStack {
                        // 阶段1：整句由小变大渐现
                        if !previewCharBounceEntryDone {
                            VStack(spacing: 3) {
                                Text(String(part1)).font(.custom(fontName, size: 15)).fontWeight(weight)
                                    .foregroundColor(style.currentLineColor.color)
                                    .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1.5)
                                    .offset(x: -8)
                                Text(String(part2)).font(.custom(fontName, size: 15)).fontWeight(weight)
                                    .foregroundColor(style.currentLineColor.color)
                                    .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1.5)
                                    .offset(x: 10)
                            }
                            .scaleEffect(previewCharBounceScale)
                            .opacity(previewCharBounceOpacity)
                            .animation(.easeOut(duration: 0.35), value: previewCharBounceScale)
                            .animation(.easeOut(duration: 0.35), value: previewCharBounceOpacity)
                        }

                        // 阶段2：逐字弹入
                        if previewCharBounceEntryDone {
                            VStack(spacing: 3) {
                                HStack(spacing: 0.3) {
                                    ForEach(0..<part1.count, id: \.self) { ci in
                                        let vis = ci < previewCharBounceCount
                                        let popping = ci == previewCharBounceCount - 1
                                        let yJitter = CGFloat(sin(Double(ci) * 1.7 + 0.5)) * 2
                                        Text(String(part1[ci]))
                                            .font(.custom(fontName, size: 15))
                                            .fontWeight(weight)
                                            .foregroundColor(style.currentLineColor.color)
                                            .shadow(color: .black.opacity(0.7), radius: 1, x: 1, y: 1.5)
                                            .shadow(color: .black.opacity(0.3), radius: 3, x: 1.5, y: 2.5)
                                            .scaleEffect(vis ? (popping ? 2.0 : 1.0) : 0.01)
                                            .opacity(vis ? 1.0 : 0)
                                            .offset(y: popping ? -4 + yJitter : (vis ? yJitter : 6))
                                            .animation(.spring(response: 0.22, dampingFraction: 0.42), value: previewCharBounceCount)
                                    }
                                }
                                .offset(x: -8)
                                HStack(spacing: 0.3) {
                                    ForEach(0..<part2.count, id: \.self) { ci in
                                        let globalCI = ci + mid
                                        let vis = globalCI < previewCharBounceCount
                                        let popping = globalCI == previewCharBounceCount - 1
                                        let yJitter = CGFloat(sin(Double(globalCI) * 1.7 + 0.5)) * 2
                                        Text(String(part2[ci]))
                                            .font(.custom(fontName, size: 15))
                                            .fontWeight(weight)
                                            .foregroundColor(style.currentLineColor.color)
                                            .shadow(color: .black.opacity(0.7), radius: 1, x: 1, y: 1.5)
                                            .shadow(color: .black.opacity(0.3), radius: 3, x: 1.5, y: 2.5)
                                            .scaleEffect(vis ? (popping ? 2.0 : 1.0) : 0.01)
                                            .opacity(vis ? 1.0 : 0)
                                            .offset(y: popping ? -4 + yJitter : (vis ? yJitter : 6))
                                            .animation(.spring(response: 0.22, dampingFraction: 0.42), value: previewCharBounceCount)
                                    }
                                }
                                .offset(x: 10)
                            }
                        }
                    }
                } else {
                    let seed = Double(index) * 2.7
                    let xOff: CGFloat = CGFloat(sin(seed)) * 25
                    let yDrift: CGFloat = isPast ? CGFloat(cos(seed * 1.3)) * 8 : 0
                    Text(text)
                        .font(.custom(fontName, size: isPast ? 10 : 11))
                        .fontWeight(weight)
                        .foregroundColor(isPast ? style.pastLineColor.color : style.otherLineColor.color)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                        .offset(x: xOff, y: yDrift)
                        .scaleEffect(isPast ? 0.7 : 0.65)
                        .opacity(isPast ? 0.2 : 0.18)
                        .animation(.easeOut(duration: 0.5), value: previewCurrentLine)
                }

            case .scatter:
                // 散落歌词 - 行偏移散布
                let seed = Double(index) * 2.7
                let xOff: CGFloat = isCurrent ? 0 : CGFloat(sin(seed)) * 40
                let yOff: CGFloat = isCurrent ? 0 : CGFloat(cos(seed + 1.5)) * 6
                Text(text)
                    .font(.custom(fontName, size: isCurrent ? 16 : 12))
                    .fontWeight(weight)
                    .foregroundColor(
                        isCurrent ? style.currentLineColor.color :
                        isPast ? style.pastLineColor.color :
                        style.otherLineColor.color
                    )
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 1)
                    .offset(x: xOff, y: yOff)
                    .scaleEffect(isCurrent ? 1.05 : 0.8)
                    .opacity(isCurrent ? 1.0 : isPast ? 0.25 : 0.45)
                    .animation(.spring(response: duration * 0.5, dampingFraction: 0.7), value: previewCurrentLine)

            case .float3D:
                // 3D浮现 - 透视旋转
                let relIdx = index - previewCurrentLine
                let rotX: Double = isCurrent ? 0 : Double(relIdx) * 15
                Text(text)
                    .font(.custom(fontName, size: isCurrent ? 16 : 13))
                    .fontWeight(weight)
                    .foregroundColor(
                        isCurrent ? style.currentLineColor.color :
                        isPast ? style.pastLineColor.color :
                        style.otherLineColor.color
                    )
                    .shadow(color: .black.opacity(0.4), radius: 3, x: 2, y: 2)
                    .rotation3DEffect(.degrees(rotX), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                    .scaleEffect(isCurrent ? 1.1 : max(0.7, 1.0 - CGFloat(abs(relIdx)) * 0.15))
                    .opacity(isCurrent ? 1.0 : max(0.2, 1.0 - Double(abs(relIdx)) * 0.3))
                    .animation(.spring(response: duration * 0.5, dampingFraction: 0.7), value: previewCurrentLine)

            case .randomSize:
                // 随机大小律动 - 每字不同大小，1-2个字特别大
                if isCurrent {
                    let chars = Array(text)
                    let bigIdx1 = abs(Int(sin(Double(previewCurrentLine) * 3.7 + 1.2) * Double(chars.count))) % max(1, chars.count)
                    let bigIdx2 = abs(Int(cos(Double(previewCurrentLine) * 2.3 + 0.8) * Double(chars.count))) % max(1, chars.count)
                    let hasTwoBig = chars.count > 3

                    HStack(alignment: .lastTextBaseline, spacing: 0.5) {
                        ForEach(0..<chars.count, id: \.self) { ci in
                            let isBig = ci == bigIdx1 || (hasTwoBig && ci == bigIdx2)
                            let ratio: CGFloat = isBig
                                ? 1.6 + CGFloat(abs(sin(Double(ci) * 2.9))) * 0.3
                                : 0.8 + CGFloat(abs(sin(Double(ci) * 1.7 + 0.5))) * 0.25
                            Text(String(chars[ci]))
                                .font(.custom(fontName, size: 14 * ratio))
                                .fontWeight(isBig ? .heavy : weight)
                                .foregroundColor(style.currentLineColor.color)
                                .shadow(color: .black.opacity(0.6), radius: 1, x: 1, y: 1.5)
                        }
                    }
                    .scaleEffect(previewRandomSizeScale)
                    .opacity(previewRandomSizeOpacity)
                    .blur(radius: previewRandomSizeBlur)
                    .animation(.easeOut(duration: 0.45), value: previewRandomSizeScale)
                    .animation(.easeOut(duration: 0.45), value: previewRandomSizeOpacity)
                    .animation(.easeOut(duration: 0.45), value: previewRandomSizeBlur)
                } else if isPast && previewRandomSizeExitActive && index == previewRandomSizePrevLine {
                    // 退场行：颜色渐浅+滑出
                    Text(text)
                        .font(.custom(fontName, size: 12))
                        .fontWeight(weight)
                        .foregroundColor(style.pastLineColor.color)
                        .opacity(previewRandomSizeExitOpacity)
                        .offset(y: previewRandomSizeExitOffset)
                        .animation(.easeIn(duration: 0.6), value: previewRandomSizeExitOpacity)
                        .animation(.easeIn(duration: 0.6), value: previewRandomSizeExitOffset)
                } else {
                    Text(text)
                        .font(.custom(fontName, size: isPast ? 10 : 11))
                        .fontWeight(weight)
                        .foregroundColor(isPast ? style.pastLineColor.color : style.otherLineColor.color)
                        .opacity(isPast ? 0.2 : 0.3)
                        .animation(.easeOut(duration: 0.4), value: previewCurrentLine)
                }
            }
        }
        .shadow(
            color: isCurrent && style.currentLineGlow ? style.currentLineColor.color.opacity(0.6) : .clear,
            radius: isCurrent && style.currentLineGlow ? 6 : 0
        )
        .frame(maxWidth: .infinity, alignment: {
            switch style.alignment {
            case .leading: return .leading
            case .trailing: return .trailing
            case .center: return .center
            }
        }())
    }

    @ViewBuilder
    private func karaokeLineView(text: String, fontName: String, weight: Font.Weight) -> some View {
        let style = appState.style
        ZStack(alignment: .leading) {
            // 底层：未唱颜色
            Text(text)
                .font(.custom(fontName, size: 16))
                .fontWeight(weight)
                .foregroundColor(style.otherLineColor.color)

            // 上层：已唱颜色，用 mask 裁剪
            Text(text)
                .font(.custom(fontName, size: 16))
                .fontWeight(weight)
                .foregroundColor(style.currentLineColor.color)
                .mask(
                    GeometryReader { geo in
                        Rectangle()
                            .frame(width: geo.size.width * karaokeProgress)
                    }
                )
        }
    }

    // MARK: - 预览计时器
    private func startPreviewTimer() {
        stopPreviewTimer()
        let animStyle = appState.style.animationStyle
        let speed = Double(appState.style.animationSpeed)
        let interval: TimeInterval = max(1.2, 2.5 * (1.1 - speed))

        previewTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            DispatchQueue.main.async {
                withAnimation {
                    previewCurrentLine = (previewCurrentLine + 1) % previewLines.count
                }
                handleLineChangeForAnimation(animStyle: animStyle, interval: interval, speed: speed)
            }
        }

        // 首次立即启动特殊动画
        handleLineChangeForAnimation(animStyle: animStyle, interval: interval, speed: speed)

        // 波浪律动：启动持续波浪
        if animStyle == .wave {
            startPreviewWaveAnimation(speed: speed)
        }

        // 脉冲呼吸：启动持续脉冲
        if animStyle == .pulse {
            startPreviewPulseAnimation(speed: speed)
        }
    }

    private func handleLineChangeForAnimation(animStyle: LyricsStyle.AnimationStyleType, interval: TimeInterval, speed: Double) {
        switch animStyle {
        case .karaoke:
            startKaraokeAnimation(duration: interval * 0.85)
        case .typewriter:
            startPreviewTypewriterAnimation(speed: speed)
        case .pulse:
            startPreviewPulseAnimation(speed: speed)
        case .charBounce:
            startPreviewCharBounceAnimation(speed: speed)
        case .randomSize:
            startPreviewRandomSizeAnimation()
        default:
            break
        }
    }

    private func stopPreviewTimer() {
        previewTimer?.invalidate()
        previewTimer = nil
        karaokeTimer?.invalidate()
        karaokeTimer = nil
        previewWaveTimer?.invalidate()
        previewWaveTimer = nil
        previewTypewriterTimer?.invalidate()
        previewTypewriterTimer = nil
        previewCharBounceTimer?.invalidate()
        previewCharBounceTimer = nil
    }

    private func restartPreviewTimer() {
        stopPreviewTimer()
        previewPulseScale = 1.0
        previewWavePhase = 0
        previewTypewriterChars = 0
        previewCharBounceCount = 0
        previewCharBounceEntryDone = false
        previewCharBounceScale = 1.0
        previewCharBounceOpacity = 1.0
        previewRandomSizeScale = 1.0
        previewRandomSizeOpacity = 1.0
        previewRandomSizeBlur = 0
        previewRandomSizeEntryDone = true
        previewRandomSizeExitActive = false
        startPreviewTimer()
    }

    private func startKaraokeAnimation(duration: TimeInterval) {
        karaokeTimer?.invalidate()
        karaokeProgress = 0
        let steps = 30
        let stepInterval = duration / Double(steps)
        var step = 0
        karaokeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { timer in
            DispatchQueue.main.async {
                step += 1
                karaokeProgress = min(1.0, CGFloat(step) / CGFloat(steps))
                if step >= steps {
                    timer.invalidate()
                }
            }
        }
    }

    private func startPreviewWaveAnimation(speed: Double) {
        previewWaveTimer?.invalidate()
        previewWavePhase = 0
        let waveInterval: TimeInterval = 0.05  // 20fps
        let phaseStep = 0.12 * (0.5 + speed)  // speed 越大波浪越快
        previewWaveTimer = Timer.scheduledTimer(withTimeInterval: waveInterval, repeats: true) { _ in
            DispatchQueue.main.async {
                previewWavePhase += phaseStep
                if previewWavePhase > .pi * 20 { previewWavePhase = 0 }
            }
        }
    }

    private func startPreviewPulseAnimation(speed: Double) {
        let duration = max(0.3, 0.6 * (1.1 - speed))
        previewPulseScale = 1.0
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            previewPulseScale = 1.12
        }
    }

    private func startPreviewTypewriterAnimation(speed: Double) {
        previewTypewriterTimer?.invalidate()
        previewTypewriterChars = 0
        let currentText = previewLines[previewCurrentLine]
        let totalChars = currentText.count
        guard totalChars > 0 else { return }
        let charInterval = max(0.03, 0.1 * (1.1 - speed))
        previewTypewriterTimer = Timer.scheduledTimer(withTimeInterval: charInterval, repeats: true) { timer in
            DispatchQueue.main.async {
                previewTypewriterChars += 1
                if previewTypewriterChars >= totalChars {
                    timer.invalidate()
                }
            }
        }
    }

    private func startPreviewCharBounceAnimation(speed: Double) {
        previewCharBounceTimer?.invalidate()
        previewCharBounceCount = 0

        // === 阶段1：整句由小变大渐现 ===
        previewCharBounceEntryDone = false
        previewCharBounceScale = 0.3
        previewCharBounceOpacity = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            previewCharBounceScale = 1.0
            previewCharBounceOpacity = 1.0
        }

        // === 阶段2：渐现完成后启动逐字弹入 ===
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            previewCharBounceEntryDone = true

            let currentText = previewLines[previewCurrentLine]
            let totalChars = currentText.count
            guard totalChars > 0 else { return }
            let charInterval = max(0.04, 0.12 * (1.1 - speed))
            previewCharBounceTimer = Timer.scheduledTimer(withTimeInterval: charInterval, repeats: true) { timer in
                DispatchQueue.main.async {
                    previewCharBounceCount += 1
                    if previewCharBounceCount >= totalChars {
                        timer.invalidate()
                    }
                }
            }
        }
    }

    private func startPreviewRandomSizeAnimation() {
        // 退场：记录上一行
        let prevLine = (previewCurrentLine - 1 + previewLines.count) % previewLines.count
        previewRandomSizePrevLine = prevLine
        previewRandomSizeExitOpacity = 1.0
        previewRandomSizeExitOffset = 0
        previewRandomSizeExitActive = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            previewRandomSizeExitOpacity = 0
            previewRandomSizeExitOffset = prevLine % 2 == 0 ? 20 : -20
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            previewRandomSizeExitActive = false
        }

        // 进场：由小变大+模糊变清晰
        previewRandomSizeEntryDone = false
        previewRandomSizeScale = 0.3
        previewRandomSizeOpacity = 0
        previewRandomSizeBlur = 6

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            previewRandomSizeScale = 1.0
            previewRandomSizeOpacity = 1.0
            previewRandomSizeBlur = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            previewRandomSizeEntryDone = true
        }
    }

    // MARK: - 主题预览卡片
    @ViewBuilder
    private func themePreviewCard(theme: ThemeInfo) -> some View {
        let s = theme.style
        let globalFont = appState.style.fontName  // 使用全局字体预览
        let globalWeight = appState.style.fontWeight.swiftUI
        Button(action: {
            pendingTheme = theme
            showThemeConfirm = true
        }) {
            VStack(spacing: 0) {
                // 迷你歌词预览（使用当前全局字体）
                ZStack {
                    s.backgroundColor.color
                        .opacity(s.backgroundOpacity)

                    VStack(spacing: 4) {
                        // 已唱行
                        Text("已唱过的歌词")
                            .font(.custom(globalFont, size: 9))
                            .fontWeight(globalWeight)
                            .foregroundColor(s.pastLineColor.color)

                        // 当前行
                        Text("当前正在唱的歌词")
                            .font(.custom(globalFont, size: 11))
                            .fontWeight(globalWeight)
                            .foregroundColor(s.currentLineColor.color)
                            .shadow(
                                color: s.currentLineGlow ? s.currentLineColor.color.opacity(0.6) : .clear,
                                radius: s.currentLineGlow ? 6 : 0
                            )

                        // 待唱行
                        Text("即将要唱的歌词")
                            .font(.custom(globalFont, size: 9))
                            .fontWeight(globalWeight)
                            .foregroundColor(s.otherLineColor.color)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
                }
                .frame(height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // 主题名
                Text(theme.name)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.primary)
                    .padding(.top, 4)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 主题数据
    struct ThemeInfo {
        let name: String
        let style: ThemeStyle
    }

    struct ThemeStyle {
        // 字体设置为全局，不随主题切换
        let currentLineColor: CodableColor
        let currentLineGlow: Bool
        let otherLineColor: CodableColor
        let pastLineColor: CodableColor
        let backgroundColor: CodableColor
        let backgroundOpacity: Double
        let animationStyle: LyricsStyle.AnimationStyleType
        let alignment: LyricsStyle.TextAlignmentType
    }

    static let ktvTheme = ThemeInfo(
        name: "KTV经典",
        style: ThemeStyle(
            currentLineColor: CodableColor(r: 1, g: 0.85, b: 0),
            currentLineGlow: true,
            otherLineColor: CodableColor(r: 1, g: 1, b: 1, a: 0.5),
            pastLineColor: CodableColor(r: 0.5, g: 0.5, b: 0.5, a: 0.3),
            backgroundColor: CodableColor(r: 0, g: 0, b: 0),
            backgroundOpacity: 1.0,
            animationStyle: .karaoke, alignment: .center
        )
    )

    static let concertTheme = ThemeInfo(
        name: "演唱会",
        style: ThemeStyle(
            currentLineColor: CodableColor(r: 1, g: 1, b: 1),
            currentLineGlow: true,
            otherLineColor: CodableColor(r: 0.7, g: 0.7, b: 1, a: 0.4),
            pastLineColor: CodableColor(r: 0.4, g: 0.4, b: 0.6, a: 0.2),
            backgroundColor: CodableColor(r: 0.05, g: 0.02, b: 0.15),
            backgroundOpacity: 1.0,
            animationStyle: .bounce, alignment: .center
        )
    )

    static let minimalTheme = ThemeInfo(
        name: "简约白",
        style: ThemeStyle(
            currentLineColor: CodableColor(r: 0.1, g: 0.1, b: 0.1),
            currentLineGlow: false,
            otherLineColor: CodableColor(r: 0.5, g: 0.5, b: 0.5, a: 0.5),
            pastLineColor: CodableColor(r: 0.7, g: 0.7, b: 0.7, a: 0.3),
            backgroundColor: CodableColor(r: 0.95, g: 0.95, b: 0.95),
            backgroundOpacity: 1.0,
            animationStyle: .fade, alignment: .center
        )
    )

    static let neonTheme = ThemeInfo(
        name: "霓虹灯",
        style: ThemeStyle(
            currentLineColor: CodableColor(r: 0, g: 1, b: 0.8),
            currentLineGlow: true,
            otherLineColor: CodableColor(r: 1, g: 0.2, b: 0.8, a: 0.5),
            pastLineColor: CodableColor(r: 0.3, g: 0.1, b: 0.3, a: 0.3),
            backgroundColor: CodableColor(r: 0.05, g: 0, b: 0.1),
            backgroundOpacity: 1.0,
            animationStyle: .smooth, alignment: .center
        )
    )

    // 浪漫婚礼 - 粉金配色，温馨柔和
    static let weddingTheme = ThemeInfo(
        name: "浪漫婚礼",
        style: ThemeStyle(
            currentLineColor: CodableColor(r: 0.85, g: 0.65, b: 0.5),
            currentLineGlow: true,
            otherLineColor: CodableColor(r: 1, g: 0.85, b: 0.85, a: 0.5),
            pastLineColor: CodableColor(r: 0.7, g: 0.55, b: 0.55, a: 0.25),
            backgroundColor: CodableColor(r: 0.15, g: 0.05, b: 0.08),
            backgroundOpacity: 1.0,
            animationStyle: .fade, alignment: .center
        )
    )

    // 复古港风 - 红黄经典港式卡拉OK
    static let retroHKTheme = ThemeInfo(
        name: "复古港风",
        style: ThemeStyle(
            currentLineColor: CodableColor(r: 1, g: 0.2, b: 0.2),
            currentLineGlow: false,
            otherLineColor: CodableColor(r: 1, g: 0.95, b: 0.6, a: 0.6),
            pastLineColor: CodableColor(r: 0.6, g: 0.6, b: 0.4, a: 0.25),
            backgroundColor: CodableColor(r: 0.08, g: 0.05, b: 0.15),
            backgroundOpacity: 1.0,
            animationStyle: .karaoke, alignment: .center
        )
    )

    // 清新自然 - 绿色系，适合轻音乐/民谣
    static let natureTheme = ThemeInfo(
        name: "清新自然",
        style: ThemeStyle(
            currentLineColor: CodableColor(r: 0.3, g: 0.8, b: 0.4),
            currentLineGlow: true,
            otherLineColor: CodableColor(r: 0.6, g: 0.85, b: 0.7, a: 0.45),
            pastLineColor: CodableColor(r: 0.35, g: 0.5, b: 0.4, a: 0.2),
            backgroundColor: CodableColor(r: 0.02, g: 0.08, b: 0.04),
            backgroundOpacity: 1.0,
            animationStyle: .wave, alignment: .center
        )
    )

    // 热血摇滚 - 红黑撞色，大字粗体
    static let rockTheme = ThemeInfo(
        name: "热血摇滚",
        style: ThemeStyle(
            currentLineColor: CodableColor(r: 1, g: 0.15, b: 0.1),
            currentLineGlow: true,
            otherLineColor: CodableColor(r: 0.9, g: 0.9, b: 0.9, a: 0.4),
            pastLineColor: CodableColor(r: 0.4, g: 0.1, b: 0.1, a: 0.25),
            backgroundColor: CodableColor(r: 0.05, g: 0.02, b: 0.02),
            backgroundOpacity: 1.0,
            animationStyle: .pulse, alignment: .center
        )
    )

    // 深海蓝 - 冷色调，沉静优雅
    static let oceanTheme = ThemeInfo(
        name: "深海蓝",
        style: ThemeStyle(
            currentLineColor: CodableColor(r: 0.4, g: 0.8, b: 1),
            currentLineGlow: true,
            otherLineColor: CodableColor(r: 0.5, g: 0.7, b: 0.9, a: 0.4),
            pastLineColor: CodableColor(r: 0.3, g: 0.4, b: 0.55, a: 0.2),
            backgroundColor: CodableColor(r: 0.02, g: 0.05, b: 0.12),
            backgroundOpacity: 1.0,
            animationStyle: .slideIn, alignment: .center
        )
    )

    // 暖光酒吧 - 暖黄昏暗，适合酒吧/餐厅
    static let barTheme = ThemeInfo(
        name: "暖光酒吧",
        style: ThemeStyle(
            currentLineColor: CodableColor(r: 1, g: 0.75, b: 0.35),
            currentLineGlow: true,
            otherLineColor: CodableColor(r: 0.8, g: 0.65, b: 0.45, a: 0.4),
            pastLineColor: CodableColor(r: 0.5, g: 0.4, b: 0.25, a: 0.2),
            backgroundColor: CodableColor(r: 0.1, g: 0.06, b: 0.02),
            backgroundOpacity: 1.0,
            animationStyle: .typewriter, alignment: .center
        )
    )

    // 海边日落 - 仿视频MV风格，白色粗体+暗蓝背景+逐字弹入
    static let sunsetBeachTheme = ThemeInfo(
        name: "海边日落",
        style: ThemeStyle(
            currentLineColor: CodableColor(r: 1, g: 1, b: 1),
            currentLineGlow: true,
            otherLineColor: CodableColor(r: 0.7, g: 0.8, b: 0.9, a: 0.5),
            pastLineColor: CodableColor(r: 0.5, g: 0.6, b: 0.7, a: 0.25),
            backgroundColor: CodableColor(r: 0.04, g: 0.08, b: 0.18),
            backgroundOpacity: 1.0,
            animationStyle: .charBounce, alignment: .center
        )
    )

    // MV散落 - 歌词散落式布局，适合抒情MV
    static let mvScatterTheme = ThemeInfo(
        name: "MV散落",
        style: ThemeStyle(
            currentLineColor: CodableColor(r: 1, g: 0.95, b: 0.85),
            currentLineGlow: true,
            otherLineColor: CodableColor(r: 0.75, g: 0.7, b: 0.65, a: 0.45),
            pastLineColor: CodableColor(r: 0.5, g: 0.45, b: 0.4, a: 0.2),
            backgroundColor: CodableColor(r: 0.06, g: 0.04, b: 0.1),
            backgroundOpacity: 1.0,
            animationStyle: .scatter, alignment: .center
        )
    )

    // 立体舞台 - 3D透视旋转，适合演出场景
    static let stage3DTheme = ThemeInfo(
        name: "立体舞台",
        style: ThemeStyle(
            currentLineColor: CodableColor(r: 0.95, g: 0.85, b: 1),
            currentLineGlow: true,
            otherLineColor: CodableColor(r: 0.6, g: 0.5, b: 0.8, a: 0.4),
            pastLineColor: CodableColor(r: 0.35, g: 0.3, b: 0.5, a: 0.2),
            backgroundColor: CodableColor(r: 0.08, g: 0.03, b: 0.12),
            backgroundOpacity: 1.0,
            animationStyle: .float3D, alignment: .center
        )
    )

    // 随机律动 - 字体随机大小+模糊进场+滑出退场
    static let randomSizeTheme = ThemeInfo(
        name: "随机律动",
        style: ThemeStyle(
            currentLineColor: CodableColor(r: 1, g: 0.92, b: 0.7),
            currentLineGlow: true,
            otherLineColor: CodableColor(r: 0.65, g: 0.6, b: 0.55, a: 0.4),
            pastLineColor: CodableColor(r: 0.45, g: 0.4, b: 0.35, a: 0.25),
            backgroundColor: CodableColor(r: 0.05, g: 0.03, b: 0.08),
            backgroundOpacity: 1.0,
            animationStyle: .randomSize, alignment: .center
        )
    )

    // 全部主题集合
    static let allThemes: [ThemeInfo] = [
        ktvTheme, concertTheme, minimalTheme, neonTheme,
        weddingTheme, retroHKTheme, natureTheme,
        rockTheme, oceanTheme, barTheme,
        sunsetBeachTheme, mvScatterTheme, stage3DTheme,
        randomSizeTheme
    ]

    // MARK: - 应用主题（一次性赋值，避免多次触发 didSet 导致卡顿）
    // 字体设置（fontName / fontSize / fontWeight）为全局设置，切换主题时保留不变
    private func applyTheme(_ t: ThemeStyle) {
        var newStyle = appState.style  // 保留字体、lineSpacing、padding 等全局设置
        // 只覆盖颜色、背景、动画、对齐
        newStyle.currentLineColor = t.currentLineColor
        newStyle.currentLineGlow = t.currentLineGlow
        newStyle.otherLineColor = t.otherLineColor
        newStyle.pastLineColor = t.pastLineColor
        newStyle.backgroundColor = t.backgroundColor
        newStyle.backgroundOpacity = t.backgroundOpacity
        newStyle.animationStyle = t.animationStyle
        newStyle.alignment = t.alignment
        appState.style = newStyle  // 只触发一次 didSet → saveStyle()
    }

    // MARK: - 颜色绑定
    private var currentLineColorBinding: Binding<Color> {
        Binding(
            get: { appState.style.currentLineColor.color },
            set: { appState.style.currentLineColor = CodableColor(from: NSColor($0)) }
        )
    }

    private var otherLineColorBinding: Binding<Color> {
        Binding(
            get: { appState.style.otherLineColor.color },
            set: { appState.style.otherLineColor = CodableColor(from: NSColor($0)) }
        )
    }

    private var pastLineColorBinding: Binding<Color> {
        Binding(
            get: { appState.style.pastLineColor.color },
            set: { appState.style.pastLineColor = CodableColor(from: NSColor($0)) }
        )
    }

    private var bgColorBinding: Binding<Color> {
        Binding(
            get: { appState.style.backgroundColor.color },
            set: { appState.style.backgroundColor = CodableColor(from: NSColor($0)) }
        )
    }

    // MARK: - 预设
    private func applyPresetBG(r: Double, g: Double, b: Double) {
        appState.style.backgroundColor = CodableColor(r: r, g: g, b: b)
        appState.style.backgroundOpacity = 1.0
    }

}

// MARK: - Sheet 包装器（二级页面）
struct StyleEditorSheet: View {
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

                Text("歌词显示设置")
                    .font(.headline)

                Spacer()

                // 占位，让标题居中
                Button("") {}
                    .hidden()
                    .frame(width: 60)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)

            Divider()

            // 内容
            StyleEditorView()
                .environmentObject(appState)
        }
        .frame(minWidth: 420, idealWidth: 500, minHeight: 600, idealHeight: 750)
    }
}
