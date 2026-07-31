import AppKit

/// Renders whichever cat sprite frame it's handed. All positioning happens by moving
/// the containing window, so this view never redraws its own geometry.
final class CatView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.magnificationFilter = .nearest
        layer?.contentsGravity = .resize
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSprite(_ image: NSImage) {
        var rect = NSRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return }
        layer?.contents = cgImage
    }
}
