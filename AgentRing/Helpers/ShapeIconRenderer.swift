//
//  ShapeIconRenderer.swift
//  CodexRings
//

import AppKit

final class ShapeIconRenderer {

    static func createHexagonIcon(
        percentage: Double,
        isMonochrome: Bool,
        button: NSStatusBarButton?,
        removeBackground: Bool = false,
        colorOverride: NSColor? = nil
    ) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let center = NSPoint(x: size.width / 2, y: size.height / 2)
        drawHexagonWithPercentage(
            center: center,
            radius: 7.2,
            percentage: percentage,
            isMonochrome: isMonochrome,
            button: button,
            removeBackground: removeBackground,
            colorOverride: colorOverride
        )

        image.unlockFocus()
        image.isTemplate = isMonochrome
        return image
    }

    private static func drawHexagonWithPercentage(
        center: NSPoint,
        radius: CGFloat,
        percentage: Double,
        isMonochrome: Bool,
        button: NSStatusBarButton?,
        removeBackground: Bool,
        colorOverride: NSColor?
    ) {
        let vertices = hexagonVertices(center: center, radius: radius)
        let hexagon = path(for: vertices)

        if !removeBackground && !isMonochrome {
            NSColor.white.withAlphaComponent(0.5).setFill()
            hexagon.fill()
        }

        hexagon.lineWidth = 1.5
        (isMonochrome ? NSColor.black.withAlphaComponent(0.25) : NSColor.gray.withAlphaComponent(0.5)).setStroke()
        hexagon.stroke()

        if percentage > 0 {
            let progress = progressPath(for: vertices)
            let sideLength = radius
            let perimeter = sideLength * 6
            let strokeWidth: CGFloat = 2.5
            let baseLength = perimeter * CGFloat(min(max(percentage, 0), 100) / 100)
            let progressLength = percentage >= 100 ? baseLength : max(0, baseLength - strokeWidth * min(1, CGFloat(percentage / 50)))
            let pattern: [CGFloat] = [progressLength, max(0.01, perimeter - progressLength)]

            progress.setLineDash(pattern, count: pattern.count, phase: percentage >= 100 ? 0 : -strokeWidth / 2)
            progress.lineWidth = strokeWidth
            progress.lineCapStyle = percentage >= 100 ? .butt : .round
            progress.lineJoinStyle = .round

            if isMonochrome {
                NSColor.black.withAlphaComponent(monochromeOpacity(for: percentage)).setStroke()
            } else {
                (colorOverride ?? UsageColorScheme.codexExtraUsageColorAdaptive(percentage, for: button)).setStroke()
            }
            progress.stroke()
        }

        drawPercentageText(percentage, at: center, isMonochrome: isMonochrome)
    }

    private static func hexagonVertices(center: NSPoint, radius: CGFloat) -> [NSPoint] {
        (0..<6).map { index in
            let angle = CGFloat(-60 + index * 60) * .pi / 180
            return NSPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
        }
    }

    private static func path(for vertices: [NSPoint]) -> NSBezierPath {
        let path = NSBezierPath()
        guard let first = vertices.first else { return path }
        path.move(to: first)
        for vertex in vertices.dropFirst() {
            path.line(to: vertex)
        }
        path.close()
        return path
    }

    private static func progressPath(for vertices: [NSPoint]) -> NSBezierPath {
        let path = NSBezierPath()
        guard vertices.count == 6 else { return path }
        let topMidpoint = NSPoint(
            x: (vertices[1].x + vertices[2].x) / 2,
            y: (vertices[1].y + vertices[2].y) / 2
        )

        path.move(to: topMidpoint)
        path.line(to: vertices[1])
        path.line(to: vertices[0])
        path.line(to: vertices[5])
        path.line(to: vertices[4])
        path.line(to: vertices[3])
        path.line(to: vertices[2])
        path.line(to: topMidpoint)
        return path
    }

    private static func drawPercentageText(_ percentage: Double, at center: NSPoint, isMonochrome: Bool) {
        let value = Int(min(max(percentage, 0), 999))
        let text = "\(value)"
        let fontSize: CGFloat = value >= 100 ? 5.0 : 7.2
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: value >= 100 ? .bold : .semibold),
            .foregroundColor: isMonochrome ? NSColor.black : NSColor.black
        ]
        let textSize = text.size(withAttributes: attributes)
        let rect = NSRect(
            x: center.x - textSize.width / 2,
            y: center.y - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: rect, withAttributes: attributes)
    }

    private static func monochromeOpacity(for percentage: Double) -> CGFloat {
        if percentage <= 50 { return 0.8 }
        if percentage <= 75 { return 0.9 }
        return 1.0
    }
}
