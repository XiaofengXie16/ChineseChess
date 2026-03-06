import SwiftUI

private let sidebarWidth: CGFloat = 230

struct ContentView: View {
    @StateObject private var game = ChessGame()
    @State private var redWins = 0
    @State private var blackWins = 0

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // ── Left sidebar ──────────────────────────────────
                SidebarView(game: game, redWins: $redWins, blackWins: $blackWins)
                    .frame(width: sidebarWidth)

                Divider().background(Color.white.opacity(0.07))

                // ── Right board area ──────────────────────────────
                BoardAreaView(
                    game: game,
                    redWins: $redWins,
                    blackWins: $blackWins,
                    availableSize: CGSize(
                        width: geo.size.width - sidebarWidth - 1,
                        height: geo.size.height
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(red: 0.10, green: 0.09, blue: 0.08))
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @ObservedObject var game: ChessGame
    @Binding var redWins: Int
    @Binding var blackWins: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            VStack(alignment: .leading, spacing: 3) {
                Text("象棋")
                    .font(.system(size: 30, weight: .black, design: .serif))
                    .foregroundColor(.white)
                Text("Chinese Chess  ·  中国象棋")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 20)

            Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 12)

            // Player cards
            VStack(spacing: 10) {
                PlayerCard(side: .black, label: "AI", isAI: true,  wins: blackWins, game: game)

                HStack {
                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                    Text("VS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.25))
                        .padding(.horizontal, 8)
                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                }

                PlayerCard(side: .red, label: "你", isAI: false, wins: redWins, game: game)
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)

            // Buttons
            VStack(spacing: 8) {
                Button(action: { withAnimation(.easeInOut(duration: 0.18)) { game.undoMove() } }) {
                    Label("悔棋", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)))
                        .foregroundColor(.white.opacity(game.moveHistory.count >= 2 && !game.isAIThinking ? 0.85 : 0.3))
                }
                .buttonStyle(.plain)
                .disabled(game.moveHistory.count < 2 || game.isAIThinking)

                Button(action: {
                    if case .checkmate(let loser) = game.gameStatus {
                        if loser == .red { blackWins += 1 } else { redWins += 1 }
                    } else if case .repetition(let loser) = game.gameStatus {
                        if loser == .red { blackWins += 1 } else { redWins += 1 }
                    }
                    withAnimation { game.newGame() }
                }) {
                    Label("新游戏", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.18, green: 0.42, blue: 0.90)))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("n", modifiers: .command)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .background(Color(red: 0.13, green: 0.12, blue: 0.11))
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Player Card

struct PlayerCard: View {
    let side: Side
    let label: String
    let isAI: Bool
    let wins: Int
    @ObservedObject var game: ChessGame

    private var isActive: Bool { game.currentTurn == side }
    private var isInCheck: Bool {
        if case .check(let s) = game.gameStatus { return s == side }
        return false
    }

    var body: some View {
        HStack(spacing: 12) {
            // Piece avatar
            ZStack {
                Circle()
                    .fill(side == .red
                          ? RadialGradient(colors: [Color(red:1,green:0.45,blue:0.3), Color(red:0.7,green:0.05,blue:0.04)],
                                           center: UnitPoint(x:0.35,y:0.3), startRadius: 2, endRadius: 22)
                          : RadialGradient(colors: [Color(red:0.45,green:0.45,blue:0.45), Color(red:0.10,green:0.10,blue:0.10)],
                                           center: UnitPoint(x:0.35,y:0.3), startRadius: 2, endRadius: 22))
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)

                Circle()
                    .stroke(side == .red ? Color(red:0.9,green:0.6,blue:0.5).opacity(0.6) : Color.white.opacity(0.2), lineWidth: 1.5)
                    .frame(width: 44, height: 44)

                Text(side == .red ? "帅" : "将")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(side == .red ? .white : Color(white: 0.9))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(label)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    if isAI {
                        Text("CPU")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().fill(Color(red:0.18,green:0.42,blue:0.90)))
                    }
                    if isInCheck {
                        Text("将军!")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().fill(Color.orange))
                    }
                }
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i < wins ? Color.yellow : Color.white.opacity(0.15))
                            .frame(width: 7, height: 7)
                    }
                    Text("\(wins) wins")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))
                }
            }

            Spacer()

            if isAI && game.isAIThinking {
                ProgressView().controlSize(.mini).tint(Color(red:0.18,green:0.42,blue:0.90))
            } else {
                Circle()
                    .fill(isActive ? Color.green : Color.white.opacity(0.12))
                    .frame(width: 9, height: 9)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isActive ? 0.07 : 0.03))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color(red:0.18,green:0.42,blue:0.90).opacity(0.7) : Color.clear, lineWidth: 1.5))
        )
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

// MARK: - Board Area (responsive)

struct BoardAreaView: View {
    @ObservedObject var game: ChessGame
    @Binding var redWins: Int
    @Binding var blackWins: Int
    let availableSize: CGSize

    // Compute cell size to fill available space
    private var cs: CGFloat {
        let hPad: CGFloat = 80   // left (row labels) + right padding
        let vPad: CGFloat = 90   // top (turn pill) + bottom padding
        let maxByW = (availableSize.width - hPad) / 10
        let maxByH = (availableSize.height - vPad) / 11
        return max(36, min(maxByW, maxByH))
    }

    var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.09, blue: 0.08)

            VStack(spacing: 12) {
                TurnPill(game: game)

                HStack(alignment: .top, spacing: 0) {
                    // Row numbers
                    VStack(spacing: 0) {
                        Spacer().frame(height: cs)
                        ForEach(0..<10) { row in
                            Text("\(row + 1)")
                                .font(.system(size: max(9, cs * 0.20), weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.25))
                                .frame(width: 22, height: cs)
                        }
                    }

                    VStack(spacing: 0) {
                        // Column labels
                        HStack(spacing: 0) {
                            Spacer().frame(width: cs)
                            ForEach(["九","八","七","六","五","四","三","二","一"], id: \.self) { ch in
                                Text(ch)
                                    .font(.system(size: max(9, cs * 0.20), weight: .medium, design: .serif))
                                    .foregroundColor(.white.opacity(0.25))
                                    .frame(width: cs, height: cs)
                            }
                            Spacer().frame(width: cs)
                        }

                        // Board
                        ZStack(alignment: .top) {
                            BoardView(game: game, cellSize: cs)
                            RiverLabelOverlay(cellSize: cs)
                                .offset(x: cs, y: cs * 5)
                                .allowsHitTesting(false)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(red: 0.60, green: 0.44, blue: 0.22))
                                .shadow(color: .black.opacity(0.6), radius: 16, x: 0, y: 8)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(red: 0.45, green: 0.30, blue: 0.12).opacity(0.8), lineWidth: 1)
                        )
                    }

                    Spacer().frame(width: 22)
                }
            }
            .padding(.vertical, 20)

            // Game over overlay
            if case .checkmate(let loser) = game.gameStatus {
                GameOverOverlay(winner: loser.opponent, isRepetition: false, game: game,
                                redWins: $redWins, blackWins: $blackWins)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            } else if case .repetition(let loser) = game.gameStatus {
                GameOverOverlay(winner: loser.opponent, isRepetition: true, game: game,
                                redWins: $redWins, blackWins: $blackWins)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: {
            if case .checkmate = game.gameStatus { return true }
            if case .repetition = game.gameStatus { return true }
            return false
        }())
        .clipped()
    }
}

// MARK: - Turn Pill

struct TurnPill: View {
    @ObservedObject var game: ChessGame

    private var isCheck: Bool {
        if case .check = game.gameStatus { return true }
        return false
    }

    var body: some View {
        HStack(spacing: 8) {
            if game.isAIThinking {
                ProgressView().controlSize(.mini).tint(.white)
            } else {
                Circle()
                    .fill(game.currentTurn == .red
                          ? Color(red: 0.85, green: 0.12, blue: 0.08)
                          : Color(red: 0.20, green: 0.20, blue: 0.20))
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    .frame(width: 14, height: 14)
            }
            Text(pillText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 18).padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isCheck ? Color.orange.opacity(0.25) : Color.white.opacity(0.08))
                .overlay(Capsule().stroke(isCheck ? Color.orange.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1))
        )
        .animation(.easeInOut(duration: 0.2), value: game.currentTurn == .red)
    }

    private var pillText: String {
        switch game.gameStatus {
        case .check(let s): return s == .red ? "红方将军！" : "黑方将军！"
        case .repetition(let loser): return loser == .red ? "长将！红方负" : "长将！黑方负"
        default:
            if game.isAIThinking { return "AI 思考中..." }
            return game.currentTurn == .red ? "红方走棋" : "黑方走棋"
        }
    }
}

// MARK: - Game Over Overlay

struct GameOverOverlay: View {
    let winner: Side
    let isRepetition: Bool
    @ObservedObject var game: ChessGame
    @Binding var redWins: Int
    @Binding var blackWins: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.60)

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(winner == .red
                              ? RadialGradient(colors: [Color(red:1,green:0.45,blue:0.3), Color(red:0.7,green:0.05,blue:0.04)],
                                               center: UnitPoint(x:0.35,y:0.3), startRadius: 4, endRadius: 38)
                              : RadialGradient(colors: [Color(red:0.5,green:0.5,blue:0.5), Color(red:0.1,green:0.1,blue:0.1)],
                                               center: UnitPoint(x:0.35,y:0.3), startRadius: 4, endRadius: 38))
                        .frame(width: 76, height: 76)
                        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
                    Text(winner == .red ? "帅" : "将")
                        .font(.system(size: 34, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                }

                VStack(spacing: 6) {
                    Text(winner == .red ? "红方胜利！" : "黑方胜利！")
                        .font(.system(size: 26, weight: .black, design: .serif))
                        .foregroundColor(.white)
                    if isRepetition {
                        Text("长将违规，对方判负")
                            .font(.system(size: 14))
                            .foregroundColor(.orange.opacity(0.85))
                    } else {
                        Text(winner == game.playerSide ? "恭喜你赢了！" : "电脑赢了，再来一局！")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Button(action: {
                    if winner == .red { redWins += 1 } else { blackWins += 1 }
                    withAnimation { game.newGame() }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("再来一局")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.18, green: 0.42, blue: 0.90)))
                }
                .buttonStyle(.plain)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.13, green: 0.12, blue: 0.11))
                    .overlay(RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1))
            )
            .shadow(color: .black.opacity(0.7), radius: 40)
        }
    }
}
