import AppKit

/// A tiny hand-authored 16x16 pixel cat, rendered without any external image assets.
enum CatSprite {
    static let gridSize = 16
    private static let pixelScale = 8 // rendered bitmap = 128x128, downscaled with nearest-neighbor filtering

    private static func color(for c: Character) -> NSColor? {
        switch c {
        case "K": return NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.11, alpha: 1) // outline
        case "W": return NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.90, alpha: 1) // fur
        case "P": return NSColor(calibratedRed: 0.95, green: 0.65, blue: 0.70, alpha: 1) // nose
        default: return nil
        }
    }

    // Base pose: sitting, facing the viewer. Rows top -> bottom, 16 chars each.
    private static let baseRows: [String] = [
        "....KK....KK....",
        "...KWWK..KWWK...",
        "..KWWWWWWWWWWK..",
        ".KWWWWWWWWWWWWK.",
        ".KWWWKWWWWKWWWK.",
        ".KWWWWWPPWWWWWK.",
        ".KWWWWWWWWWWWWK.",
        "..KWWWWWWWWWWK..",
        "...KWWWWWWWWK...",
        ".KWWWWWWWWWWWWK.",
        ".KWWWWKWWKWWWWK.",
        "..KWWWWKKWWWWK..",
        "...KWWWWWWWWK...",
        ".............KW.",
        "................",
        "................",
    ].map { fixLength($0) }

    private static var blinkRows: [String] = {
        var rows = baseRows
        rows[4] = fixLength(".KWWWWWWWWWWWWK.") // eyes closed
        return rows
    }()

    private static var tailFlickRows: [String] = {
        var rows = baseRows
        rows[13] = fixLength("..............KW") // tail nub shifted
        return rows
    }()

    // Defensive: guarantee every row is exactly `gridSize` characters, padding/truncating as needed.
    private static func fixLength(_ row: String) -> String {
        var chars = Array(row)
        if chars.count < gridSize {
            chars.append(contentsOf: Array(repeating: Character("."), count: gridSize - chars.count))
        } else if chars.count > gridSize {
            chars = Array(chars.prefix(gridSize))
        }
        return String(chars)
    }

    private static func renderImage(rows: [String], flip: Bool) -> NSImage {
        let side = gridSize * pixelScale
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .none
        for (y, rowStr) in rows.enumerated() {
            let chars = Array(rowStr)
            for x in 0..<gridSize {
                guard x < chars.count, let fill = color(for: chars[x]) else { continue }
                let drawX = flip ? (gridSize - 1 - x) : x
                let drawY = gridSize - 1 - y
                fill.setFill()
                NSRect(x: drawX * pixelScale, y: drawY * pixelScale, width: pixelScale, height: pixelScale).fill()
            }
        }
        image.unlockFocus()
        return image
    }

    // MARK: - Cached frames

    private static let restNormal = renderImage(rows: baseRows, flip: false)
    private static let restFlipped = renderImage(rows: baseRows, flip: true)
    private static let blinkNormal = renderImage(rows: blinkRows, flip: false)
    private static let blinkFlipped = renderImage(rows: blinkRows, flip: true)
    private static let flickNormal = renderImage(rows: tailFlickRows, flip: false)
    private static let flickFlipped = renderImage(rows: tailFlickRows, flip: true)

    enum Pose {
        case rest, blink, tailFlick
    }

    static func image(for pose: Pose, flip: Bool) -> NSImage {
        switch pose {
        case .rest: return flip ? restFlipped : restNormal
        case .blink: return flip ? blinkFlipped : blinkNormal
        case .tailFlick: return flip ? flickFlipped : flickNormal
        }
    }
}
