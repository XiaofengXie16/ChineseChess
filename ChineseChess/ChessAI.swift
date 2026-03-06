import Foundation

// MARK: - Piece Values

private let pieceValue: [PieceType: Int] = [
    .general:  100_000,
    .chariot:    900,
    .cannon:     450,
    .horse:      400,
    .elephant:   200,
    .advisor:    200,
    .soldier:    100,
]

// Position bonus tables (from Black's perspective — low row = home)
// Each table is [row][col], 10 rows × 9 cols
private let soldierBonus: [[Int]] = [
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [50,50,50,50,50,50,50,50,50],  // just crossed river — big bonus
    [60,60,60,60,60,60,60,60,60],
    [70,70,70,70,70,70,70,70,70],
    [80,80,80,80,80,80,80,80,80],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],  // unreachable row 9 for black
]

// MARK: - Evaluation

struct ChessAI {

    static func evaluate(board: [ChessPiece], for side: Side, game: ChessGame) -> Int {
        var score = 0
        for piece in board {
            var val = pieceValue[piece.type] ?? 0

            // Soldier position bonus
            if piece.type == .soldier {
                let r = piece.side == .black ? piece.position.row : 9 - piece.position.row
                let c = piece.position.col
                val += soldierBonus[min(r, 9)][min(c, 8)]
            }

            // Chariot / cannon: mobility bonus
            if piece.type == .chariot || piece.type == .cannon {
                val += game.rawMoves(for: piece, board: board).count * 5
            }

            score += (piece.side == side) ? val : -val
        }
        return score
    }

    // MARK: - Minimax + Alpha-Beta

    static func bestMove(for side: Side, board: [ChessPiece], game: ChessGame) -> (piece: ChessPiece, to: Position)? {
        let depth = 3
        var alpha = Int.min + 1
        let beta  = Int.max - 1
        var bestMove: (ChessPiece, Position)? = nil

        let myPieces = board.filter { $0.side == side }
        var allMoves: [(ChessPiece, Position)] = []
        for piece in myPieces {
            for pos in game.legalMoves(for: piece, board: board) {
                allMoves.append((piece, pos))
            }
        }
        // Shuffle for variety at equal scores
        allMoves.shuffle()

        for (piece, pos) in allMoves {
            let simBoard = applyMove(piece: piece, to: pos, board: board)
            let val = minimax(board: simBoard, depth: depth-1, alpha: alpha, beta: beta,
                              maximizing: false, side: side, game: game)
            if val > alpha {
                alpha = val
                bestMove = (piece, pos)
            }
        }
        return bestMove
    }

    private static func minimax(board: [ChessPiece], depth: Int, alpha: Int, beta: Int,
                                maximizing: Bool, side: Side, game: ChessGame) -> Int {
        let currentSide: Side = maximizing ? side : side.opponent

        // Terminal / depth check
        if depth == 0 { return evaluate(board: board, for: side, game: game) }

        // Check for no legal moves (loss/stalemate)
        let myPieces = board.filter { $0.side == currentSide }
        var hasMoves = false
        for piece in myPieces {
            if !game.legalMoves(for: piece, board: board).isEmpty { hasMoves = true; break }
        }
        if !hasMoves {
            return maximizing ? (Int.min + 1) : (Int.max - 1)
        }

        var a = alpha, b = beta

        if maximizing {
            var best = Int.min + 1
            outer: for piece in myPieces {
                for pos in game.legalMoves(for: piece, board: board) {
                    let sim = applyMove(piece: piece, to: pos, board: board)
                    let val = minimax(board: sim, depth: depth-1, alpha: a, beta: b,
                                     maximizing: false, side: side, game: game)
                    best = max(best, val)
                    a = max(a, val)
                    if b <= a { break outer }
                }
            }
            return best
        } else {
            var best = Int.max - 1
            outer: for piece in myPieces {
                for pos in game.legalMoves(for: piece, board: board) {
                    let sim = applyMove(piece: piece, to: pos, board: board)
                    let val = minimax(board: sim, depth: depth-1, alpha: a, beta: b,
                                     maximizing: true, side: side, game: game)
                    best = min(best, val)
                    b = min(b, val)
                    if b <= a { break outer }
                }
            }
            return best
        }
    }

    // MARK: - Board Simulation

    private static func applyMove(piece: ChessPiece, to pos: Position, board: [ChessPiece]) -> [ChessPiece] {
        var sim = board
        sim.removeAll { $0.position == pos && $0.side != piece.side }
        if let idx = sim.firstIndex(where: { $0.id == piece.id }) {
            sim[idx].position = pos
        }
        return sim
    }
}
