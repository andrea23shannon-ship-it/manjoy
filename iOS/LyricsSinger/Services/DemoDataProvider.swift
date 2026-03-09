// DemoDataProvider.swift
// iOS端 - 审核演示模式数据
// 提供预置歌词数据，让App Store审核人员无需连接Mac即可体验核心功能

import Foundation

struct DemoDataProvider {

    /// 演示用歌曲列表
    static let demoSongs: [(song: SongInfo, lyrics: [LyricLine])] = [
        (demoSong1, demoLyrics1),
        (demoSong2, demoLyrics2),
        (demoSong3, demoLyrics3)
    ]

    // MARK: - 歌曲1: 小星星 (Twinkle Twinkle Little Star)
    static let demoSong1 = SongInfo(
        title: "小星星",
        artist: "儿童歌曲",
        album: "经典儿歌",
        duration: 60.0
    )

    static let demoLyrics1: [LyricLine] = [
        LyricLine(time: 0.0, text: "一闪一闪亮晶晶", translation: "Twinkle twinkle little star"),
        LyricLine(time: 4.0, text: "满天都是小星星", translation: "How I wonder what you are"),
        LyricLine(time: 8.0, text: "挂在天空放光明", translation: "Up above the world so high"),
        LyricLine(time: 12.0, text: "好像许多小眼睛", translation: "Like a diamond in the sky"),
        LyricLine(time: 16.0, text: "一闪一闪亮晶晶", translation: "Twinkle twinkle little star"),
        LyricLine(time: 20.0, text: "满天都是小星星", translation: "How I wonder what you are"),
        LyricLine(time: 24.0, text: ""),
        LyricLine(time: 26.0, text: "太阳慢慢向西沉", translation: "When the blazing sun is gone"),
        LyricLine(time: 30.0, text: "乌鸦回到热腾腾的巢", translation: "When he nothing shines upon"),
        LyricLine(time: 34.0, text: "星星挂在天空中", translation: "Then you show your little light"),
        LyricLine(time: 38.0, text: "光辉照耀到天明", translation: "Twinkle twinkle all the night"),
        LyricLine(time: 42.0, text: "一闪一闪亮晶晶", translation: "Twinkle twinkle little star"),
        LyricLine(time: 46.0, text: "满天都是小星星", translation: "How I wonder what you are")
    ]

    // MARK: - 歌曲2: 演示歌曲（原创示例歌词）
    static let demoSong2 = SongInfo(
        title: "舞台之光",
        artist: "LyricsCaster Demo",
        album: "演示专辑",
        duration: 80.0
    )

    static let demoLyrics2: [LyricLine] = [
        LyricLine(time: 0.0, text: "灯光亮起的瞬间"),
        LyricLine(time: 4.0, text: "音乐响彻整个空间"),
        LyricLine(time: 8.0, text: "歌词浮现在大屏幕上"),
        LyricLine(time: 12.0, text: "每个人都能跟着唱"),
        LyricLine(time: 16.0, text: ""),
        LyricLine(time: 18.0, text: "不需要背词的烦恼"),
        LyricLine(time: 22.0, text: "不需要担心忘记旋律"),
        LyricLine(time: 26.0, text: "歌词投屏 让音乐更自由"),
        LyricLine(time: 30.0, text: "让每个声音都被听到"),
        LyricLine(time: 34.0, text: ""),
        LyricLine(time: 36.0, text: "舞台的光 照亮每张脸"),
        LyricLine(time: 40.0, text: "歌词的字 串起每颗心"),
        LyricLine(time: 44.0, text: "一起唱 一起感受"),
        LyricLine(time: 48.0, text: "这就是音乐的力量"),
        LyricLine(time: 52.0, text: ""),
        LyricLine(time: 54.0, text: "LyricsCaster"),
        LyricLine(time: 58.0, text: "让歌词飞到大屏幕"),
        LyricLine(time: 62.0, text: "让音乐连接你和我")
    ]

    // MARK: - 歌曲3: Amazing Grace (公有领域)
    static let demoSong3 = SongInfo(
        title: "Amazing Grace",
        artist: "Traditional Hymn",
        album: "Classic Hymns",
        duration: 90.0
    )

    static let demoLyrics3: [LyricLine] = [
        LyricLine(time: 0.0, text: "Amazing grace how sweet the sound", translation: "奇异恩典 何等甘甜"),
        LyricLine(time: 6.0, text: "That saved a wretch like me", translation: "我曾迷失 今被寻回"),
        LyricLine(time: 12.0, text: "I once was lost but now am found", translation: "曾经迷途 如今归来"),
        LyricLine(time: 18.0, text: "Was blind but now I see", translation: "曾经盲目 重见光明"),
        LyricLine(time: 24.0, text: ""),
        LyricLine(time: 26.0, text: "T'was grace that taught my heart to fear", translation: "恩典教导 我心敬畏"),
        LyricLine(time: 32.0, text: "And grace my fears relieved", translation: "恩典解除 我心忧惧"),
        LyricLine(time: 38.0, text: "How precious did that grace appear", translation: "恩典何等 宝贵珍重"),
        LyricLine(time: 44.0, text: "The hour I first believed", translation: "在我初信 那一刻"),
        LyricLine(time: 50.0, text: ""),
        LyricLine(time: 52.0, text: "Through many dangers toils and snares", translation: "历经险阻 艰辛陷阱"),
        LyricLine(time: 58.0, text: "I have already come", translation: "我已走过"),
        LyricLine(time: 64.0, text: "T'is grace hath brought me safe thus far", translation: "恩典保守 一路平安"),
        LyricLine(time: 70.0, text: "And grace will lead me home", translation: "恩典引领 回到家园")
    ]
}
