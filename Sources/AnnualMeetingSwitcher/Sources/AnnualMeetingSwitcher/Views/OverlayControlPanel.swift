import SwiftUI

// MARK: - V27: 叠层控制面板（主控台 UI）
// V27 新增：Lower Third 人名条控制区

struct OverlayControlPanel: View {
    @EnvironmentObject var viewModel: SwitcherViewModel

    // 倒计时输入状态
    @State private var countdownMinutes: Int       = 10
    @State private var countdownSecs: Int          = 0
    @State private var countdownTitleInput: String = "活动即将开始"

    // 游动字幕输入状态
    @State private var tickerInput: String         = "Welcome · The program will begin shortly"
    @State private var tickerSpeedIndex: Int       = 1   // 0慢/1中/2快

    // V27: Lower Third 输入状态
    @State private var ltNameInput: String         = ""
    @State private var ltTitleInput: String        = ""

    private let tickerSpeeds: [(String, Double)] = [
        ("慢", 55), ("中", 85), ("快", 130)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── 标题 ──
                panelHeader

                Divider()

                // ── V27: 下三分之一条（人名条）区 ──
                lowerThirdSection

                Divider()

                // ── 倒计时区 ──
                countdownSection

                Divider()

                // ── 游动字幕区 ──
                tickerSection

                Spacer(minLength: 0)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 标题区

    private var panelHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "film.stack")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            Text("叠层控制")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(.top, 2)
    }

    // MARK: - V27: 下三分之一条区

    private var lowerThirdSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 区标题
            HStack(spacing: 6) {
                Label("人名条（Lower Third）", systemImage: "person.text.rectangle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                // 状态指示灯
                Circle()
                    .fill(viewModel.isLowerThirdVisible ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 8, height: 8)
            }

            // 姓名输入
            TextField("嘉宾姓名", text: $ltNameInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))

            // 职务/头衔输入
            TextField("职务 / 单位（可留空）", text: $ltTitleInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))

            // 快捷操作按钮组
            HStack(spacing: 8) {
                // 上屏按钮
                Button(action: {
                    guard !ltNameInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.showLowerThird(name: ltNameInput, title: ltTitleInput)
                    }
                }) {
                    Label("上屏", systemImage: "arrow.up.to.line")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 7)
                .background(viewModel.isLowerThirdVisible ? Color.gray : Color.red)
                .cornerRadius(8)
                .disabled(viewModel.isLowerThirdVisible || ltNameInput.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity((viewModel.isLowerThirdVisible || ltNameInput.trimmingCharacters(in: .whitespaces).isEmpty) ? 0.5 : 1.0)

                // 退场按钮
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.dismissLowerThird()
                    }
                }) {
                    Label("退场", systemImage: "arrow.down.to.line")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 7)
                .background(Color.gray)
                .cornerRadius(8)
                .disabled(!viewModel.isLowerThirdVisible)
                .opacity(viewModel.isLowerThirdVisible ? 1.0 : 0.5)
            }

            // 当前上屏预览（上屏中时展示）
            if viewModel.isLowerThirdVisible {
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.lowerThirdName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        if !viewModel.lowerThirdTitle.isEmpty {
                            Text(viewModel.lowerThirdTitle)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Text("● 直播中")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.red.opacity(0.4), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - 倒计时区

    private var countdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("倒计时", systemImage: "timer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            // 标题文本
            TextField("标题（如：活动即将开始）", text: $countdownTitleInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            // 时间输入：分钟 + 秒（直接输入数字）
            HStack(spacing: 8) {
                // 分钟输入框
                HStack(spacing: 4) {
                    TextField("10", value: $countdownMinutes, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 52)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                    Text("分")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Text(":")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.secondary)

                // 秒输入框
                HStack(spacing: 4) {
                    TextField("00", value: $countdownSecs, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 52)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                    Text("秒")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // 实时剩余（激活时显示）
            if viewModel.isCountdownActive {
                HStack {
                    Text("剩余: \(formattedTime(viewModel.countdownSeconds))")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                    Spacer()
                }
            }

            // 开始/停止按钮
            HStack(spacing: 8) {
                Button(action: {
                    let total = countdownMinutes * 60 + countdownSecs
                    guard total > 0 else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.startCountdown(seconds: total, title: countdownTitleInput)
                    }
                }) {
                    Label("开始", systemImage: "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 7)
                .background(Color.orange)
                .cornerRadius(8)
                .disabled(viewModel.isCountdownActive)
                .opacity(viewModel.isCountdownActive ? 0.5 : 1.0)

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.stopCountdown()
                    }
                }) {
                    Label("停止", systemImage: "stop.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 7)
                .background(Color.gray)
                .cornerRadius(8)
                .disabled(!viewModel.isCountdownActive)
                .opacity(viewModel.isCountdownActive ? 1.0 : 0.5)
            }
        }
    }

    // MARK: - 游动字幕区

    private var tickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("游动字幕", systemImage: "text.badge.star")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            // 文本输入
            TextEditor(text: $tickerInput)
                .font(.system(size: 12))
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )

            // 速度选择
            HStack {
                Text("速度:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Picker("", selection: $tickerSpeedIndex) {
                    ForEach(0..<tickerSpeeds.count, id: \.self) { i in
                        Text(tickerSpeeds[i].0).tag(i)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: tickerSpeedIndex) { _, idx in
                    viewModel.tickerSpeed = tickerSpeeds[idx].1
                }
            }

            // 开始/停止按钮
            HStack(spacing: 8) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.startTicker(text: tickerInput)
                    }
                }) {
                    Label("开始", systemImage: "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 7)
                .background(Color.purple)
                .cornerRadius(8)
                .disabled(viewModel.isTickerActive)
                .opacity(viewModel.isTickerActive ? 0.5 : 1.0)

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.stopTicker()
                    }
                }) {
                    Label("停止", systemImage: "stop.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 7)
                .background(Color.gray)
                .cornerRadius(8)
                .disabled(!viewModel.isTickerActive)
                .opacity(viewModel.isTickerActive ? 1.0 : 0.5)
            }
        }
    }

    private func formattedTime(_ seconds: Int) -> String {
        let m = max(seconds, 0) / 60
        let s = max(seconds, 0) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
