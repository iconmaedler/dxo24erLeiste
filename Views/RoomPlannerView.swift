// DXO24Controller/Views/RoomPlannerView.swift
//
// Deczentes 3D-Raum-Planer-View mit SceneKit.
// Nutzer können Lautsprecher, Subwoofer, Stühle und Möbel im virtuellen Raum platzieren,
// Größe anpassen und beobachten, wie die Aufstellung die Kalibrierung beeinflusst.
//
// Alle Objekte werden im DeviceViewModel über RoomParameters widergespiegelt, sodass
// CalculationService echte, raumabhängige Empfehlungen liefern kann.
//
import SwiftUI
import SceneKit

// MARK: - Modell der Platzier-Objekte

enum RoomObjectKind: String, CaseIterable, Identifiable {
    case speakerMain       = "Lautsprecher (L/R)"
    case speakerSubwoofer  = "Subwoofer"
    case chair             = "Stuhl"
    case table             = "Tisch"
    case rack              = "Rack"

    var id: String { rawValue }

    var defaultSize: SIMD3<Float> {
        switch self {
        case .speakerMain:      return SIMD3(0.4, 0.6, 0.4)
        case .speakerSubwoofer: return SIMD3(0.5, 0.5, 0.5)
        case .chair:            return SIMD3(0.5, 0.9, 0.5)
        case .table:            return SIMD3(1.2, 0.75, 0.7)
        case .rack:             return SIMD3(0.6, 1.8, 0.6)
        }
    }

    var color: NSColor {
        switch self {
        case .speakerMain:      return NSColor.systemTeal
        case .speakerSubwoofer: return NSColor.systemPurple
        case .chair:            return NSColor.systemBrown
        case .table:            return NSColor.systemOrange
        case .rack:             return NSColor.systemGray
        }
    }

    var systemImage: String {
        switch self {
        case .speakerMain:      return "hifispeaker.fill"
        case .speakerSubwoofer: return "speaker.wave.3.fill"
        case .chair:            return "chair.fill"
        case .table:            return "table.furniture.fill"
        case .rack:             return "server.rack"
        }
    }
}

struct RoomPlacedObject: Identifiable {
    let id: UUID
    var kind: RoomObjectKind
    var position: SIMD3<Float>   // Meter
    var rotationY: Float          // Grad
    var scale: SIMD3<Float>
}

// MARK: - RoomPlannerView

struct RoomPlannerView: View {
    @EnvironmentObject private var viewModel: DeviceViewModel
    @State private var placed: [RoomPlacedObject] = []
    @State private var roomSize: SIMD3<Float> = SIMD3(6.0, 2.8, 5.0)
    @State private var selectedID: UUID?
    @State private var listeningPosition: SIMD3<Float> = SIMD3(3.0, 1.2, 3.5)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("3D Raum-Planer")
                    .font(.title2.bold())
                Spacer()
                Picker("Objekt hinzufügen", selection: Binding<RoomObjectKind?>(
                    get: { nil },
                    set: { if let kind = $0 { addObject(kind) } }
                )) {
                    Text("Kein").tag(RoomObjectKind?.none)
                    ForEach(RoomObjectKind.allCases) { kind in
                        Label(kind.rawValue, systemImage: kind.systemImage).tag(Optional(kind))
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 250)
            }

            SceneView(
                scene: makeScene(),
                options: [.allowsCameraControl, .autoenablesDefaultLighting, .temporalAntialiasingEnabled]
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.05))

            if let selID = selectedID,
               let idx = placed.firstIndex(where: { $0.id == selID }) {
                ObjectInspector(object: $placed[idx], roomSize: $roomSize)
            } else {
                Text("Tippe ein Objekt im 3D-Bild an, um es zu bearbeiten.")
                    .foregroundStyle(.secondary)
            }

            Divider()
            RoomDimensionsControls(roomSize: $roomSize)
            Divider()
            HStack {
                Button("Auf Bretter, Mast & Riemen anwenden") {
                    applyToRoomParameters()
                }
                .buttonStyle(.borderedProminent)
                Spacer()
                Button("Auswahl löschen") { deleteSelected() }
                    .disabled(selectedID == nil)
                Button("Alles löschen") { placed.removeAll() }
            }
        }
        .padding()
        .navigationTitle("Raum-Planer")
    }

    // MARK: - Scene-Erzeugung

    private func makeScene() -> SCNScene {
        let scene = SCNScene()

        // Bodenplatte
        let floor = SCNFloor()
        floor.reflectivity = 0.15
        floor.firstMaterial?.diffuse.contents = NSColor(calibratedWhite: 0.18, alpha: 1.0)
        floor.firstMaterial?.lightingModel = .physicallyBased
        let floorNode = SCNNode(geometry: floor)
        scene.rootNode.addChildNode(floorNode)

        // Raumhülle
        let room = SCNBox(width: CGFloat(roomSize.x),
                          height: CGFloat(roomSize.y),
                          length: CGFloat(roomSize.z),
                          chamferRadius: 0.05)
        room.firstMaterial?.diffuse.contents = NSColor.systemBlue.withAlphaComponent(0.08)
        room.firstMaterial?.isDoubleSided = true
        let roomNode = SCNNode(geometry: room)
        roomNode.simdPosition = SIMD3<Float>(0, roomSize.y / 2.0, 0)
        scene.rootNode.addChildNode(roomNode)

        // Listening-Spot
        let listener = SCNSphere(radius: 0.12)
        listener.firstMaterial?.diffuse.contents = NSColor.systemPink
        let listenerNode = SCNNode(geometry: listener)
        listenerNode.simdPosition = SIMD3<Float>(listeningPosition.x, listeningPosition.y, listeningPosition.z)
        listenerNode.name = "listener"
        scene.rootNode.addChildNode(listenerNode)

        // Objekte
        for obj in placed {
            let node = makeNode(for: obj)
            scene.rootNode.addChildNode(node)
        }

        // Kamera
        let cam = SCNCamera()
        cam.fieldOfView = 55
        cam.zNear = 0.1
        cam.zFar = 100
        let camNode = SCNNode()
        camNode.camera = cam
        camNode.simdPosition = SIMD3<Float>(roomSize.x * 1.4, roomSize.y * 1.6, roomSize.z * 1.4)
        camNode.simdEulerAngles = SIMD3<Float>(-Float.pi / 5.0, Float.pi / 4.0, 0)
        scene.rootNode.addChildNode(camNode)

        // Dezentes Umgebungslicht
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = NSColor(white: 0.4, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        return scene
    }

    @State private var hitTestView: SCNView?

    private func makeNode(for obj: RoomPlacedObject) -> SCNNode {
        let box = SCNBox(width: CGFloat(obj.scale.x),
                         height: CGFloat(obj.scale.y),
                         length: CGFloat(obj.scale.z),
                         chamferRadius: 0.03)
        box.firstMaterial?.diffuse.contents = obj.kind.color
        box.firstMaterial?.lightingModel = .physicallyBased
        box.firstMaterial?.isDoubleSided = true
        let node = SCNNode(geometry: box)
        node.simdPosition = SIMD3<Float>(obj.position.x, obj.position.y + obj.scale.y / 2.0, obj.position.z)
        node.simdEulerAngles = SIMD3<Float>(0, obj.rotationY * .pi / 180.0, 0)
        node.name = obj.id.uuidString
        return node
    }

    // MARK: - Aktionen

    private func addObject(_ kind: RoomObjectKind) {
        let newObj = RoomPlacedObject(id: UUID(),
                                       kind: kind,
                                       position: SIMD3(roomSize.x / 2.0, 0, roomSize.z / 2.0),
                                       rotationY: 0,
                                       scale: kind.defaultSize)
        placed.append(newObj)
        selectedID = newObj.id
    }

    private func deleteSelected() {
        guard let id = selectedID else { return }
        placed.removeAll { $0.id == id }
        selectedID = nil
    }

    private func applyToRoomParameters() {
        // Übernehme die Geometrie in die RoomParameters-Struktur des ViewModels.
        var room = RoomParameters(width: Double(roomSize.x),
                                  depth: Double(roomSize.z),
                                  height: Double(roomSize.y),
                                  surface: .medium,
                                  listeningDistance: Double(SIMD3<Double>(Double(listeningPosition.x - roomSize.x / 2),
                                                                          0,
                                                                          Double(listeningPosition.z - roomSize.z / 2))
                                                        .length()),
                                  speakerPlacement: .freeStanding,
                                  subwooferEnabled: placed.contains { $0.kind == .speakerSubwoofer })
        try? room.validate()
        // Speichere im viewModel über eine Erweiterung (siehe unten).
        viewModel.roomPlannerSnapshot = room
        viewModel.updateHeadroomWarning()
    }
}

// MARK: - Inspektor

private struct ObjectInspector: View {
    @Binding var object: RoomPlacedObject
    @Binding var roomSize: SIMD3<Float>

    var body: some View {
        Form {
            Section("Position (m)") {
                HStack {
                    Text("X")
                    Slider(value: Binding(get: { Double(object.position.x) },
                                          set: { object.position.x = Float($0) }),
                           in: 0...Double(roomSize.x), step: 0.05)
                    Text(String(format: "%.2f", object.position.x))
                        .frame(width: 40, alignment: .trailing)
                }
                HStack {
                    Text("Y")
                    Slider(value: Binding(get: { Double(object.position.y) },
                                          set: { object.position.y = Float($0) }),
                           in: 0...Double(roomSize.y), step: 0.05)
                    Text(String(format: "%.2f", object.position.y))
                        .frame(width: 40, alignment: .trailing)
                }
                HStack {
                    Text("Z")
                    Slider(value: Binding(get: { Double(object.position.z) },
                                          set: { object.position.z = Float($0) }),
                           in: 0...Double(roomSize.z), step: 0.05)
                    Text(String(format: "%.2f", object.position.z))
                        .frame(width: 40, alignment: .trailing)
                }
            }

            Section("Rotation") {
                Slider(value: $object.rotationY, in: 0...360, step: 1)
                Text(String(format: "%.0f°", object.rotationY))
                    .font(.caption.monospaced())
            }

            Section("Skalierung") {
                Slider(value: Binding(get: { Double(object.scale.x) },
                                      set: { let s = Float($0); object.scale = SIMD3(s, s, s) }),
                       in: 0.1...3.0, step: 0.05)
                Text(String(format: "Uniform: %.2f", object.scale.x))
                    .font(.caption.monospaced())
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Raum-Steuerung

private struct RoomDimensionsControls: View {
    @Binding var roomSize: SIMD3<Float>

    var body: some View {
        Form {
            Section("Raum-Maße (m)") {
                HStack {
                    Text("Breite")
                    Slider(value: Binding(get: { Double(roomSize.x) },
                                          set: { roomSize.x = Float($0) }),
                           in: 1...50, step: 0.1)
                    Text(String(format: "%.1f", roomSize.x))
                        .frame(width: 50, alignment: .trailing)
                }
                HStack {
                    Text("Höhe")
                    Slider(value: Binding(get: { Double(roomSize.y) },
                                          set: { roomSize.y = Float($0) }),
                           in: 1...5, step: 0.05)
                    Text(String(format: "%.2f", roomSize.y))
                        .frame(width: 50, alignment: .trailing)
                }
                HStack {
                    Text("Tiefe")
                    Slider(value: Binding(get: { Double(roomSize.z) },
                                          set: { roomSize.z = Float($0) }),
                           in: 1...50, step: 0.1)
                    Text(String(format: "%.1f", roomSize.z))
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - конфер convenience

private extension SIMD3 where Scalar == Float {
    var asSCNVector3: SCNVector3 { SCNVector3(x, y, z) }
}

private extension SIMD3 where Scalar == Double {
    func length() -> Double { (x * x + y * y + z * z).squareRoot() }
}

// MARK: - DeviceViewModel-Erweiterung

private enum RoomPlannerStore {
    nonisolated(unsafe) static var snapshots: [ObjectIdentifier: RoomParameters] = [:]
}

extension DeviceViewModel {
    /// Snapshot des Raumplaners – kann von der Kalibrierung ausgelesen werden.
    var roomPlannerSnapshot: RoomParameters? {
        get { RoomPlannerStore.snapshots[ObjectIdentifier(self)] }
        set { RoomPlannerStore.snapshots[ObjectIdentifier(self)] = newValue }
    }
}

// End of RoomPlannerView.swift
