// Renders the README's pictures from simulator screenshots.
//
//   swift tools/media/render-media.swift fan <out.png> <back.png> <front.png>
//       Two phones, fanned, on a transparent background (the README gallery).
//   swift tools/media/render-media.swift social <out.png> <left.png> <middle.png> <right.png>
//       GitHub's 1280×640 social preview card.
//
// Screenshots come from `mainline run` or `mainline screenshots` (iPhone 17 Pro size works best).

import AppKit
import SwiftUI

let green = Color(red: 0.247, green: 0.725, blue: 0.314)      // #3FB950
let ink = Color(red: 0.941, green: 0.953, blue: 0.965)        // #F0F3F6
let mute = Color(red: 0.569, green: 0.596, blue: 0.631)       // #9198A1
let night = Color(red: 0.051, green: 0.067, blue: 0.090)      // #0D1117
let track = Color(red: 0.165, green: 0.192, blue: 0.235)      // #2A313C

func load(_ path: String) -> NSImage {
    guard let image = NSImage(contentsOfFile: path) else { fatalError("can't read \(path)") }
    return image
}

/// An iPhone with a screenshot on it: thin bezel, rounded screen, Dynamic Island, soft shadow.
struct Phone: View {
    let screen: NSImage
    var width: CGFloat

    var body: some View {
        let bezel = width * 0.035
        let screenWidth = width - bezel * 2
        let screenHeight = screenWidth * screen.size.height / screen.size.width
        let radius = screenWidth * 0.137
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: radius + bezel, style: .continuous)
                .fill(Color(white: 0.06))
                .overlay(RoundedRectangle(cornerRadius: radius + bezel, style: .continuous)
                    .strokeBorder(Color(white: 0.32), lineWidth: max(1, width * 0.004)))
            Image(nsImage: screen)
                .resizable()
                .frame(width: screenWidth, height: screenHeight)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .padding(.top, bezel)
            Capsule()
                .fill(Color.black)
                .frame(width: screenWidth * 0.313, height: screenWidth * 0.092)
                .padding(.top, bezel + screenWidth * 0.027)
        }
        .frame(width: width, height: screenHeight + bezel * 2)
        .shadow(color: .black.opacity(0.35), radius: width * 0.06, y: width * 0.05)
    }
}

struct Fan: View {
    let back: NSImage
    let front: NSImage

    var body: some View {
        ZStack {
            Phone(screen: back, width: 330)
                .rotationEffect(.degrees(-7))
                .offset(x: -105, y: -10)
            Phone(screen: front, width: 330)
                .rotationEffect(.degrees(5))
                .offset(x: 105, y: 22)
        }
        .frame(width: 760, height: 860)
    }
}

/// The transit line from the hero: stations named after mainline's commands, ending at a phone.
struct Line: View {
    let stations = ["new", "build", "test", "run", "register", "ship"]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(stations.indices, id: \.self) { i in
                VStack(spacing: 12) {
                    ZStack {
                        Rectangle().fill(green).frame(height: 7)
                            .padding(.leading, i == 0 ? 40 : 0)
                        Circle().fill(night).frame(width: 22, height: 22)
                            .overlay(Circle().strokeBorder(green, lineWidth: 5))
                    }
                    .frame(height: 24)
                    Text(stations[i])
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .fixedSize()
                        .foregroundStyle(ink)
                }
                .frame(width: 92)
            }
        }
    }
}

struct Social: View {
    let phones: [NSImage]

    var body: some View {
        ZStack(alignment: .topLeading) {
            night
            // Phones on the right, bleeding off the bottom edge.
            ZStack {
                Phone(screen: phones[0], width: 250).rotationEffect(.degrees(-8)).offset(x: -190, y: 60)
                Phone(screen: phones[2], width: 250).rotationEffect(.degrees(8)).offset(x: 190, y: 60)
                Phone(screen: phones[1], width: 270).offset(y: 20)
            }
            .frame(width: 640, height: 640)
            .offset(x: 645, y: 150)
            VStack(alignment: .leading, spacing: 0) {
                Text("mainline")
                    .font(.system(size: 104, weight: .bold))
                    .tracking(-3)
                    .foregroundStyle(ink)
                Text("Idea → TestFlight,\nfrom the command line.")
                    .font(.system(size: 36, weight: .regular))
                    .foregroundStyle(mute)
                    .lineSpacing(4)
                    .padding(.top, 4)
                Text("Built for AI agents.")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(green)
                    .padding(.top, 6)
                Spacer()
                Line()
                    .padding(.bottom, 64)
            }
            .padding(.leading, 72)
            .padding(.top, 72)
            .frame(width: 700, height: 640, alignment: .topLeading)
        }
        .frame(width: 1280, height: 640)
        .clipped()
    }
}

@MainActor
func write<V: View>(_ view: V, to path: String, scale: CGFloat, opaque: Bool) {
    let renderer = ImageRenderer(content: view)
    renderer.scale = scale
    renderer.isOpaque = opaque
    guard let image = renderer.cgImage else { fatalError("render failed") }
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("encode failed") }
    do { try data.write(to: URL(fileURLWithPath: path)) } catch { fatalError("can't write \(path): \(error)") }
    print(path)
}

let args = CommandLine.arguments
MainActor.assumeIsolated {
    switch (args.count > 1 ? args[1] : "", args.count) {
    case ("fan", 5):
        write(Fan(back: load(args[3]), front: load(args[4])), to: args[2], scale: 2, opaque: false)
    case ("social", 6):
        write(Social(phones: args[3...5].map(load)), to: args[2], scale: 1, opaque: true)
    default:
        FileHandle.standardError.write(Data("usage: render-media.swift fan <out.png> <back.png> <front.png>\n       render-media.swift social <out.png> <left.png> <middle.png> <right.png>\n".utf8))
        exit(64)
    }
}
