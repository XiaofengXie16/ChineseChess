import SwiftUI

// MARK: - Board Colors

private let boardFill    = Color(red: 0.76, green: 0.58, blue: 0.30)
private let lineCol      = Color(red: 0.36, green: 0.20, blue: 0.06)
private let riverFill    = Color(red: 0.68, green: 0.50, blue: 0.24)

// MARK: - BoardView

struct BoardView: View {
    @ObservedObject var game: ChessGame
    let cellSize: CGFloat

    private var bp: CGFloat { cellSize }               // board padding
    private var boardW: CGFloat { cellSize * 10 }
    private var boardH: CGFloat { cellSize * 11 }

    private func px(_ col: Int) -> CGFloat { bp + CGFloat(col) * cellSize }
    private func py(_ row: Int) -> CGFloat { bp + CGFloat(row) * cellSize }

    var body: some View {
        ZStack {
            // Canvas: board lines + decorations
            Canvas { ctx, size in
                drawBoard(ctx: ctx)
            }
            .frame(width: boardW, height: boardH)

            // Last move highlights
            if let lm = game.lastMove {
                moveHighlight(pos: lm.from, opacity: 0.22)
                moveHighlight(pos: lm.to,   opacity: 0.35)
            }

            // Valid move dots / rings
            ForEach(game.validMoves, id: \.self) { pos in
                validMoveMarker(pos: pos)
            }

            // Pieces
            ForEach(game.pieces) { piece in
                PieceView(piece: piece, cellSize: cellSize,
                          isSelected: game.selectedPiece?.id == piece.id)
                    .position(x: px(piece.position.col), y: py(piece.position.row))
                    .animation(.spring(response: 0.25, dampingFraction: 0.75),
                               value: piece.position.col)
                    .animation(.spring(response: 0.25, dampingFraction: 0.75),
                               value: piece.position.row)
                    .zIndex(game.selectedPiece?.id == piece.id ? 10 : 1)
            }
        }
        .frame(width: boardW, height: boardH)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { v in
                    let col = Int(round((v.location.x - bp) / cellSize))
                    let row = Int(round((v.location.y - bp) / cellSize))
                    game.handleTap(at: Position(col: col, row: row))
                }
        )
    }

    // MARK: - Overlays

    @ViewBuilder
    private func moveHighlight(pos: Position, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: cellSize * 0.45)
            .fill(Color.yellow.opacity(opacity))
            .frame(width: cellSize * 0.85, height: cellSize * 0.85)
            .position(x: px(pos.col), y: py(pos.row))
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func validMoveMarker(pos: Position) -> some View {
        let hasEnemy = game.piece(at: pos) != nil
        Group {
            if hasEnemy {
                Circle()
                    .stroke(Color(red: 0.2, green: 0.8, blue: 0.4), lineWidth: 2.5)
                    .frame(width: cellSize * 0.88, height: cellSize * 0.88)
            } else {
                Circle()
                    .fill(Color(red: 0.2, green: 0.8, blue: 0.4).opacity(0.55))
                    .frame(width: cellSize * 0.27, height: cellSize * 0.27)
            }
        }
        .position(x: px(pos.col), y: py(pos.row))
        .allowsHitTesting(false)
    }

    // MARK: - Canvas Board Drawing

    private func drawBoard(ctx: GraphicsContext) {
        let bp = self.bp
        let cs = cellSize

        // Board background
        let boardRect = CGRect(x: bp - cs*0.5, y: bp - cs*0.5, width: cs*9, height: cs*10)
        ctx.fill(Path(boardRect), with: .color(boardFill))

        // Subtle wood grain lines (horizontal)
        for i in 0..<20 {
            let yy = bp - cs*0.5 + CGFloat(i) * (cs*10/20)
            let grainPath = Path { p in
                p.move(to: CGPoint(x: bp - cs*0.5, y: yy))
                p.addLine(to: CGPoint(x: bp + cs*8.5, y: yy + CGFloat.random(in: -2...2)))
            }
            ctx.stroke(grainPath, with: .color(Color(red: 0.65, green: 0.48, blue: 0.22).opacity(0.18)), lineWidth: 0.5)
        }

        // Outer border (double frame)
        ctx.stroke(Path(boardRect), with: .color(lineCol), lineWidth: 2.5)
        let inner = boardRect.insetBy(dx: 3.5, dy: 3.5)
        ctx.stroke(Path(inner), with: .color(lineCol.opacity(0.6)), lineWidth: 0.8)

        // Horizontal lines
        for row in 0...9 {
            let yy = bp + CGFloat(row) * cs
            let path = Path { p in
                p.move(to: CGPoint(x: bp, y: yy))
                p.addLine(to: CGPoint(x: bp + 8*cs, y: yy))
            }
            ctx.stroke(path, with: .color(lineCol), lineWidth: 1)
        }

        // Vertical lines (inner cols broken at river)
        for col in 0...8 {
            let xx = bp + CGFloat(col) * cs
            if col == 0 || col == 8 {
                let path = Path { p in
                    p.move(to: CGPoint(x: xx, y: bp))
                    p.addLine(to: CGPoint(x: xx, y: bp + 9*cs))
                }
                ctx.stroke(path, with: .color(lineCol), lineWidth: 1)
            } else {
                // top half
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: xx, y: bp))
                    p.addLine(to: CGPoint(x: xx, y: bp + 4*cs))
                }, with: .color(lineCol), lineWidth: 1)
                // bottom half
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: xx, y: bp + 5*cs))
                    p.addLine(to: CGPoint(x: xx, y: bp + 9*cs))
                }, with: .color(lineCol), lineWidth: 1)
            }
        }

        // River
        let riverRect = CGRect(x: bp, y: bp + 4*cs, width: 8*cs, height: cs)
        ctx.fill(Path(riverRect), with: .color(riverFill))

        // Palace diagonals
        drawPalace(ctx: ctx, topRow: 0, bp: bp, cs: cs)
        drawPalace(ctx: ctx, topRow: 7, bp: bp, cs: cs)

        // Position markers
        let markers: [(Int,Int)] = [
            (1,2),(7,2),(1,7),(7,7),
            (0,3),(2,3),(4,3),(6,3),(8,3),
            (0,6),(2,6),(4,6),(6,6),(8,6)
        ]
        for (c, r) in markers { drawMarker(ctx: ctx, col: c, row: r, bp: bp, cs: cs) }
    }

    private func drawPalace(ctx: GraphicsContext, topRow: Int, bp: CGFloat, cs: CGFloat) {
        let x1 = bp + 3*cs, x2 = bp + 5*cs
        let y1 = bp + CGFloat(topRow)*cs
        let y2 = bp + CGFloat(topRow+2)*cs
        ctx.stroke(Path { p in p.move(to: CGPoint(x:x1,y:y1)); p.addLine(to: CGPoint(x:x2,y:y2)) },
                   with: .color(lineCol), lineWidth: 1)
        ctx.stroke(Path { p in p.move(to: CGPoint(x:x2,y:y1)); p.addLine(to: CGPoint(x:x1,y:y2)) },
                   with: .color(lineCol), lineWidth: 1)
    }

    private func drawMarker(ctx: GraphicsContext, col: Int, row: Int, bp: CGFloat, cs: CGFloat) {
        let cx = bp + CGFloat(col)*cs
        let cy = bp + CGFloat(row)*cs
        let ms: CGFloat = cs * 0.12
        let mg: CGFloat = cs * 0.09

        for (sx, sy) in [(1.0,1.0),(1.0,-1.0),(-1.0,1.0),(-1.0,-1.0)] {
            let canH = (sx > 0 && col < 8) || (sx < 0 && col > 0)
            let canV = (sy > 0 && row < 9) || (sy < 0 && row > 0)
            let path = Path { p in
                if canH {
                    p.move(to: CGPoint(x: cx + sx*mg, y: cy + sy*mg))
                    p.addLine(to: CGPoint(x: cx + sx*(mg+ms), y: cy + sy*mg))
                }
                if canV {
                    p.move(to: CGPoint(x: cx + sx*mg, y: cy + sy*mg))
                    p.addLine(to: CGPoint(x: cx + sx*mg, y: cy + sy*(mg+ms)))
                }
            }
            if canH || canV {
                ctx.stroke(path, with: .color(lineCol), lineWidth: 1)
            }
        }
    }
}

// MARK: - PieceView

struct PieceView: View {
    let piece: ChessPiece
    let cellSize: CGFloat
    let isSelected: Bool

    private var sz: CGFloat { cellSize * 0.84 }
    private var isRed: Bool { piece.side == .red }

    // Gradient colors
    private var gradHighlight: Color {
        isRed ? Color(red: 1.0, green: 0.52, blue: 0.32)
              : Color(red: 0.52, green: 0.52, blue: 0.52)
    }
    private var gradMid: Color {
        isRed ? Color(red: 0.72, green: 0.06, blue: 0.04)
              : Color(red: 0.14, green: 0.14, blue: 0.14)
    }
    private var gradShadow: Color {
        isRed ? Color(red: 0.38, green: 0.02, blue: 0.02)
              : Color(red: 0.04, green: 0.04, blue: 0.04)
    }
    private var ringColor: Color {
        isRed ? Color(red: 0.95, green: 0.65, blue: 0.55)
              : Color(red: 0.55, green: 0.55, blue: 0.55)
    }
    private var charColor: Color {
        isRed ? Color(red: 1.0, green: 0.90, blue: 0.85)
              : Color(red: 0.88, green: 0.88, blue: 0.88)
    }

    var body: some View {
        ZStack {
            // Drop shadow disc
            Circle()
                .fill(Color.black.opacity(0.35))
                .frame(width: sz, height: sz)
                .offset(x: 1.5, y: 2.5)
                .blur(radius: 2)

            // Piece body — 3D lacquer gradient
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: gradHighlight, location: 0.0),
                            .init(color: gradMid,       location: 0.45),
                            .init(color: gradShadow,    location: 1.0)
                        ]),
                        center: UnitPoint(x: 0.32, y: 0.28),
                        startRadius: 0,
                        endRadius: sz * 0.55
                    )
                )
                .frame(width: sz, height: sz)

            // Outer ring
            Circle()
                .stroke(ringColor.opacity(0.75), lineWidth: 1.8)
                .frame(width: sz, height: sz)

            // Inner ring (traditional double ring)
            Circle()
                .stroke(ringColor.opacity(0.45), lineWidth: 1.0)
                .frame(width: sz * 0.74, height: sz * 0.74)

            // Specular highlight
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.30), Color.white.opacity(0)],
                        startPoint: .top, endPoint: .center
                    )
                )
                .frame(width: sz * 0.55, height: sz * 0.28)
                .offset(y: -sz * 0.21)

            // Chinese character
            Text(piece.chineseChar)
                .font(.system(size: sz * 0.40, weight: .bold, design: .serif))
                .foregroundColor(charColor)
                .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 0.5)
        }
        .frame(width: sz, height: sz)
        // Selection: golden glow + ring
        .shadow(color: isSelected ? Color.yellow.opacity(0.9) : .clear,
                radius: isSelected ? 10 : 0)
        .overlay(
            Circle()
                .stroke(Color.yellow, lineWidth: isSelected ? 2.5 : 0)
                .frame(width: sz + 5, height: sz + 5)
        )
        .scaleEffect(isSelected ? 1.10 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected)
    }
}

// MARK: - River Label

struct RiverLabelOverlay: View {
    let cellSize: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Text("楚  河")
                .frame(maxWidth: .infinity)
            Text("汉  界")
                .frame(maxWidth: .infinity)
        }
        .font(.system(size: cellSize * 0.30, weight: .semibold, design: .serif))
        .foregroundColor(Color(red: 0.32, green: 0.17, blue: 0.04).opacity(0.75))
        .frame(width: cellSize * 8, height: cellSize)
    }
}
