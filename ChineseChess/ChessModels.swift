import Foundation

// MARK: - Side

enum Side: Equatable {
    case red, black

    var opponent: Side { self == .red ? .black : .red }

    var displayName: String { self == .red ? "红方" : "黑方" }
    var turnText: String { self == .red ? "红方走棋" : "黑方走棋" }
}

// MARK: - PieceType

enum PieceType: CaseIterable {
    case general, advisor, elephant, horse, chariot, cannon, soldier
}

// MARK: - Position

struct Position: Equatable, Hashable {
    let col: Int  // 0–8  (left to right)
    let row: Int  // 0–9  (top = black side, bottom = red side)
}

// MARK: - ChessPiece

struct ChessPiece: Identifiable {
    let id: UUID
    let type: PieceType
    let side: Side
    var position: Position

    init(type: PieceType, side: Side, position: Position) {
        self.id = UUID()
        self.type = type
        self.side = side
        self.position = position
    }

    var chineseChar: String {
        switch (type, side) {
        case (.general,  .red):   return "帅"
        case (.general,  .black): return "将"
        case (.advisor,  .red):   return "仕"
        case (.advisor,  .black): return "士"
        case (.elephant, .red):   return "相"
        case (.elephant, .black): return "象"
        case (.horse,    .red):   return "马"
        case (.horse,    .black): return "马"
        case (.chariot,  .red):   return "车"
        case (.chariot,  .black): return "车"
        case (.cannon,   .red):   return "炮"
        case (.cannon,   .black): return "炮"
        case (.soldier,  .red):   return "兵"
        case (.soldier,  .black): return "卒"
        }
    }
}

// MARK: - MoveRecord (for undo)

struct MoveRecord {
    let pieceId: UUID
    let from: Position
    let to: Position
    let capturedPiece: ChessPiece?
}

// MARK: - GameStatus

enum GameStatus {
    case playing
    case check(Side)
    case checkmate(Side)   // side that LOST
    case stalemate         // draw — no legal moves but not in check (rare in Xiangqi, treated as loss)
}
