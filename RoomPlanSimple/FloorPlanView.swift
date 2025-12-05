/*
See LICENSE folder for this sample's licensing information.

Abstract:
A view that renders a 2D floor plan from CapturedRoom data (Issues #7, #9, #10).
*/

import UIKit
import RoomPlan
import simd

// MARK: - Floor Plan Configuration

enum FloorPlanConfig {
    static let wallColor = UIColor.darkGray
    static let doorColor = UIColor.systemBrown
    static let windowColor = UIColor.systemBlue
    static let objectColor = UIColor.systemOrange
    static let openingColor = UIColor.lightGray
    static let backgroundColor = UIColor.systemBackground
    static let dimensionColor = UIColor.secondaryLabel

    static let wallThickness: CGFloat = 4.0
    static let doorThickness: CGFloat = 2.0
    static let windowThickness: CGFloat = 3.0
    static let objectCornerRadius: CGFloat = 4.0

    static let padding: CGFloat = 40.0
    static let dimensionFontSize: CGFloat = 10.0
    static let labelFontSize: CGFloat = 12.0

    static let metersToPoints: CGFloat = 100.0 // Base scale: 1 meter = 100 points

    // WiFi heatmap colors
    static let wifiExcellentColor = UIColor.systemGreen
    static let wifiGoodColor = UIColor.systemYellow
    static let wifiFairColor = UIColor.systemOrange
    static let wifiPoorColor = UIColor.systemRed
    static let wifiDotRadius: CGFloat = 15.0
    static let wifiDotAlpha: CGFloat = 0.6
}

// MARK: - Floor Plan Element

struct FloorPlanElement {
    let rect: CGRect
    let rotation: CGFloat
    let type: ElementType
    let label: String?

    enum ElementType {
        case wall
        case door
        case window
        case opening
        case object(category: CapturedRoom.Object.Category)
    }
}

// MARK: - Floor Plan Data

struct FloorPlanData {
    let elements: [FloorPlanElement]
    let boundingBox: CGRect
    let roomDimensions: (width: Float, height: Float, depth: Float)

    static func from(_ room: CapturedRoom) -> FloorPlanData {
        var elements: [FloorPlanElement] = []

        // Process walls
        for wall in room.walls {
            let element = FloorPlanElement(
                rect: rectFrom(surface: wall),
                rotation: rotationFrom(transform: wall.transform),
                type: .wall,
                label: nil
            )
            elements.append(element)
        }

        // Process doors
        for door in room.doors {
            let element = FloorPlanElement(
                rect: rectFrom(surface: door),
                rotation: rotationFrom(transform: door.transform),
                type: .door,
                label: nil
            )
            elements.append(element)
        }

        // Process windows
        for window in room.windows {
            let element = FloorPlanElement(
                rect: rectFrom(surface: window),
                rotation: rotationFrom(transform: window.transform),
                type: .window,
                label: nil
            )
            elements.append(element)
        }

        // Process openings
        for opening in room.openings {
            let element = FloorPlanElement(
                rect: rectFrom(surface: opening),
                rotation: rotationFrom(transform: opening.transform),
                type: .opening,
                label: nil
            )
            elements.append(element)
        }

        // Process objects
        for object in room.objects {
            let element = FloorPlanElement(
                rect: rectFrom(object: object),
                rotation: rotationFrom(transform: object.transform),
                type: .object(category: object.category),
                label: labelFor(category: object.category)
            )
            elements.append(element)
        }

        let boundingBox = calculateBoundingBox(elements: elements)
        let dimensions = RoomGeometry.getBoundingBox(from: room)

        return FloorPlanData(
            elements: elements,
            boundingBox: boundingBox,
            roomDimensions: dimensions
        )
    }

    private static func rectFrom(surface: any RoomPlanSurface) -> CGRect {
        let position = surface.transform.columns.3
        let dimensions = surface.dimensions

        // Use X and Z for 2D floor plan (top-down view)
        return CGRect(
            x: CGFloat(position.x - dimensions.x / 2),
            y: CGFloat(position.z - dimensions.z / 2),
            width: CGFloat(dimensions.x),
            height: CGFloat(dimensions.z)
        )
    }

    private static func rectFrom(object: CapturedRoom.Object) -> CGRect {
        let position = object.transform.columns.3
        let dimensions = object.dimensions

        return CGRect(
            x: CGFloat(position.x - dimensions.x / 2),
            y: CGFloat(position.z - dimensions.z / 2),
            width: CGFloat(dimensions.x),
            height: CGFloat(dimensions.z)
        )
    }

    private static func rotationFrom(transform: simd_float4x4) -> CGFloat {
        // Extract Y-axis rotation from transform matrix
        let rotation = atan2(transform.columns.0.z, transform.columns.0.x)
        return CGFloat(rotation)
    }

    private static func calculateBoundingBox(elements: [FloorPlanElement]) -> CGRect {
        guard !elements.isEmpty else { return .zero }

        var minX: CGFloat = .greatestFiniteMagnitude
        var maxX: CGFloat = -.greatestFiniteMagnitude
        var minY: CGFloat = .greatestFiniteMagnitude
        var maxY: CGFloat = -.greatestFiniteMagnitude

        for element in elements {
            minX = min(minX, element.rect.minX)
            maxX = max(maxX, element.rect.maxX)
            minY = min(minY, element.rect.minY)
            maxY = max(maxY, element.rect.maxY)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func labelFor(category: CapturedRoom.Object.Category) -> String {
        switch category {
        case .storage: return "Storage"
        case .refrigerator: return "Fridge"
        case .stove: return "Stove"
        case .bed: return "Bed"
        case .sink: return "Sink"
        case .washerDryer: return "Washer"
        case .toilet: return "Toilet"
        case .bathtub: return "Bathtub"
        case .oven: return "Oven"
        case .dishwasher: return "Dishwasher"
        case .table: return "Table"
        case .sofa: return "Sofa"
        case .chair: return "Chair"
        case .fireplace: return "Fireplace"
        case .television: return "TV"
        case .stairs: return "Stairs"
        @unknown default: return "Object"
        }
    }
}

// MARK: - RoomPlan Surface Protocol

private protocol RoomPlanSurface {
    var transform: simd_float4x4 { get }
    var dimensions: simd_float3 { get }
}

extension CapturedRoom.Surface: RoomPlanSurface {}

// MARK: - Floor Plan View

class FloorPlanView: UIView, UIGestureRecognizerDelegate {

    private var floorPlanData: FloorPlanData?
    private var scale: CGFloat = 1.0
    private var offset: CGPoint = .zero

    // Zoom, pan, and rotation
    private var zoomScale: CGFloat = 1.0
    private var panOffset: CGPoint = .zero
    private var rotationAngle: CGFloat = 0.0
    private var minZoom: CGFloat = 0.5
    private var maxZoom: CGFloat = 4.0

    // WiFi heatmap
    private var wifiSamples: [WiFiSample] = []

    var showDimensions: Bool = true {
        didSet { setNeedsDisplay() }
    }

    var showLabels: Bool = true {
        didSet { setNeedsDisplay() }
    }

    var showWifiHeatmap: Bool = true {
        didSet { setNeedsDisplay() }
    }

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        backgroundColor = FloorPlanConfig.backgroundColor
        contentMode = .redraw
        isUserInteractionEnabled = true

        // Add zoom gesture
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinchGesture)

        // Add pan gesture
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 2
        addGestureRecognizer(panGesture)

        // Add rotation gesture
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        addGestureRecognizer(rotationGesture)

        // Add double-tap to reset zoom
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTapGesture)

        // Enable simultaneous gestures
        pinchGesture.delegate = self
        panGesture.delegate = self
        rotationGesture.delegate = self
    }

    // MARK: - Gesture Handlers

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .changed {
            let newZoom = zoomScale * gesture.scale
            zoomScale = min(max(newZoom, minZoom), maxZoom)
            gesture.scale = 1.0
            setNeedsDisplay()
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .changed {
            let translation = gesture.translation(in: self)
            panOffset.x += translation.x
            panOffset.y += translation.y
            gesture.setTranslation(.zero, in: self)
            setNeedsDisplay()
        }
    }

    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        switch gesture.state {
        case .changed:
            rotationAngle += gesture.rotation
            gesture.rotation = 0.0
            setNeedsDisplay()
        case .began, .ended:
            #if DEBUG
            print("Rotation: \(rotationAngle * 180 / .pi)°")
            #endif
        default:
            break
        }
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        // Reset zoom, pan, and rotation
        UIView.animate(withDuration: 0.3) {
            self.zoomScale = 1.0
            self.panOffset = .zero
            self.rotationAngle = 0.0
            self.setNeedsDisplay()
        }
    }

    // MARK: - Public Methods

    func configure(with room: CapturedRoom) {
        floorPlanData = FloorPlanData.from(room)
        calculateTransform()
        setNeedsDisplay()
    }

    func configure(with room: CapturedRoom, wifiSamples: [WiFiSample]) {
        floorPlanData = FloorPlanData.from(room)
        self.wifiSamples = wifiSamples
        calculateTransform()
        setNeedsDisplay()
    }

    func setWifiSamples(_ samples: [WiFiSample]) {
        self.wifiSamples = samples
        setNeedsDisplay()
    }

    func clear() {
        floorPlanData = nil
        wifiSamples = []
        zoomScale = 1.0
        panOffset = .zero
        setNeedsDisplay()
    }

    func resetZoom() {
        zoomScale = 1.0
        panOffset = .zero
        rotationAngle = 0.0
        setNeedsDisplay()
    }

    // MARK: - Transform Calculation

    private func calculateTransform() {
        guard let data = floorPlanData else { return }

        let availableWidth = bounds.width - FloorPlanConfig.padding * 2
        let availableHeight = bounds.height - FloorPlanConfig.padding * 2

        guard availableWidth > 0, availableHeight > 0 else { return }

        let boundingBox = data.boundingBox
        guard boundingBox.width > 0, boundingBox.height > 0 else { return }

        // Calculate scale to fit room in view
        let scaleX = availableWidth / (boundingBox.width * FloorPlanConfig.metersToPoints)
        let scaleY = availableHeight / (boundingBox.height * FloorPlanConfig.metersToPoints)
        scale = min(scaleX, scaleY)

        // Calculate offset to center room in view
        let scaledWidth = boundingBox.width * FloorPlanConfig.metersToPoints * scale
        let scaledHeight = boundingBox.height * FloorPlanConfig.metersToPoints * scale

        offset = CGPoint(
            x: FloorPlanConfig.padding + (availableWidth - scaledWidth) / 2 - boundingBox.minX * FloorPlanConfig.metersToPoints * scale,
            y: FloorPlanConfig.padding + (availableHeight - scaledHeight) / 2 - boundingBox.minY * FloorPlanConfig.metersToPoints * scale
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        calculateTransform()
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let data = floorPlanData else { return }

        context.saveGState()

        // Apply zoom, pan, and rotation transformations
        context.translateBy(x: bounds.midX + panOffset.x, y: bounds.midY + panOffset.y)
        context.rotate(by: rotationAngle)
        context.scaleBy(x: zoomScale, y: zoomScale)
        context.translateBy(x: -bounds.midX, y: -bounds.midY)

        // Draw WiFi heatmap first (behind floor plan)
        if showWifiHeatmap && !wifiSamples.isEmpty {
            drawWifiHeatmap(in: context)
        }

        // Draw elements by type (walls first, then others on top)
        let walls = data.elements.filter { if case .wall = $0.type { return true } else { return false } }
        let doors = data.elements.filter { if case .door = $0.type { return true } else { return false } }
        let windows = data.elements.filter { if case .window = $0.type { return true } else { return false } }
        let openings = data.elements.filter { if case .opening = $0.type { return true } else { return false } }
        let objects = data.elements.filter { if case .object = $0.type { return true } else { return false } }

        // Draw in order: walls, openings, doors, windows, objects
        walls.forEach { drawElement($0, in: context) }
        openings.forEach { drawElement($0, in: context) }
        doors.forEach { drawElement($0, in: context) }
        windows.forEach { drawElement($0, in: context) }
        objects.forEach { drawElement($0, in: context) }

        // Draw dimensions
        if showDimensions {
            drawDimensions(data: data, in: context)
        }

        context.restoreGState()

        // Draw legend (not affected by zoom/pan)
        if showWifiHeatmap && !wifiSamples.isEmpty {
            drawWifiLegend(in: context)
        }

        // Draw zoom/rotation indicator
        if zoomScale != 1.0 || rotationAngle != 0.0 {
            drawTransformIndicator(in: context)
        }
    }

    // MARK: - WiFi Heatmap Drawing

    private func drawWifiHeatmap(in context: CGContext) {
        for sample in wifiSamples {
            let point = transformPoint(x: sample.position.x, z: sample.position.z)
            let color = colorForSignal(rssi: sample.rssi)
            let radius = FloorPlanConfig.wifiDotRadius

            // Draw gradient circle for each sample
            context.saveGState()

            // Outer glow
            context.setFillColor(color.withAlphaComponent(0.2).cgColor)
            context.fillEllipse(in: CGRect(
                x: point.x - radius * 1.5,
                y: point.y - radius * 1.5,
                width: radius * 3,
                height: radius * 3
            ))

            // Inner dot
            context.setFillColor(color.withAlphaComponent(FloorPlanConfig.wifiDotAlpha).cgColor)
            context.fillEllipse(in: CGRect(
                x: point.x - radius,
                y: point.y - radius,
                width: radius * 2,
                height: radius * 2
            ))

            // Center dot
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: CGRect(
                x: point.x - radius * 0.4,
                y: point.y - radius * 0.4,
                width: radius * 0.8,
                height: radius * 0.8
            ))

            context.restoreGState()
        }
    }

    private func colorForSignal(rssi: Int) -> UIColor {
        switch rssi {
        case -50...0:
            return FloorPlanConfig.wifiExcellentColor
        case -60..<(-50):
            return FloorPlanConfig.wifiGoodColor
        case -70..<(-60):
            return FloorPlanConfig.wifiFairColor
        default:
            return FloorPlanConfig.wifiPoorColor
        }
    }

    private func transformPoint(x: Float, z: Float) -> CGPoint {
        CGPoint(
            x: CGFloat(x) * FloorPlanConfig.metersToPoints * scale + offset.x,
            y: CGFloat(z) * FloorPlanConfig.metersToPoints * scale + offset.y
        )
    }

    private func drawWifiLegend(in context: CGContext) {
        let legendX: CGFloat = 16
        let legendY: CGFloat = bounds.height - 100
        let dotSize: CGFloat = 12
        let spacing: CGFloat = 20

        let items: [(String, UIColor)] = [
            ("Excellent", FloorPlanConfig.wifiExcellentColor),
            ("Good", FloorPlanConfig.wifiGoodColor),
            ("Fair", FloorPlanConfig.wifiFairColor),
            ("Poor", FloorPlanConfig.wifiPoorColor)
        ]

        // Background
        let bgRect = CGRect(x: legendX - 8, y: legendY - 8, width: 90, height: CGFloat(items.count) * spacing + 12)
        context.setFillColor(UIColor.systemBackground.withAlphaComponent(0.9).cgColor)
        context.fill(bgRect)
        context.setStrokeColor(UIColor.separator.cgColor)
        context.setLineWidth(0.5)
        context.stroke(bgRect)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.label
        ]

        for (index, item) in items.enumerated() {
            let y = legendY + CGFloat(index) * spacing

            // Draw colored dot
            context.setFillColor(item.1.cgColor)
            context.fillEllipse(in: CGRect(x: legendX, y: y, width: dotSize, height: dotSize))

            // Draw label
            item.0.draw(at: CGPoint(x: legendX + dotSize + 6, y: y - 1), withAttributes: attributes)
        }
    }

    private func drawTransformIndicator(in context: CGContext) {
        var indicators: [String] = []

        if zoomScale != 1.0 {
            indicators.append(String(format: "%.0f%%", zoomScale * 100))
        }

        if rotationAngle != 0.0 {
            let degrees = Int(rotationAngle * 180 / .pi) % 360
            indicators.append(String(format: "%d°", degrees))
        }

        let text = indicators.joined(separator: " • ")
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let size = text.size(withAttributes: attributes)
        let point = CGPoint(x: bounds.width - size.width - 16, y: bounds.height - size.height - 16)
        text.draw(at: point, withAttributes: attributes)
    }

    private func drawElement(_ element: FloorPlanElement, in context: CGContext) {
        let transformedRect = transformRect(element.rect)

        context.saveGState()

        // Apply rotation around center
        let center = CGPoint(x: transformedRect.midX, y: transformedRect.midY)
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: element.rotation)
        context.translateBy(x: -center.x, y: -center.y)

        switch element.type {
        case .wall:
            drawWall(rect: transformedRect, in: context)
        case .door:
            drawDoor(rect: transformedRect, in: context)
        case .window:
            drawWindow(rect: transformedRect, in: context)
        case .opening:
            drawOpening(rect: transformedRect, in: context)
        case .object(let category):
            drawObject(rect: transformedRect, category: category, label: element.label, in: context)
        }

        context.restoreGState()
    }

    private func transformRect(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.origin.x * FloorPlanConfig.metersToPoints * scale + offset.x,
            y: rect.origin.y * FloorPlanConfig.metersToPoints * scale + offset.y,
            width: rect.width * FloorPlanConfig.metersToPoints * scale,
            height: rect.height * FloorPlanConfig.metersToPoints * scale
        )
    }

    private func drawWall(rect: CGRect, in context: CGContext) {
        context.setFillColor(FloorPlanConfig.wallColor.cgColor)
        context.fill(rect)
    }

    private func drawDoor(rect: CGRect, in context: CGContext) {
        context.setStrokeColor(FloorPlanConfig.doorColor.cgColor)
        context.setLineWidth(FloorPlanConfig.doorThickness)

        // Draw door as an arc (swing indicator)
        let arcRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.width)
        context.addArc(center: CGPoint(x: arcRect.minX, y: arcRect.midY),
                       radius: rect.width,
                       startAngle: -.pi / 2,
                       endAngle: 0,
                       clockwise: false)
        context.strokePath()

        // Draw door line
        context.move(to: CGPoint(x: rect.minX, y: rect.midY))
        context.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        context.strokePath()
    }

    private func drawWindow(rect: CGRect, in context: CGContext) {
        context.setStrokeColor(FloorPlanConfig.windowColor.cgColor)
        context.setLineWidth(FloorPlanConfig.windowThickness)

        // Draw window as double line
        let inset: CGFloat = 2
        context.stroke(rect)
        context.stroke(rect.insetBy(dx: inset, dy: inset))
    }

    private func drawOpening(rect: CGRect, in context: CGContext) {
        context.setStrokeColor(FloorPlanConfig.openingColor.cgColor)
        context.setLineWidth(1.0)
        context.setLineDash(phase: 0, lengths: [4, 4])
        context.stroke(rect)
        context.setLineDash(phase: 0, lengths: [])
    }

    private func drawObject(rect: CGRect, category: CapturedRoom.Object.Category, label: String?, in context: CGContext) {
        let color = colorFor(category: category)
        context.setFillColor(color.withAlphaComponent(0.3).cgColor)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.5)

        let path = UIBezierPath(roundedRect: rect, cornerRadius: FloorPlanConfig.objectCornerRadius)
        context.addPath(path.cgPath)
        context.drawPath(using: .fillStroke)

        // Draw label
        if showLabels, let label = label, rect.width > 20 {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: FloorPlanConfig.labelFontSize, weight: .medium),
                .foregroundColor: color
            ]
            let size = label.size(withAttributes: attributes)
            if size.width < rect.width - 4 {
                let point = CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
                label.draw(at: point, withAttributes: attributes)
            }
        }
    }

    private func colorFor(category: CapturedRoom.Object.Category) -> UIColor {
        switch category {
        case .bed, .sofa, .chair:
            return .systemPurple
        case .table:
            return .systemBrown
        case .storage, .refrigerator, .stove, .oven, .dishwasher, .washerDryer:
            return .systemGray
        case .sink, .toilet, .bathtub:
            return .systemCyan
        case .television:
            return .systemIndigo
        case .fireplace:
            return .systemOrange
        case .stairs:
            return .systemYellow
        @unknown default:
            return FloorPlanConfig.objectColor
        }
    }

    private func drawDimensions(data: FloorPlanData, in context: CGContext) {
        let dims = data.roomDimensions
        guard dims.width > 0, dims.depth > 0 else { return }

        let widthText = String(format: "%.2f m", dims.width)
        let depthText = String(format: "%.2f m", dims.depth)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: FloorPlanConfig.dimensionFontSize),
            .foregroundColor: FloorPlanConfig.dimensionColor
        ]

        // Draw width dimension at bottom
        let widthSize = widthText.size(withAttributes: attributes)
        let widthPoint = CGPoint(
            x: bounds.midX - widthSize.width / 2,
            y: bounds.maxY - FloorPlanConfig.padding / 2 - widthSize.height / 2
        )
        widthText.draw(at: widthPoint, withAttributes: attributes)

        // Draw depth dimension on right side
        let depthSize = depthText.size(withAttributes: attributes)
        context.saveGState()
        context.translateBy(x: bounds.maxX - FloorPlanConfig.padding / 2, y: bounds.midY)
        context.rotate(by: -.pi / 2)
        depthText.draw(at: CGPoint(x: -depthSize.width / 2, y: -depthSize.height / 2), withAttributes: attributes)
        context.restoreGState()
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow pinch, pan, and rotation to work simultaneously
        return true
    }
}
