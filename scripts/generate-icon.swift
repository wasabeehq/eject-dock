#!/usr/bin/env swift

import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: generate-icon.swift OUTPUT.icns\n".utf8))
    exit(2)
}

let outputURL = URL(fileURLWithPath: arguments[1]).standardizedFileURL
let fileManager = FileManager.default
let iconsetURL = fileManager.temporaryDirectory
    .appendingPathComponent("EjectDock-\(UUID().uuidString).iconset", isDirectory: true)

try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: iconsetURL) }

func roundedRectPath(in rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func renderIcon(size: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "EjectDockIcon", code: 1)
    }

    bitmap.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        NSGraphicsContext.restoreGraphicsState()
        throw NSError(domain: "EjectDockIcon", code: 2)
    }
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.shouldAntialias = true

    let scale = CGFloat(size) / 1024
    let canvas = CGRect(x: 52 * scale, y: 52 * scale, width: 920 * scale, height: 920 * scale)
    let background = roundedRectPath(in: canvas, radius: 214 * scale)
    let gradient = NSGradient(colors: [
        NSColor(deviceRed: 0.08, green: 0.20, blue: 0.33, alpha: 1),
        NSColor(deviceRed: 0.02, green: 0.47, blue: 0.64, alpha: 1)
    ])!
    gradient.draw(in: background, angle: 72)

    let highlight = NSBezierPath(ovalIn: CGRect(x: 150 * scale, y: 430 * scale, width: 720 * scale, height: 520 * scale))
    NSColor(deviceWhite: 1, alpha: 0.08).setFill()
    highlight.fill()

    let symbol = NSBezierPath()
    symbol.move(to: CGPoint(x: 512 * scale, y: 744 * scale))
    symbol.line(to: CGPoint(x: 292 * scale, y: 426 * scale))
    symbol.curve(to: CGPoint(x: 332 * scale, y: 362 * scale),
                 controlPoint1: CGPoint(x: 270 * scale, y: 394 * scale),
                 controlPoint2: CGPoint(x: 292 * scale, y: 362 * scale))
    symbol.line(to: CGPoint(x: 692 * scale, y: 362 * scale))
    symbol.curve(to: CGPoint(x: 732 * scale, y: 426 * scale),
                 controlPoint1: CGPoint(x: 732 * scale, y: 362 * scale),
                 controlPoint2: CGPoint(x: 754 * scale, y: 394 * scale))
    symbol.close()
    NSColor.white.setFill()
    symbol.fill()

    let ejectBar = roundedRectPath(
        in: CGRect(x: 272 * scale, y: 236 * scale, width: 480 * scale, height: 82 * scale),
        radius: 41 * scale
    )
    ejectBar.fill()

    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "EjectDockIcon", code: 3)
    }
    return png
}

let files: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in files {
    try renderIcon(size: size).write(to: iconsetURL.appendingPathComponent(name))
}

try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else {
    throw NSError(domain: "EjectDockIcon", code: Int(process.terminationStatus))
}

print("Application icon generated: \(outputURL.path)")
