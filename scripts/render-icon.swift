// Render the simple geometric SVG source with macOS frameworks only.
import AppKit

final class IconRenderer: NSObject, XMLParserDelegate {
    let context: CGContext
    init(context: CGContext) { self.context = context }

    func parser(_ parser: XMLParser, didStartElement name: String,
                namespaceURI: String?, qualifiedName: String?, attributes a: [String: String]) {
        guard name == "rect" || name == "circle" else { return }
        func number(_ key: String) -> CGFloat { CGFloat(Double(a[key] ?? "0")!) }
        let hex = UInt32(a["fill"]!.dropFirst(), radix: 16)!
        context.setFillColor(CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                                     green: CGFloat((hex >> 8) & 255) / 255,
                                     blue: CGFloat(hex & 255) / 255, alpha: 1))
        if name == "rect" {
            context.addPath(CGPath(roundedRect: CGRect(x: number("x"), y: number("y"),
                width: number("width"), height: number("height")),
                cornerWidth: number("rx"), cornerHeight: number("rx"), transform: nil))
        } else {
            let r = number("r")
            context.addEllipse(in: CGRect(x: number("cx") - r, y: number("cy") - r,
                                         width: r * 2, height: r * 2))
        }
        context.fillPath()
    }
}

let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.translateBy(x: 0, y: 1024)
context.scaleBy(x: 1, y: -1)
let parser = XMLParser(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))!
let renderer = IconRenderer(context: context)
parser.delegate = renderer
guard parser.parse() else { fatalError("Invalid SVG: \(String(describing: parser.parserError))") }
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
