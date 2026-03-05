// ConnectionView.swift
// iOS端 - 连接状态视图（嵌入主界面顶部）

import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject var client: MultipeerClient

    var body: some View {
        HStack(spacing: 10) {
            // 状态图标
            Image(systemName: client.isConnected
                ? "checkmark.circle.fill"
                : client.isSearching ? "antenna.radiowaves.left.and.right" : "wifi.slash")
                .foregroundColor(client.isConnected ? .green : .orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(client.statusMessage)
                    .font(.subheadline.weight(.medium))
                if client.isConnected {
                    Text("歌词将实时投影到Mac")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !client.isConnected {
                Button(client.isSearching ? "搜索中..." : "连接Mac") {
                    if !client.isSearching {
                        client.startSearching()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(client.isSearching)
            } else {
                Button("断开") {
                    client.disconnect()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 2))
    }
}
