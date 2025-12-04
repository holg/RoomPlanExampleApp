/*
See LICENSE folder for this sample's licensing information.

Abstract:
Exports floor plan data to SVG and DXF formats.
*/

import Foundation
import UIKit

/// Exports floor plan geometry to CAD-compatible formats
final class FloorPlanExporter {

    // MARK: - Export Formats

    enum ExportFormat: String, CaseIterable {
        case svg = "SVG (Vector Graphics)"
        case dxf = "DXF (AutoCAD)"

        var fileExtension: String {
            switch self {
            case .svg: return "svg"
            case .dxf: return "dxf"
            }
        }
    }

    // MARK: - SVG Export

    /// Export floor plan data to SVG format
    static func exportToSVG(data: FloorPlanData, includeDimensions: Bool = true) -> String {
        let padding: CGFloat = 50
        let scale: CGFloat = 100  // 1 meter = 100 pixels

        let width = data.boundingBox.width * scale + padding * 2
        let height = data.boundingBox.height * scale + padding * 2

        var svg = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg"
             width="\(Int(width))" height="\(Int(height))"
             viewBox="0 0 \(Int(width)) \(Int(height))">
        <title>Floor Plan</title>
        <style>
            .wall { fill: none; stroke: #333333; stroke-width: 8; }
            .door { fill: none; stroke: #8B4513; stroke-width: 4; }
            .window { fill: #87CEEB; stroke: #4169E1; stroke-width: 2; fill-opacity: 0.5; }
            .opening { fill: none; stroke: #999999; stroke-width: 2; stroke-dasharray: 5,5; }
            .object { fill: #E0E0E0; stroke: #666666; stroke-width: 1; }
            .dimension { font-family: Arial, sans-serif; font-size: 12px; fill: #666666; }
            .label { font-family: Arial, sans-serif; font-size: 10px; fill: #333333; text-anchor: middle; }
        </style>
        <g transform="translate(\(padding), \(padding))">

        """

        // Helper to transform coordinates
        func tx(_ x: CGFloat) -> CGFloat {
            return (x - data.boundingBox.minX) * scale
        }
        func ty(_ y: CGFloat) -> CGFloat {
            return (y - data.boundingBox.minY) * scale
        }

        // Draw elements by type
        let walls = data.elements.filter { if case .wall = $0.type { return true } else { return false } }
        let doors = data.elements.filter { if case .door = $0.type { return true } else { return false } }
        let windows = data.elements.filter { if case .window = $0.type { return true } else { return false } }
        let openings = data.elements.filter { if case .opening = $0.type { return true } else { return false } }
        let objects = data.elements.filter { if case .object = $0.type { return true } else { return false } }

        // Walls
        for wall in walls {
            let x = tx(wall.rect.minX)
            let y = ty(wall.rect.minY)
            let w = wall.rect.width * scale
            let h = wall.rect.height * scale
            let cx = x + w / 2
            let cy = y + h / 2
            let rotation = wall.rotation * 180 / .pi

            svg += """
                <rect class="wall" x="\(x)" y="\(y)" width="\(w)" height="\(h)"
                      transform="rotate(\(rotation), \(cx), \(cy))"/>

            """
        }

        // Doors (draw as arc)
        for door in doors {
            let x = tx(door.rect.minX)
            let y = ty(door.rect.minY)
            let w = door.rect.width * scale
            let h = door.rect.height * scale

            svg += """
                <rect class="door" x="\(x)" y="\(y)" width="\(w)" height="\(h)"/>

            """
        }

        // Windows
        for window in windows {
            let x = tx(window.rect.minX)
            let y = ty(window.rect.minY)
            let w = window.rect.width * scale
            let h = window.rect.height * scale

            svg += """
                <rect class="window" x="\(x)" y="\(y)" width="\(w)" height="\(h)"/>

            """
        }

        // Openings
        for opening in openings {
            let x = tx(opening.rect.minX)
            let y = ty(opening.rect.minY)
            let w = opening.rect.width * scale
            let h = opening.rect.height * scale

            svg += """
                <rect class="opening" x="\(x)" y="\(y)" width="\(w)" height="\(h)"/>

            """
        }

        // Objects with labels
        for object in objects {
            let x = tx(object.rect.minX)
            let y = ty(object.rect.minY)
            let w = object.rect.width * scale
            let h = object.rect.height * scale

            svg += """
                <rect class="object" x="\(x)" y="\(y)" width="\(w)" height="\(h)"/>

            """
            if let label = object.label {
                svg += """
                    <text class="label" x="\(x + w/2)" y="\(y + h/2 + 4)">\(label)</text>

                """
            }
        }

        // Dimensions
        if includeDimensions {
            let roomWidth = String(format: "%.2fm", data.roomDimensions.width)
            let roomDepth = String(format: "%.2fm", data.roomDimensions.depth)

            // Bottom dimension (width)
            let bottomY = data.boundingBox.height * scale + 30
            svg += """
                <line x1="0" y1="\(bottomY)" x2="\(data.boundingBox.width * scale)" y2="\(bottomY)"
                      stroke="#666" stroke-width="1" marker-start="url(#arrow)" marker-end="url(#arrow)"/>
                <text class="dimension" x="\(data.boundingBox.width * scale / 2)" y="\(bottomY + 15)" text-anchor="middle">\(roomWidth)</text>

            """

            // Right dimension (depth)
            let rightX = data.boundingBox.width * scale + 30
            svg += """
                <line x1="\(rightX)" y1="0" x2="\(rightX)" y2="\(data.boundingBox.height * scale)"
                      stroke="#666" stroke-width="1"/>
                <text class="dimension" x="\(rightX + 10)" y="\(data.boundingBox.height * scale / 2)"
                      transform="rotate(90, \(rightX + 10), \(data.boundingBox.height * scale / 2))">\(roomDepth)</text>

            """
        }

        svg += """
        </g>
        </svg>
        """

        return svg
    }

    // MARK: - DXF Export

    /// Export floor plan data to DXF format (AutoCAD compatible)
    static func exportToDXF(data: FloorPlanData, includeDimensions: Bool = true) -> String {
        let scale: Float = 1.0  // 1 unit = 1 meter

        var dxf = """
        0
        SECTION
        2
        HEADER
        9
        $ACADVER
        1
        AC1015
        9
        $INSUNITS
        70
        6
        0
        ENDSEC
        0
        SECTION
        2
        TABLES
        0
        TABLE
        2
        LAYER
        70
        5
        0
        LAYER
        2
        WALLS
        70
        0
        62
        7
        6
        CONTINUOUS
        0
        LAYER
        2
        DOORS
        70
        0
        62
        3
        6
        CONTINUOUS
        0
        LAYER
        2
        WINDOWS
        70
        0
        62
        5
        6
        CONTINUOUS
        0
        LAYER
        2
        OBJECTS
        70
        0
        62
        8
        6
        CONTINUOUS
        0
        LAYER
        2
        DIMENSIONS
        70
        0
        62
        1
        6
        CONTINUOUS
        0
        ENDTAB
        0
        ENDSEC
        0
        SECTION
        2
        ENTITIES

        """

        // Helper to offset coordinates from bounding box origin
        func tx(_ x: CGFloat) -> Float {
            return Float(x - data.boundingBox.minX) * scale
        }
        func ty(_ y: CGFloat) -> Float {
            return Float(y - data.boundingBox.minY) * scale
        }

        // Draw walls as polylines (rectangles)
        for wall in data.elements {
            guard case .wall = wall.type else { continue }
            let x1 = tx(wall.rect.minX)
            let y1 = ty(wall.rect.minY)
            let x2 = tx(wall.rect.maxX)
            let y2 = ty(wall.rect.maxY)

            dxf += """
            0
            LWPOLYLINE
            8
            WALLS
            90
            4
            70
            1
            10
            \(x1)
            20
            \(y1)
            10
            \(x2)
            20
            \(y1)
            10
            \(x2)
            20
            \(y2)
            10
            \(x1)
            20
            \(y2)

            """
        }

        // Draw doors
        for door in data.elements {
            guard case .door = door.type else { continue }
            let x1 = tx(door.rect.minX)
            let y1 = ty(door.rect.minY)
            let x2 = tx(door.rect.maxX)
            let y2 = ty(door.rect.maxY)

            dxf += """
            0
            LWPOLYLINE
            8
            DOORS
            90
            4
            70
            1
            10
            \(x1)
            20
            \(y1)
            10
            \(x2)
            20
            \(y1)
            10
            \(x2)
            20
            \(y2)
            10
            \(x1)
            20
            \(y2)

            """
        }

        // Draw windows
        for window in data.elements {
            guard case .window = window.type else { continue }
            let x1 = tx(window.rect.minX)
            let y1 = ty(window.rect.minY)
            let x2 = tx(window.rect.maxX)
            let y2 = ty(window.rect.maxY)

            dxf += """
            0
            LWPOLYLINE
            8
            WINDOWS
            90
            4
            70
            1
            10
            \(x1)
            20
            \(y1)
            10
            \(x2)
            20
            \(y1)
            10
            \(x2)
            20
            \(y2)
            10
            \(x1)
            20
            \(y2)

            """
        }

        // Draw objects
        for object in data.elements {
            if case .object = object.type {
                let x1 = tx(object.rect.minX)
                let y1 = ty(object.rect.minY)
                let x2 = tx(object.rect.maxX)
                let y2 = ty(object.rect.maxY)

                dxf += """
                0
                LWPOLYLINE
                8
                OBJECTS
                90
                4
                70
                1
                10
                \(x1)
                20
                \(y1)
                10
                \(x2)
                20
                \(y1)
                10
                \(x2)
                20
                \(y2)
                10
                \(x1)
                20
                \(y2)

                """

                // Add label as text
                if let label = object.label {
                    let cx = (x1 + x2) / 2
                    let cy = (y1 + y2) / 2
                    dxf += """
                    0
                    TEXT
                    8
                    OBJECTS
                    10
                    \(cx)
                    20
                    \(cy)
                    40
                    0.15
                    1
                    \(label)

                    """
                }
            }
        }

        // Add dimension text
        if includeDimensions {
            let roomWidth = String(format: "%.2f m", data.roomDimensions.width)
            let roomDepth = String(format: "%.2f m", data.roomDimensions.depth)
            let totalWidth = Float(data.boundingBox.width) * scale
            let totalHeight = Float(data.boundingBox.height) * scale

            // Width dimension
            dxf += """
            0
            TEXT
            8
            DIMENSIONS
            10
            \(totalWidth / 2)
            20
            \(-0.3)
            40
            0.2
            1
            \(roomWidth)

            """

            // Depth dimension
            dxf += """
            0
            TEXT
            8
            DIMENSIONS
            10
            \(totalWidth + 0.3)
            20
            \(totalHeight / 2)
            40
            0.2
            1
            \(roomDepth)

            """
        }

        dxf += """
        0
        ENDSEC
        0
        EOF
        """

        return dxf
    }

    // MARK: - Export to File

    /// Export floor plan to file and return URL
    static func export(data: FloorPlanData, format: ExportFormat, includeDimensions: Bool = true) throws -> URL {
        let content: String
        switch format {
        case .svg:
            content = exportToSVG(data: data, includeDimensions: includeDimensions)
        case .dxf:
            content = exportToDXF(data: data, includeDimensions: includeDimensions)
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        let fileName = "FloorPlan_\(timestamp).\(format.fileExtension)"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        return fileURL
    }
}
