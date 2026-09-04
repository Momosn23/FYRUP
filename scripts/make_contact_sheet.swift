#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: make_contact_sheet.swift INPUT_DIRECTORY OUTPUT.png\n", stderr)
    exit(2)
}

let inputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let files = try FileManager.default.contentsOfDirectory(
    at: inputDirectory,
    includingPropertiesForKeys: nil,
    options: [.skipsHiddenFiles]
).filter { $0.pathExtension.lowercased() == "png" }.sorted { $0.lastPathComponent < $1.lastPathComponent }

guard !files.isEmpty, let firstImage = NSImage(contentsOf: files[0]) else {
    fputs("No UI screenshots found in \(inputDirectory.path)\n", stderr)
    exit(3)
}

let columns = 2
let tileWidth: CGFloat = 430
let imageHeight = tileWidth * firstImage.size.height / firstImage.size.width
let titleHeight: CGFloat = 34
let outerPadding: CGFloat = 16
let gap: CGFloat = 16
let tileHeight = titleHeight + imageHeight
let rows = Int(ceil(Double(files.count) / Double(columns)))
let canvasWidth = outerPadding * 2 + CGFloat(columns) * tileWidth + CGFloat(columns - 1) * gap
let canvasHeight = outerPadding * 2 + CGFloat(rows) * tileHeight + CGFloat(rows - 1) * gap
let canvas = NSImage(size: NSSize(width: canvasWidth, height: canvasHeight))

canvas.lockFocus()
NSColor(calibratedWhite: 0.035, alpha: 1).setFill()
NSRect(origin: .zero, size: canvas.size).fill()

let titleStyle = NSMutableParagraphStyle()
titleStyle.alignment = .left
let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
    .foregroundColor: NSColor.white,
    .paragraphStyle: titleStyle
]

for (index, file) in files.enumerated() {
    guard let image = NSImage(contentsOf: file) else { continue }
    let column = index % columns
    let row = index / columns
    let x = outerPadding + CGFloat(column) * (tileWidth + gap)
    let yFromTop = outerPadding + CGFloat(row) * (tileHeight + gap)
    let imageY = canvasHeight - yFromTop - tileHeight
    let titleRect = NSRect(x: x, y: imageY + imageHeight + 5, width: tileWidth, height: titleHeight - 5)
    let imageRect = NSRect(x: x, y: imageY, width: tileWidth, height: imageHeight)

    file.deletingPathExtension().lastPathComponent.draw(in: titleRect, withAttributes: titleAttributes)
    image.draw(in: imageRect, from: .zero, operation: .copy, fraction: 1)
}

canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Could not render contact sheet\n", stderr)
    exit(4)
}

try png.write(to: outputURL, options: .atomic)
print("Created \(outputURL.path) with \(files.count) screenshots")
