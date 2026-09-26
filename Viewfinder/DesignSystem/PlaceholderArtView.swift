import SwiftUI

/// 실제 사진이 없을 때 PlaceholderArt 레시피를 "사진처럼" 그립니다.
/// 하늘 → 해/별 → 실루엣 → 수면/지면 → 전경 → 비네팅·그레인 순서로 쌓습니다.
struct PlaceholderArtView: View {
    let art: PlaceholderArt

    var body: some View {
        Canvas(opaque: true) { context, size in
            ArtRenderer(art: art, size: size).draw(in: &context)
        }
        .accessibilityHidden(true)
    }
}

private struct ArtRenderer {
    let art: PlaceholderArt
    let size: CGSize

    var w: CGFloat { size.width }
    var h: CGFloat { size.height }
    var horizonY: CGFloat { h * CGFloat(art.horizon) }
    var ground: CGFloat { max(h - horizonY, 1) }
    var palette: SkyPalette { art.sky }
    var silhouette: Color { color(palette.silhouette) }

    // MARK: Entry

    func draw(in ctx: inout GraphicsContext) {
        guard w > 1, h > 1 else { return }
        drawUpper(&ctx)
        drawSurface(&ctx)
        for (index, item) in art.foreground.enumerated() {
            drawForeground(item, index: index, &ctx)
        }
        drawFinish(&ctx)
    }

    // MARK: Helpers

    func color(_ hex: UInt32, _ alpha: Double = 1) -> Color { Color(hex: hex, alpha: alpha) }

    /// 두 색을 섞습니다 (t = 0 → a, 1 → b)
    func blend(_ a: UInt32, _ b: UInt32, _ t: Double, alpha: Double = 1) -> Color {
        func channel(_ value: UInt32, _ shift: UInt32) -> Double { Double((value >> shift) & 0xFF) / 255 }
        let r = channel(a, 16) + (channel(b, 16) - channel(a, 16)) * t
        let g = channel(a, 8) + (channel(b, 8) - channel(a, 8)) * t
        let bl = channel(a, 0) + (channel(b, 0) - channel(a, 0)) * t
        return Color(.sRGB, red: r, green: g, blue: bl, opacity: alpha)
    }

    func random(_ salt: UInt64) -> SeededRandom { SeededRandom(seed: art.seed &* 1_000_003 &+ salt) }

    func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }

    var horizonSky: UInt32 { palette.stops.last ?? 0x888888 }

    // MARK: Sky + backdrop (수면 반영에서도 다시 그립니다)

    func drawUpper(_ ctx: inout GraphicsContext) {
        let sky = Path(CGRect(x: 0, y: 0, width: w, height: horizonY + 1))
        ctx.fill(sky, with: .linearGradient(
            Gradient(colors: palette.stops.map { color($0) }),
            startPoint: .zero,
            endPoint: CGPoint(x: 0, y: horizonY)
        ))
        if art.stars { drawStars(&ctx) }
        if art.milkyWay { drawMilkyWay(&ctx) }
        if let celestial = art.celestial { drawCelestial(celestial, &ctx) }
        for (index, item) in art.backdrop.enumerated() {
            drawBackdrop(item, index: index, &ctx)
        }
    }

    func drawStars(_ ctx: inout GraphicsContext) {
        var r = random(11)
        for _ in 0..<170 {
            let x = CGFloat(r.unit()) * w
            let y = CGFloat(pow(r.unit(), 1.3)) * horizonY * 0.97
            let s = CGFloat(r.range(0.4, 1.6))
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)), with: .color(Color.white.opacity(r.range(0.25, 0.9))))
        }
    }

    func drawMilkyWay(_ ctx: inout GraphicsContext) {
        let start = CGPoint(x: w * 0.2, y: horizonY)
        let end = CGPoint(x: w * 0.78, y: 0)
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: w * 0.05))
            var r = random(12)
            for i in 0..<14 {
                let t = CGFloat(i) / 13
                let cx = start.x + (end.x - start.x) * t
                let cy = start.y + (end.y - start.y) * t
                let rx = w * CGFloat(r.range(0.07, 0.12))
                let ry = w * CGFloat(r.range(0.04, 0.07))
                let tint = t < 0.35 ? color(0xE9C9A0, 0.24) : color(0xC9D4F0, 0.15)
                layer.fill(ellipse(cx, cy, rx, ry), with: .color(tint))
            }
        }
        var r = random(13)
        for _ in 0..<260 {
            let t = CGFloat(r.unit())
            let spread = CGFloat(r.range(-1, 1) * r.range(0, 1)) * w * 0.12
            let x = start.x + (end.x - start.x) * t + spread
            let y = start.y + (end.y - start.y) * t + spread * 0.6
            let s = CGFloat(r.range(0.4, 1.3))
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)), with: .color(Color.white.opacity(r.range(0.3, 0.85))))
        }
    }

    func drawCelestial(_ celestial: Celestial, _ ctx: inout GraphicsContext) {
        switch celestial {
        case let .sun(x, y):
            let center = CGPoint(x: w * CGFloat(x), y: h * CGFloat(y))
            let glow = max(w, h) * 0.42
            ctx.fill(ellipse(center.x, center.y, glow, glow), with: .radialGradient(
                Gradient(colors: [color(palette.glow, 0.6), color(palette.glow, 0)]),
                center: center, startRadius: 0, endRadius: glow
            ))
            let r = w * 0.034
            ctx.fill(ellipse(center.x, center.y, r, r), with: .color(color(0xFFF4DC)))
        case let .moon(x, y):
            let center = CGPoint(x: w * CGFloat(x), y: h * CGFloat(y))
            let glow = w * 0.16
            ctx.fill(ellipse(center.x, center.y, glow, glow), with: .radialGradient(
                Gradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0)]),
                center: center, startRadius: 0, endRadius: glow
            ))
            let r = w * 0.022
            ctx.fill(ellipse(center.x, center.y, r, r), with: .color(color(0xF1F3F7)))
        }
    }

    func drawBackdrop(_ item: Backdrop, index: Int, _ ctx: inout GraphicsContext) {
        switch item {
        case let .ridges(layers, height):
            for layerIndex in 0..<max(layers, 1) {
                var r = random(100 + UInt64(index * 10 + layerIndex))
                let depth = Double(layerIndex) / Double(max(layers - 1, 1))
                let peak = h * CGFloat(height) * CGFloat(0.55 + 0.45 * depth)
                var p = Path()
                p.move(to: CGPoint(x: 0, y: horizonY + 1))
                var previous = CGPoint(x: 0, y: horizonY - peak * CGFloat(r.range(0.3, 0.8)))
                p.addLine(to: previous)
                let segments = 9
                for s in 1...segments {
                    let next = CGPoint(x: w * CGFloat(s) / CGFloat(segments), y: horizonY - peak * CGFloat(r.range(0.25, 1.0)))
                    p.addQuadCurve(to: CGPoint(x: (previous.x + next.x) / 2, y: (previous.y + next.y) / 2), control: previous)
                    previous = next
                }
                p.addLine(to: previous)
                p.addLine(to: CGPoint(x: w, y: horizonY + 1))
                p.closeSubpath()
                ctx.fill(p, with: .color(color(palette.silhouette, 0.45 + 0.55 * depth)))
            }

        case let .hills(height):
            var r = random(200 + UInt64(index))
            let phase = r.range(0, 6.28)
            let amplitude = h * CGFloat(height)
            var p = Path()
            p.move(to: CGPoint(x: 0, y: horizonY + 1))
            for i in 0...40 {
                let t = Double(i) / 40
                let y = horizonY - amplitude * CGFloat(0.55 + 0.45 * sin(t * 5.5 + phase))
                p.addLine(to: CGPoint(x: w * CGFloat(t), y: y))
            }
            p.addLine(to: CGPoint(x: w, y: horizonY + 1))
            p.closeSubpath()
            ctx.fill(p, with: .color(color(palette.silhouette, 0.85)))

        case let .volcano(x, width, height):
            let cx = w * CGFloat(x), bw = w * CGFloat(width), vh = h * CGFloat(height)
            let top = horizonY - vh
            var p = Path()
            p.move(to: CGPoint(x: cx - bw / 2, y: horizonY + 1))
            p.addQuadCurve(to: CGPoint(x: cx - bw * 0.26, y: top + vh * 0.08), control: CGPoint(x: cx - bw * 0.36, y: horizonY - vh * 0.2))
            let rim: [(CGFloat, CGFloat)] = [(-0.2, 0), (-0.12, 0.03), (-0.04, -0.01), (0.05, 0.02), (0.14, -0.005), (0.22, 0.04)]
            for (dx, dy) in rim {
                p.addLine(to: CGPoint(x: cx + bw * dx, y: top + vh * dy))
            }
            p.addQuadCurve(to: CGPoint(x: cx + bw / 2, y: horizonY + 1), control: CGPoint(x: cx + bw * 0.38, y: horizonY - vh * 0.25))
            p.closeSubpath()
            ctx.fill(p, with: .color(silhouette))
            // 낮게 이어지는 땅 (성산 지협)
            ctx.fill(Path(CGRect(x: 0, y: horizonY - h * 0.006, width: w, height: h * 0.006 + 1)), with: .color(color(palette.silhouette, 0.9)))

        case let .skyline(lit, height):
            var r = random(300 + UInt64(index))
            var x: CGFloat = 0
            let maxHeight = h * CGFloat(height)
            while x < w {
                let bw = w * CGFloat(r.range(0.03, 0.075))
                let bh = maxHeight * CGFloat(r.range(0.3, 1.0))
                ctx.fill(Path(CGRect(x: x, y: horizonY - bh, width: bw + 1, height: bh + 1)), with: .color(silhouette))
                if lit {
                    let cols = max(1, Int(bw / 4))
                    let rows = max(1, Int(bh / 5))
                    for cx in 0..<cols {
                        for cy in 0..<rows {
                            if r.unit() < 0.3 {
                                let warm = r.unit() < 0.7
                                let rect = CGRect(x: x + 1.5 + CGFloat(cx) * 4, y: horizonY - bh + 2 + CGFloat(cy) * 5, width: 1.6, height: 2.2)
                                ctx.fill(Path(rect), with: .color(warm ? color(0xFFD28A, 0.85) : color(0xE8F0FF, 0.7)))
                            }
                        }
                    }
                }
                x += bw
            }

        case let .tower(x, height, lit):
            let cx = w * CGFloat(x), th = h * CGFloat(height)
            ctx.fill(ellipse(cx, horizonY, w * 0.16, h * 0.035), with: .color(silhouette))
            ctx.fill(Path(CGRect(x: cx - w * 0.007, y: horizonY - th, width: w * 0.014, height: th)), with: .color(silhouette))
            let podY = horizonY - th * 0.78
            ctx.fill(ellipse(cx, podY, w * 0.028, h * 0.012), with: .color(silhouette))
            ctx.fill(Path(CGRect(x: cx - 0.75, y: horizonY - th * 1.14, width: 1.5, height: th * 0.14)), with: .color(silhouette))
            if lit {
                ctx.fill(ellipse(cx, podY, w * 0.07, w * 0.07), with: .radialGradient(
                    Gradient(colors: [color(0xFFE6B0, 0.55), color(0xFFE6B0, 0)]),
                    center: CGPoint(x: cx, y: podY), startRadius: 0, endRadius: w * 0.07
                ))
                ctx.fill(Path(CGRect(x: cx - w * 0.024, y: podY - 1, width: w * 0.048, height: 2)), with: .color(color(0xFFF1C9)))
            }

        case let .bridge(lit):
            let deckY = horizonY - h * 0.03
            ctx.fill(Path(CGRect(x: 0, y: deckY, width: w, height: max(2, h * 0.008))), with: .color(silhouette))
            for i in 0..<9 {
                let px = w * (0.05 + 0.11 * CGFloat(i))
                ctx.fill(Path(CGRect(x: px, y: deckY, width: 2, height: horizonY - deckY + 1)), with: .color(silhouette))
            }
            for towerX in [0.3, 0.7] as [CGFloat] {
                ctx.fill(Path(CGRect(x: w * towerX - 1.5, y: deckY - h * 0.1, width: 3, height: h * 0.1)), with: .color(silhouette))
            }
            var cable = Path()
            cable.move(to: CGPoint(x: 0, y: deckY - h * 0.02))
            cable.addQuadCurve(to: CGPoint(x: w * 0.3, y: deckY - h * 0.1), control: CGPoint(x: w * 0.18, y: deckY - h * 0.015))
            cable.addQuadCurve(to: CGPoint(x: w * 0.7, y: deckY - h * 0.1), control: CGPoint(x: w * 0.5, y: deckY + h * 0.01))
            cable.addQuadCurve(to: CGPoint(x: w, y: deckY - h * 0.02), control: CGPoint(x: w * 0.82, y: deckY - h * 0.015))
            ctx.stroke(cable, with: .color(lit ? color(0xFFE2A8, 0.9) : silhouette), lineWidth: 1.2)
            if lit {
                for i in 0..<44 {
                    let lx = w * CGFloat(i) / 44
                    ctx.fill(ellipse(lx, deckY, 1.2, 1.2), with: .color(color(0xFFF1C9, 0.95)))
                }
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: 3))
                    layer.stroke(cable, with: .color(color(0xFFC46B, 0.6)), lineWidth: 3)
                    layer.fill(Path(CGRect(x: 0, y: deckY - 1, width: w, height: 3)), with: .color(color(0xFFC46B, 0.5)))
                }
            }

        case let .tree(x, scale):
            let cx = w * CGFloat(x), s = CGFloat(scale)
            let baseY = horizonY + h * 0.01
            let th = h * 0.36 * s
            ctx.fill(Path(CGRect(x: cx - w * 0.008 * s, y: baseY - th * 0.45, width: w * 0.016 * s, height: th * 0.45)), with: .color(silhouette))
            var r = random(400 + UInt64(index))
            for _ in 0..<16 {
                let ox = CGFloat(r.range(-0.5, 0.5)) * w * 0.22 * s
                let oy = CGFloat(r.unit()) * th * 0.5
                let rr = CGFloat(r.range(0.05, 0.09)) * w * s
                ctx.fill(ellipse(cx + ox, baseY - th + oy + rr * 0.3, rr, rr * 0.72), with: .color(silhouette))
            }

        case let .pavilion(x, lit):
            let cx = w * CGFloat(x)
            drawPavilion(cx: cx, width: w * 0.34, height: h * 0.1, lit: lit, &ctx)
            drawPavilion(cx: cx + w * 0.3, width: w * 0.2, height: h * 0.065, lit: lit, &ctx)

        case let .lighthouse(x):
            let cx = w * CGFloat(x)
            ctx.fill(ellipse(cx, horizonY, w * 0.14, h * 0.04), with: .color(silhouette))
            let baseY = horizonY - h * 0.03, lh = h * 0.13, bw = w * 0.02
            var body = Path()
            body.move(to: CGPoint(x: cx - bw, y: baseY))
            body.addLine(to: CGPoint(x: cx - bw * 0.65, y: baseY - lh))
            body.addLine(to: CGPoint(x: cx + bw * 0.65, y: baseY - lh))
            body.addLine(to: CGPoint(x: cx + bw, y: baseY))
            body.closeSubpath()
            ctx.fill(body, with: .color(color(0xB5392C)))
            ctx.fill(Path(CGRect(x: cx - bw * 0.8, y: baseY - lh - h * 0.02, width: bw * 1.6, height: h * 0.02)), with: .color(color(0xF2EBDD)))
        }
    }

    func drawPavilion(cx: CGFloat, width pw: CGFloat, height ph: CGFloat, lit: Bool, _ ctx: inout GraphicsContext) {
        let baseY = horizonY
        ctx.fill(Path(CGRect(x: cx - pw * 0.5, y: baseY - ph * 0.18, width: pw, height: ph * 0.18 + 1)), with: .color(silhouette))
        let body = CGRect(x: cx - pw * 0.38, y: baseY - ph * 0.62, width: pw * 0.76, height: ph * 0.44)
        ctx.fill(Path(body), with: .color(lit ? color(0xF5B35C, 0.92) : silhouette))
        if lit {
            for i in 0..<6 {
                let px = body.minX + body.width * CGFloat(i) / 5 - 1
                ctx.fill(Path(CGRect(x: px, y: body.minY, width: 2, height: body.height)), with: .color(color(0x3A1F0C, 0.9)))
            }
            ctx.fill(ellipse(cx, body.midY, pw * 0.7, ph * 0.9), with: .radialGradient(
                Gradient(colors: [color(0xFFB45C, 0.35), color(0xFFB45C, 0)]),
                center: CGPoint(x: cx, y: body.midY), startRadius: 0, endRadius: pw * 0.7
            ))
        }
        var roof = Path()
        roof.move(to: CGPoint(x: cx - pw * 0.56, y: baseY - ph * 0.66))
        roof.addQuadCurve(to: CGPoint(x: cx - pw * 0.3, y: baseY - ph * 0.92), control: CGPoint(x: cx - pw * 0.44, y: baseY - ph * 0.7))
        roof.addLine(to: CGPoint(x: cx + pw * 0.3, y: baseY - ph * 0.92))
        roof.addQuadCurve(to: CGPoint(x: cx + pw * 0.56, y: baseY - ph * 0.66), control: CGPoint(x: cx + pw * 0.44, y: baseY - ph * 0.7))
        roof.addLine(to: CGPoint(x: cx + pw * 0.4, y: baseY - ph * 0.6))
        roof.addLine(to: CGPoint(x: cx - pw * 0.4, y: baseY - ph * 0.6))
        roof.closeSubpath()
        ctx.fill(roof, with: .color(silhouette))
        ctx.fill(Path(CGRect(x: cx - pw * 0.3, y: baseY - ph * 0.97, width: pw * 0.6, height: ph * 0.05)), with: .color(silhouette))
    }

    // MARK: Surface

    func drawSurface(_ ctx: inout GraphicsContext) {
        let rect = CGRect(x: 0, y: horizonY, width: w, height: ground + 1)
        switch art.surface {
        case .sea: drawSea(rect, &ctx)
        case .calmWater: drawReflection(rect, &ctx)
        case let .land(tone): drawLand(tone, rect, &ctx)
        case .teaRows: drawTeaRows(rect, &ctx)
        case let .road(tone): drawRoad(tone, rect, &ctx)
        case .sCurve: drawSCurve(rect, &ctx)
        }
    }

    func drawSea(_ rect: CGRect, _ ctx: inout GraphicsContext) {
        ctx.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [blend(horizonSky, palette.silhouette, 0.35), blend(horizonSky, palette.silhouette, 0.88)]),
            startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY)
        ))
        var r = random(500)
        for _ in 0..<34 {
            let t = CGFloat(pow(r.unit(), 1.6))
            let y = rect.minY + ground * t
            let length = w * CGFloat(r.range(0.05, 0.25)) * (0.4 + t)
            let x = CGFloat(r.unit()) * w
            var line = Path()
            line.move(to: CGPoint(x: x, y: y))
            line.addLine(to: CGPoint(x: x + length, y: y))
            ctx.stroke(line, with: .color(Color.white.opacity(r.range(0.06, 0.16))), lineWidth: 0.5 + 1.2 * t)
        }
        if case let .sun(sx, _)? = art.celestial { drawGlitter(x: w * CGFloat(sx), rect, &ctx) }
    }

    func drawGlitter(x: CGFloat, _ rect: CGRect, _ ctx: inout GraphicsContext) {
        var r = random(510)
        for _ in 0..<40 {
            let t = CGFloat(r.unit())
            let y = rect.minY + ground * t
            let spread = w * 0.03 * (0.3 + t)
            let gx = x + CGFloat(r.range(-1, 1)) * spread
            ctx.fill(Path(CGRect(x: gx, y: y, width: w * 0.02 * (0.3 + t), height: 1.2)), with: .color(color(palette.glow, r.range(0.35, 0.8))))
        }
    }

    func drawReflection(_ rect: CGRect, _ ctx: inout GraphicsContext) {
        ctx.fill(Path(rect), with: .color(blend(horizonSky, palette.silhouette, 0.6)))
        ctx.drawLayer { layer in
            layer.clip(to: Path(rect))
            layer.translateBy(x: 0, y: 2 * horizonY)
            layer.scaleBy(x: 1, y: -1)
            layer.opacity = 0.72
            layer.addFilter(.blur(radius: 1.4))
            drawUpper(&layer)
        }
        ctx.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [Color.black.opacity(0.1), Color.black.opacity(0.45)]),
            startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY)
        ))
        var r = random(520)
        for _ in 0..<14 {
            let y = rect.minY + ground * CGFloat(r.range(0.05, 1))
            let x = CGFloat(r.unit()) * w
            var line = Path()
            line.move(to: CGPoint(x: x, y: y))
            line.addLine(to: CGPoint(x: x + w * CGFloat(r.range(0.1, 0.4)), y: y))
            ctx.stroke(line, with: .color(Color.white.opacity(0.07)), lineWidth: 0.6)
        }
        var shoreline = Path()
        shoreline.move(to: CGPoint(x: 0, y: horizonY))
        shoreline.addLine(to: CGPoint(x: w, y: horizonY))
        ctx.stroke(shoreline, with: .color(color(palette.glow, 0.25)), lineWidth: 0.8)
    }

    func drawLand(_ tone: LandTone, _ rect: CGRect, _ ctx: inout GraphicsContext) {
        let colors: [Color]
        switch tone {
        case .dark: colors = [blend(palette.silhouette, 0x000000, 0.1), blend(palette.silhouette, 0x000000, 0.5)]
        case .green: colors = [color(0x2F4A2B), color(0x1B2B18)]
        case .snow: colors = [color(0xE3E7EC), color(0xB4BDC8)]
        case .field: colors = [blend(0x5A4A2A, palette.silhouette, 0.4), blend(0x2A2114, palette.silhouette, 0.4)]
        }
        ctx.fill(Path(rect), with: .linearGradient(Gradient(colors: colors), startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY)))
        if tone == .field || tone == .snow {
            // 밭 이랑 / 눈 결
            for i in 0..<12 {
                let t = CGFloat(i) / 11
                let y = rect.minY + ground * pow(t, 1.5)
                var p = Path()
                p.move(to: CGPoint(x: -10, y: y))
                p.addQuadCurve(to: CGPoint(x: w + 10, y: y + ground * 0.05), control: CGPoint(x: w * 0.5, y: y - ground * 0.06))
                let lineColor = tone == .snow ? Color.white.opacity(0.35) : Color.black.opacity(0.25)
                ctx.stroke(p, with: .color(lineColor), lineWidth: 0.6 + 1.4 * t)
            }
        }
    }

    func drawTeaRows(_ rect: CGRect, _ ctx: inout GraphicsContext) {
        ctx.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [color(0x5C8448), color(0x223D1E)]),
            startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY)
        ))
        for i in 0..<20 {
            let t = CGFloat(i) / 19
            let y = rect.minY + ground * pow(t, 1.4)
            var p = Path()
            p.move(to: CGPoint(x: -10, y: y))
            p.addCurve(
                to: CGPoint(x: w + 10, y: y + ground * 0.04),
                control1: CGPoint(x: w * 0.3, y: y - ground * 0.1 * (1 - t)),
                control2: CGPoint(x: w * 0.7, y: y + ground * 0.12)
            )
            let stripe = i % 2 == 0 ? color(0x79A85A, 0.9) : color(0x1C3519, 0.9)
            ctx.stroke(p, with: .color(stripe), lineWidth: max(1, ground / 26 * (0.4 + t)))
        }
    }

    func drawRoad(_ tone: TreeTone, _ rect: CGRect, _ ctx: inout GraphicsContext) {
        let vanishing = CGPoint(x: w * 0.5, y: horizonY)
        ctx.fill(Path(rect), with: .color(blend(palette.silhouette, 0x000000, 0.15)))
        var road = Path()
        road.move(to: CGPoint(x: w * 0.26, y: h))
        road.addLine(to: CGPoint(x: vanishing.x - 2, y: vanishing.y))
        road.addLine(to: CGPoint(x: vanishing.x + 2, y: vanishing.y))
        road.addLine(to: CGPoint(x: w * 0.74, y: h))
        road.closeSubpath()
        ctx.fill(road, with: .linearGradient(
            Gradient(colors: [color(0x80766A, 0.9), color(0x2B2724)]),
            startPoint: vanishing, endPoint: CGPoint(x: w / 2, y: h)
        ))

        let treeColors: [UInt32] = tone == .autumn ? [0xC2551C, 0xD9822B, 0x9E3F16] : [0x2F5E2B, 0x3E7336, 0x244A21]
        var r = random(600)
        for side in [-1.0, 1.0] as [CGFloat] {
            for i in 0..<16 {
                let t = CGFloat(pow(Double(i) / 15, 1.8))
                let x = vanishing.x + side * (w * 0.02 + w * 0.5 * t)
                let baseY = vanishing.y + ground * t * 0.95
                let treeHeight = h * 0.06 + h * 0.95 * t
                let treeWidth = treeHeight * 0.28
                var tree = Path()
                tree.move(to: CGPoint(x: x, y: baseY - treeHeight))
                tree.addQuadCurve(to: CGPoint(x: x + treeWidth / 2, y: baseY - treeHeight * 0.1), control: CGPoint(x: x + treeWidth * 0.45, y: baseY - treeHeight * 0.6))
                tree.addLine(to: CGPoint(x: x - treeWidth / 2, y: baseY - treeHeight * 0.1))
                tree.addQuadCurve(to: CGPoint(x: x, y: baseY - treeHeight), control: CGPoint(x: x - treeWidth * 0.45, y: baseY - treeHeight * 0.6))
                ctx.fill(tree, with: .color(color(treeColors[Int(r.unit() * 3) % 3], 0.96)))
                ctx.fill(Path(CGRect(x: x - treeWidth * 0.04, y: baseY - treeHeight * 0.12, width: treeWidth * 0.08, height: treeHeight * 0.12)), with: .color(color(0x2A1D14)))
            }
        }
    }

    func drawSCurve(_ rect: CGRect, _ ctx: inout GraphicsContext) {
        ctx.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [color(0x4A3A2C), color(0x1C1510)]),
            startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY)
        ))
        var r = random(700)
        for _ in 0..<220 {
            let x = CGFloat(r.unit()) * w
            let y = rect.minY + ground * CGFloat(r.unit())
            ctx.fill(Path(CGRect(x: x, y: y, width: 1, height: 1 + 2 * (y - rect.minY) / ground)), with: .color(color(0xB58E5A, 0.25)))
        }
        var river = Path()
        river.move(to: CGPoint(x: w * 0.55, y: h + 4))
        river.addCurve(
            to: CGPoint(x: w * 0.45, y: horizonY + ground * 0.45),
            control1: CGPoint(x: w * 0.95, y: h - ground * 0.25),
            control2: CGPoint(x: w * 0.05, y: horizonY + ground * 0.7)
        )
        river.addCurve(
            to: CGPoint(x: w * 0.52, y: horizonY + 1),
            control1: CGPoint(x: w * 0.85, y: horizonY + ground * 0.25),
            control2: CGPoint(x: w * 0.3, y: horizonY + ground * 0.08)
        )
        ctx.stroke(river, with: .color(color(palette.glow, 0.3)), style: StrokeStyle(lineWidth: w * 0.07, lineCap: .round))
        ctx.stroke(river, with: .color(color(palette.glow, 0.85)), style: StrokeStyle(lineWidth: w * 0.028, lineCap: .round))
    }

    // MARK: Foreground

    func drawForeground(_ item: Foreground, index: Int, _ ctx: inout GraphicsContext) {
        switch item {
        case .rocks:
            var r = random(800 + UInt64(index))
            for _ in 0..<5 {
                let cx = CGFloat(r.unit()) * w
                let ry = h * CGFloat(r.range(0.04, 0.09))
                let rx = ry * CGFloat(r.range(1.4, 2.4))
                let cy = h - ry * CGFloat(r.range(0.2, 0.8))
                var p = Path()
                for k in 0..<9 {
                    let angle = Double(k) / 9 * 2 * .pi
                    let jitter = CGFloat(r.range(0.75, 1.1))
                    let point = CGPoint(x: cx + CGFloat(cos(angle)) * rx * jitter, y: cy + CGFloat(sin(angle)) * ry * jitter)
                    if k == 0 { p.move(to: point) } else { p.addLine(to: point) }
                }
                p.closeSubpath()
                ctx.fill(p, with: .linearGradient(
                    Gradient(colors: [color(0x46663A), color(0x0E120D)]),
                    startPoint: CGPoint(x: cx, y: cy - ry), endPoint: CGPoint(x: cx, y: cy + ry)
                ))
            }

        case let .blossoms(tone, density):
            let colors: [UInt32] = tone == .yellow ? [0xF5D547, 0xE8B92E, 0xFFE680] : [0xF4B6C2, 0xF7C9D3, 0xE58FA3]
            let bandTop = horizonY + ground * 0.25
            ctx.fill(Path(CGRect(x: 0, y: bandTop, width: w, height: h - bandTop)), with: .linearGradient(
                Gradient(colors: [color(0x2E4A22, 0), color(0x2E4A22, 0.85)]),
                startPoint: CGPoint(x: 0, y: bandTop), endPoint: CGPoint(x: 0, y: h)
            ))
            var r = random(900 + UInt64(index))
            let count = Int(240 * density)
            for _ in 0..<count {
                let y = h - ground * CGFloat(pow(r.unit(), 1.8)) * 0.9
                let x = CGFloat(r.unit()) * w
                let scale = 0.4 + (y - horizonY) / ground
                let s = CGFloat(r.range(1.5, 4.5)) * scale
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)), with: .color(color(colors[Int(r.unit() * 3) % 3], r.range(0.6, 0.95))))
            }
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 4))
                var near = random(950 + UInt64(index))
                for _ in 0..<Int(10 * density) {
                    let x = CGFloat(near.unit()) * w
                    let y = h - CGFloat(near.range(0, 0.12)) * h
                    let s = CGFloat(near.range(8, 16))
                    layer.fill(ellipse(x, y, s, s), with: .color(color(colors[0], 0.55)))
                }
            }

        case let .person(x):
            let cx = w * CGFloat(x), baseY = h * 0.99, ph = h * 0.3
            let dark = color(0x0A0A0A)
            ctx.fill(ellipse(cx, baseY - ph + ph * 0.075, ph * 0.075, ph * 0.075), with: .color(dark))
            var body = Path()
            body.move(to: CGPoint(x: cx - ph * 0.12, y: baseY - ph * 0.8))
            body.addQuadCurve(to: CGPoint(x: cx + ph * 0.12, y: baseY - ph * 0.8), control: CGPoint(x: cx, y: baseY - ph * 0.86))
            body.addLine(to: CGPoint(x: cx + ph * 0.09, y: baseY))
            body.addLine(to: CGPoint(x: cx - ph * 0.09, y: baseY))
            body.closeSubpath()
            ctx.fill(body, with: .color(dark))
            ctx.stroke(body, with: .color(color(palette.glow, 0.35)), lineWidth: 0.8)

        case .lightTrails:
            let baseY = horizonY + ground * 0.55
            func trail(_ i: Int) -> Path {
                var p = Path()
                let offset = CGFloat(i) * 2.2
                p.move(to: CGPoint(x: -10, y: baseY + offset * 2))
                p.addCurve(
                    to: CGPoint(x: w + 10, y: baseY - ground * 0.25 + offset),
                    control1: CGPoint(x: w * 0.35, y: baseY + ground * 0.2 + offset),
                    control2: CGPoint(x: w * 0.65, y: baseY - ground * 0.35 + offset)
                )
                return p
            }
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 4))
                for i in 0..<10 {
                    layer.stroke(trail(i), with: .color(i % 2 == 0 ? color(0xFF4B3A, 0.5) : color(0xFFF1C1, 0.45)), lineWidth: 4)
                }
            }
            for i in 0..<10 {
                ctx.stroke(trail(i), with: .color(i % 2 == 0 ? color(0xFF4B3A, 0.85) : color(0xFFF1C1, 0.9)), lineWidth: 1.2)
            }

        case let .fog(level):
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: h * 0.04))
                var r = random(1000 + UInt64(index))
                for _ in 0..<7 {
                    let y = horizonY + CGFloat(r.range(-0.12, 0.1)) * h
                    let bandHeight = h * CGFloat(r.range(0.05, 0.12))
                    let rect = CGRect(x: -w * 0.2 + CGFloat(r.unit()) * w * 0.2, y: y - bandHeight / 2, width: w * 1.4, height: bandHeight)
                    layer.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.28 * level)))
                }
            }

        case .reeds:
            var r = random(1100 + UInt64(index))
            for _ in 0..<170 {
                let x = CGFloat(r.unit()) * w
                let bottom = h + 2
                let height = ground * CGFloat(r.range(0.3, 0.95))
                var p = Path()
                p.move(to: CGPoint(x: x, y: bottom))
                p.addQuadCurve(
                    to: CGPoint(x: x + CGFloat(r.range(-8, 8)), y: bottom - height),
                    control: CGPoint(x: x + CGFloat(r.range(-4, 4)), y: bottom - height * 0.5)
                )
                ctx.stroke(p, with: .color(color(0xC9A36A, r.range(0.35, 0.8))), lineWidth: CGFloat(r.range(0.6, 1.4)))
                ctx.fill(Path(ellipseIn: CGRect(x: x - 2, y: bottom - height - 4, width: 4, height: 8)), with: .color(color(0xE8C99A, 0.5)))
            }
        }
    }

    // MARK: Finish (비네팅 + 필름 그레인)

    func drawFinish(_ ctx: inout GraphicsContext) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(colors: [Color.black.opacity(0), Color.black.opacity(0.36)]),
            center: CGPoint(x: w / 2, y: h / 2),
            startRadius: min(w, h) * 0.35,
            endRadius: max(w, h) * 0.75
        ))
        var r = random(1200)
        let count = min(1400, Int(w * h / 260))
        for _ in 0..<count {
            let x = CGFloat(r.unit()) * w
            let y = CGFloat(r.unit()) * h
            let light = r.unit() < 0.5
            ctx.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(light ? Color.white.opacity(0.06) : Color.black.opacity(0.08)))
        }
    }
}
