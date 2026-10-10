import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// appicon — render a 1024×1024 App Store icon with no alpha channel
// (App Store Connect rejects icons with transparency).
//
//   appicon --out Icon.png --symbol plus.forwardslash.minus --from "#FF7A45" --to "#E63946"
//   appicon --out Icon.png --text T --from "#1D3557" --to "#457B9D" [--fg "#FFFFFF"] [--scale 0.55]

let usage = """
usage: appicon --out <file.png> (--symbol <sf-symbol-name> | --text <chars>)
               [--from <#hex>] [--to <#hex>] [--fg <#hex>] [--scale 0.0–1.0]
"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("appicon: \(message)\n\(usage)\n".utf8))
    exit(64)
}

var options: [String: String] = [:]
var argv = Array(CommandLine.arguments.dropFirst())
while !argv.isEmpty {
    let key = argv.removeFirst()
    guard key.hasPrefix("--"), !argv.isEmpty else { fail("bad argument \(key)") }
    options[String(key.dropFirst(2))] = argv.removeFirst()
}

func color(_ hex: String) -> CGColor {
    let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard digits.count == 6, let value = UInt32(digits, radix: 16) else { fail("invalid color \(hex)") }
    return CGColor(
        srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
        green: CGFloat((value >> 8) & 0xFF) / 255,
        blue: CGFloat(value & 0xFF) / 255,
        alpha: 1)
}

guard let outPath = options["out"] else { fail("--out is required") }
let from = color(options["from"] ?? "#4F46E5")
let to = color(options["to"] ?? "#7C3AED")
let foreground = NSColor(cgColor: color(options["fg"] ?? "#FFFFFF"))!
let scale = CGFloat(Double(options["scale"] ?? "") ?? 0.56)
let size = 1024

// 32-bit RGB with the alpha byte skipped → the PNG is written without an alpha channel.
guard let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
else { fail("could not create bitmap context") }

// Background: diagonal gradient, top-left → bottom-right.
let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [from, to] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

// Foreground glyph, centred.
let glyphBox = CGFloat(size) * scale
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

if let symbolName = options["symbol"] {
    let config = NSImage.SymbolConfiguration(pointSize: glyphBox, weight: .semibold)
    guard let template = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
        .withSymbolConfiguration(config)
    else { fail("unknown SF Symbol '\(symbolName)'") }
    // Tint as a monochrome template so cut-outs (e.g. the plus in plus.circle.fill) stay see-through.
    let symbol = NSImage(size: template.size, flipped: false) { rect in
        template.draw(in: rect)
        foreground.set()
        rect.fill(using: .sourceAtop)
        return true
    }
    // Fit the symbol's aspect ratio inside the glyph box.
    let aspect = symbol.size.width / symbol.size.height
    let w = aspect >= 1 ? glyphBox : glyphBox * aspect
    let h = aspect >= 1 ? glyphBox / aspect : glyphBox
    symbol.draw(in: NSRect(x: (CGFloat(size) - w) / 2, y: (CGFloat(size) - h) / 2, width: w, height: h))
} else if let text = options["text"] {
    let font = NSFont.systemFont(ofSize: glyphBox, weight: .bold)
    let attributed = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: foreground])
    let bounds = attributed.boundingRect(with: .zero, options: [.usesLineFragmentOrigin])
    attributed.draw(at: NSPoint(x: (CGFloat(size) - bounds.width) / 2 - bounds.minX,
                                y: (CGFloat(size) - bounds.height) / 2 - bounds.minY))
} else {
    fail("pass --symbol or --text")
}
NSGraphicsContext.current = nil

guard let image = ctx.makeImage() else { fail("render failed") }
let url = URL(fileURLWithPath: outPath)
try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fail("cannot write \(outPath)")
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fail("cannot write \(outPath)") }
print(outPath)
