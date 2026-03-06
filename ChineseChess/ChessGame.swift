import SwiftUI
import Combine

class ChessGame: ObservableObject {

    // MARK: - Published State

    @Published var pieces: [ChessPiece] = []
    @Published var currentTurn: Side = .red
    @Published var selectedPiece: ChessPiece? = nil
    @Published var validMoves: [Position] = []
    @Published var gameStatus: GameStatus = .playing
    @Published var lastMove: (from: Position, to: Position)? = nil
    @Published var moveHistory: [MoveRecord] = []
    @Published var isAIThinking: Bool = false

    let playerSide: Side = .red   // Human always plays Red
    var aiSide: Side { playerSide.opponent }

    private var positionCounts: [String: Int] = [:]

    // MARK: - Init

    init() { setupBoard() }

    // MARK: - Board Setup

    func setupBoard() {
        pieces = []
        currentTurn = .red
        selectedPiece = nil
        validMoves = []
        gameStatus = .playing
        lastMove = nil
        moveHistory = []
        isAIThinking = false
        positionCounts = [:]
        loadInitialPieces()
    }

    func newGame() {
        setupBoard()
    }

    private func loadInitialPieces() {
        // Black pieces — top (rows 0–3)
        let backRow: [(PieceType, Int)] = [
            (.chariot,0),(.horse,1),(.elephant,2),(.advisor,3),
            (.general,4),(.advisor,5),(.elephant,6),(.horse,7),(.chariot,8)
        ]
        for (type, col) in backRow {
            pieces.append(ChessPiece(type: type, side: .black, position: Position(col: col, row: 0)))
        }
        pieces.append(ChessPiece(type: .cannon, side: .black, position: Position(col: 1, row: 2)))
        pieces.append(ChessPiece(type: .cannon, side: .black, position: Position(col: 7, row: 2)))
        for col in [0,2,4,6,8] {
            pieces.append(ChessPiece(type: .soldier, side: .black, position: Position(col: col, row: 3)))
        }
        // Red pieces — bottom (rows 6–9)
        for (type, col) in backRow {
            pieces.append(ChessPiece(type: type, side: .red, position: Position(col: col, row: 9)))
        }
        pieces.append(ChessPiece(type: .cannon, side: .red, position: Position(col: 1, row: 7)))
        pieces.append(ChessPiece(type: .cannon, side: .red, position: Position(col: 7, row: 7)))
        for col in [0,2,4,6,8] {
            pieces.append(ChessPiece(type: .soldier, side: .red, position: Position(col: col, row: 6)))
        }
    }

    // MARK: - Piece Lookup

    func piece(at pos: Position, in board: [ChessPiece]? = nil) -> ChessPiece? {
        (board ?? pieces).first { $0.position == pos }
    }

    // MARK: - Human Tap / Selection

    func handleTap(at pos: Position) {
        if case .checkmate = gameStatus { return }
        guard !isAIThinking else { return }
        guard currentTurn == playerSide else { return }
        guard pos.col >= 0, pos.col <= 8, pos.row >= 0, pos.row <= 9 else { return }

        if let selected = selectedPiece {
            if validMoves.contains(pos) {
                executeMove(selected, to: pos)
                return
            } else if let tapped = piece(at: pos), tapped.side == currentTurn {
                selectedPiece = tapped
                validMoves = legalMoves(for: tapped)
                return
            } else {
                selectedPiece = nil
                validMoves = []
                return
            }
        }

        if let tapped = piece(at: pos), tapped.side == currentTurn {
            selectedPiece = tapped
            validMoves = legalMoves(for: tapped)
        }
    }

    // MARK: - Execute Move

    func executeMove(_ piece: ChessPiece, to pos: Position) {
        let from = piece.position
        let moverSide = currentTurn
        let captured = self.piece(at: pos)

        moveHistory.append(MoveRecord(pieceId: piece.id, from: from, to: pos, capturedPiece: captured))

        if let cap = captured {
            pieces.removeAll { $0.id == cap.id }
        }
        if let idx = pieces.firstIndex(where: { $0.id == piece.id }) {
            pieces[idx].position = pos
        }

        lastMove = (from: from, to: pos)
        selectedPiece = nil
        validMoves = []
        currentTurn = currentTurn.opponent

        // Check three-fold repetition before refreshing status
        let hash = boardStateHash()
        positionCounts[hash, default: 0] += 1
        if positionCounts[hash]! >= 3 {
            gameStatus = .repetition(moverSide)
            return
        }

        refreshGameStatus()

        // Trigger AI if game still going
        switch gameStatus {
        case .playing, .check: triggerAIIfNeeded()
        default: break
        }
    }

    private func boardStateHash() -> String {
        let pieceStr = pieces
            .sorted {
                if $0.position.row != $1.position.row { return $0.position.row < $1.position.row }
                return $0.position.col < $1.position.col
            }
            .map { "\($0.side == .red ? "R" : "B")\($0.chineseChar)\($0.position.col)\($0.position.row)" }
            .joined()
        return "\(currentTurn == .red ? "R" : "B")|\(pieceStr)"
    }

    // MARK: - Undo

    func undoMove() {
        // Undo AI move first, then human move
        guard !isAIThinking else { return }
        let movesToUndo = currentTurn == playerSide ? 2 : 1
        for _ in 0..<movesToUndo {
            guard let record = moveHistory.last else { break }
            moveHistory.removeLast()
            if let idx = pieces.firstIndex(where: { $0.id == record.pieceId }) {
                pieces[idx].position = record.from
            }
            if let cap = record.capturedPiece {
                pieces.append(cap)
            }
            currentTurn = currentTurn.opponent
        }
        lastMove = moveHistory.last.map { (from: $0.from, to: $0.to) }
        selectedPiece = nil
        validMoves = []
        positionCounts = [:]
        refreshGameStatus()
    }

    // MARK: - Game Status

    func refreshGameStatus() {
        let inCheck = isKingInCheck(side: currentTurn, board: pieces)
        let hasLegal = pieces.filter { $0.side == currentTurn }.contains { legalMoves(for: $0).count > 0 }

        if !hasLegal {
            gameStatus = .checkmate(currentTurn)
        } else if inCheck {
            gameStatus = .check(currentTurn)
        } else {
            gameStatus = .playing
        }
    }

    // MARK: - AI

    private func triggerAIIfNeeded() {
        guard currentTurn == aiSide else { return }
        isAIThinking = true

        let boardSnapshot = pieces  // capture current state

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = ChessAI.bestMove(for: self.aiSide, board: boardSnapshot, game: self)
            DispatchQueue.main.async {
                self.isAIThinking = false
                if let (piece, to) = result, let livePiece = self.pieces.first(where: { $0.id == piece.id }) {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        self.executeMove(livePiece, to: to)
                    }
                } else {
                    // AI has no legal moves — it loses
                    self.gameStatus = .checkmate(self.aiSide)
                }
            }
        }
    }

    // MARK: - Check Detection

    func isKingInCheck(side: Side, board: [ChessPiece]) -> Bool {
        guard let king = board.first(where: { $0.type == .general && $0.side == side }) else {
            return false
        }
        for opp in board.filter({ $0.side == side.opponent }) {
            if rawMoves(for: opp, board: board).contains(king.position) { return true }
        }
        // Flying general
        if let oppKing = board.first(where: { $0.type == .general && $0.side == side.opponent }),
           king.position.col == oppKing.position.col {
            let lo = min(king.position.row, oppKing.position.row) + 1
            let hi = max(king.position.row, oppKing.position.row)
            let blocked = (lo..<hi).contains { r in
                board.contains { $0.position == Position(col: king.position.col, row: r) }
            }
            if !blocked { return true }
        }
        return false
    }

    // MARK: - Legal Moves

    func legalMoves(for piece: ChessPiece) -> [Position] {
        legalMoves(for: piece, board: pieces)
    }

    func legalMoves(for piece: ChessPiece, board: [ChessPiece]) -> [Position] {
        rawMoves(for: piece, board: board).filter { pos in
            !wouldBeInCheck(moving: piece, to: pos, board: board)
        }
    }

    func wouldBeInCheck(moving piece: ChessPiece, to pos: Position, board: [ChessPiece]) -> Bool {
        var sim = board
        sim.removeAll { $0.position == pos && $0.side != piece.side }
        if let idx = sim.firstIndex(where: { $0.id == piece.id }) {
            sim[idx].position = pos
        }
        return isKingInCheck(side: piece.side, board: sim)
    }

    // MARK: - Raw Move Generation

    func rawMoves(for piece: ChessPiece, board: [ChessPiece]) -> [Position] {
        func at(_ p: Position) -> ChessPiece? { board.first { $0.position == p } }
        func valid(_ p: Position) -> Bool { p.col >= 0 && p.col <= 8 && p.row >= 0 && p.row <= 9 }
        func canGo(_ p: Position) -> Bool { valid(p) && at(p)?.side != piece.side }

        let pos = piece.position
        var moves: [Position] = []

        switch piece.type {
        case .general:
            let palaceRows: ClosedRange<Int> = piece.side == .red ? 7...9 : 0...2
            for (dc, dr) in [(0,1),(0,-1),(1,0),(-1,0)] {
                let np = Position(col: pos.col+dc, row: pos.row+dr)
                if valid(np), palaceRows.contains(np.row), (3...5).contains(np.col), canGo(np) {
                    moves.append(np)
                }
            }

        case .advisor:
            let palaceRows: ClosedRange<Int> = piece.side == .red ? 7...9 : 0...2
            for (dc, dr) in [(1,1),(1,-1),(-1,1),(-1,-1)] {
                let np = Position(col: pos.col+dc, row: pos.row+dr)
                if valid(np), palaceRows.contains(np.row), (3...5).contains(np.col), canGo(np) {
                    moves.append(np)
                }
            }

        case .elephant:
            let ownRows: ClosedRange<Int> = piece.side == .red ? 5...9 : 0...4
            for (dc, dr) in [(2,2),(2,-2),(-2,2),(-2,-2)] {
                let np = Position(col: pos.col+dc, row: pos.row+dr)
                let bp = Position(col: pos.col+dc/2, row: pos.row+dr/2)
                if valid(np), ownRows.contains(np.row), at(bp) == nil, canGo(np) {
                    moves.append(np)
                }
            }

        case .horse:
            let defs: [(dc:Int,dr:Int,bdc:Int,bdr:Int)] = [
                (1,2,0,1),(1,-2,0,-1),(-1,2,0,1),(-1,-2,0,-1),
                (2,1,1,0),(2,-1,1,0),(-2,1,-1,0),(-2,-1,-1,0)
            ]
            for h in defs {
                let np = Position(col: pos.col+h.dc, row: pos.row+h.dr)
                let bp = Position(col: pos.col+h.bdc, row: pos.row+h.bdr)
                if valid(np), at(bp) == nil, canGo(np) { moves.append(np) }
            }

        case .chariot:
            for (dc, dr) in [(0,1),(0,-1),(1,0),(-1,0)] {
                var c = pos.col+dc, r = pos.row+dr
                while c >= 0 && c <= 8 && r >= 0 && r <= 9 {
                    let np = Position(col: c, row: r)
                    if let p = at(np) { if p.side != piece.side { moves.append(np) }; break }
                    moves.append(np)
                    c += dc; r += dr
                }
            }

        case .cannon:
            for (dc, dr) in [(0,1),(0,-1),(1,0),(-1,0)] {
                var c = pos.col+dc, r = pos.row+dr
                var screen = false
                while c >= 0 && c <= 8 && r >= 0 && r <= 9 {
                    let np = Position(col: c, row: r)
                    if let p = at(np) {
                        if screen { if p.side != piece.side { moves.append(np) }; break }
                        else { screen = true }
                    } else if !screen { moves.append(np) }
                    c += dc; r += dr
                }
            }

        case .soldier:
            if piece.side == .red {
                let fwd = Position(col: pos.col, row: pos.row-1)
                if valid(fwd) && canGo(fwd) { moves.append(fwd) }
                if pos.row <= 4 {
                    for dc in [-1,1] {
                        let sp = Position(col: pos.col+dc, row: pos.row)
                        if valid(sp) && canGo(sp) { moves.append(sp) }
                    }
                }
            } else {
                let fwd = Position(col: pos.col, row: pos.row+1)
                if valid(fwd) && canGo(fwd) { moves.append(fwd) }
                if pos.row >= 5 {
                    for dc in [-1,1] {
                        let sp = Position(col: pos.col+dc, row: pos.row)
                        if valid(sp) && canGo(sp) { moves.append(sp) }
                    }
                }
            }
        }
        return moves
    }
}
