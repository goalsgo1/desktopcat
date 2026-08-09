import AppKit

/// A tiny hand-authored 16x16 pixel cat, rendered without any external image assets.
enum CatSprite {
    static let gridSize = 16
    private static let pixelScale = 8 // rendered bitmap = 128x128, downscaled with nearest-neighbor filtering

    private static func furColor(for status: CatStatus) -> NSColor {
        switch status {
        case .white: return NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.90, alpha: 1)
        case .red: return NSColor(calibratedRed: 0.82, green: 0.16, blue: 0.16, alpha: 1)
        case .yellow: return NSColor(calibratedRed: 0.95, green: 0.78, blue: 0.20, alpha: 1)
        case .blue: return NSColor(calibratedRed: 0.20, green: 0.45, blue: 0.90, alpha: 1)
        case .green: return NSColor(calibratedRed: 0.20, green: 0.65, blue: 0.30, alpha: 1)
        case .purple: return NSColor(calibratedRed: 0.55, green: 0.35, blue: 0.75, alpha: 1)
        }
    }

    private static func color(for c: Character, furColor: NSColor) -> NSColor? {
        switch c {
        case "K": return NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.11, alpha: 1) // outline
        case "W": return furColor // fur
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

    private static func renderImage(rows: [String], flip: Bool, furColor: NSColor) -> NSImage {
        let side = gridSize * pixelScale
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .none
        for (y, rowStr) in rows.enumerated() {
            let chars = Array(rowStr)
            for x in 0..<gridSize {
                guard x < chars.count, let fill = color(for: chars[x], furColor: furColor) else { continue }
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

    private struct FrameSet {
        let rest: NSImage
        let restFlipped: NSImage
        let blink: NSImage
        let blinkFlipped: NSImage
        let flick: NSImage
        let flickFlipped: NSImage
    }

    private static let frames: [CatStatus: FrameSet] = {
        var result: [CatStatus: FrameSet] = [:]
        for status in CatStatus.allCases {
            let fur = furColor(for: status)
            result[status] = FrameSet(
                rest: renderImage(rows: baseRows, flip: false, furColor: fur),
                restFlipped: renderImage(rows: baseRows, flip: true, furColor: fur),
                blink: renderImage(rows: blinkRows, flip: false, furColor: fur),
                blinkFlipped: renderImage(rows: blinkRows, flip: true, furColor: fur),
                flick: renderImage(rows: tailFlickRows, flip: false, furColor: fur),
                flickFlipped: renderImage(rows: tailFlickRows, flip: true, furColor: fur)
            )
        }
        return result
    }()

    enum Pose {
        case rest, blink, tailFlick
    }

    /// - Parameter status: which color variant to render. Purely cosmetic — doesn't
    ///   affect behavior/movement. Defaults to `.white` (no status assigned).
    static func image(for pose: Pose, flip: Bool, status: CatStatus = .white) -> NSImage {
        let set = frames[status]! // every case is populated in `frames`
        switch pose {
        case .rest: return flip ? set.restFlipped : set.rest
        case .blink: return flip ? set.blinkFlipped : set.blink
        case .tailFlick: return flip ? set.flickFlipped : set.flick
        }
    }
}
