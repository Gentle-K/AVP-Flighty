import Foundation
import RealityKit
import UIKit
import simd

@MainActor
struct AircraftOrientationConfig {
    var yawOffsetDegrees: Float
    var pitchOffsetDegrees: Float
    var rollOffsetDegrees: Float
    var scaleMultiplier: Float

    static let a380GLB = AircraftOrientationConfig(
        yawOffsetDegrees: 180,
        pitchOffsetDegrees: 0,
        rollOffsetDegrees: 0,
        scaleMultiplier: 1
    )
}

@MainActor
struct AircraftAssetReport {
    let name: String
    let bounds: SIMD3<Float>
    let materialCount: Int
}

@MainActor
final class AircraftAssetResolver {
    static let shared = AircraftAssetResolver()

    private let assetName = "A380"
    private let assetExtension = "glb"
    private let orientationConfig = AircraftOrientationConfig.a380GLB
    private let targetLongestDimension: Float = 0.26
    private var prototype: Entity?
    private var scaleFactor: Float = 1
    private var visualCenter: SIMD3<Float> = .zero
    private var didLogFailure = false
    private(set) var lastReport: AircraftAssetReport?

    var isAssetAvailable: Bool {
        prototype != nil || loadPrototypeIfNeeded() != nil
    }

    func makeAircraftClone() -> Entity? {
        guard let prototype = loadPrototypeIfNeeded() else { return nil }
        let rawModel = prototype.clone(recursive: true)
        rawModel.name = "AircraftModel_RawA380"
        rawModel.position = -visualCenter

        let modelRoot = Entity()
        modelRoot.name = "AircraftModel"
        modelRoot.scale = SIMD3<Float>(repeating: scaleFactor)
        modelRoot.orientation = staticModelCorrection
        modelRoot.addChild(rawModel)
        return modelRoot
    }

    private var staticModelCorrection: simd_quatf {
        let yaw = degreesToRadians(orientationConfig.yawOffsetDegrees)
        let pitch = degreesToRadians(orientationConfig.pitchOffsetDegrees)
        let roll = degreesToRadians(orientationConfig.rollOffsetDegrees)
        return simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
            * simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
            * simd_quatf(angle: roll, axis: SIMD3<Float>(0, 0, 1))
    }

    private func loadPrototypeIfNeeded() -> Entity? {
        if let prototype { return prototype }

        guard let url = resolveAssetURL() else {
            logFailure("ERROR: User-provided aircraft asset failed to load. Production aircraft rendering disabled. Missing \(assetName).\(assetExtension) in main bundle.")
            return nil
        }

        do {
            let loaded = try GLBAircraftLoader.loadEntity(contentsOf: url)
            loaded.name = "asset-a380-glb-prototype"
            let visualBounds = loaded.visualBounds(relativeTo: nil)
            let bounds = visualBounds.extents
            visualCenter = visualBounds.center
            let longest = max(bounds.x, max(bounds.y, bounds.z))
            if longest > 0.0001 {
                scaleFactor = targetLongestDimension / longest * orientationConfig.scaleMultiplier
            }
            let materialCount = loaded.recursiveMaterialCount
            prototype = loaded
            let report = AircraftAssetReport(name: "\(assetName).\(assetExtension)", bounds: bounds, materialCount: materialCount)
            lastReport = report
            print("Aircraft asset loaded: \(report.name), bounds: \(report.bounds), material count: \(report.materialCount)")
            return loaded
        } catch {
            logFailure("ERROR: User-provided aircraft asset failed to load. Production aircraft rendering disabled. \(assetName).\(assetExtension): \(error.localizedDescription)")
            return nil
        }
    }

    private func resolveAssetURL() -> URL? {
        Bundle.main.url(forResource: assetName, withExtension: assetExtension)
            ?? Bundle.main.url(forResource: assetName, withExtension: assetExtension, subdirectory: "Models")
            ?? Bundle.main.url(forResource: assetName, withExtension: assetExtension, subdirectory: "Resources/Models")
    }

    private func logFailure(_ message: String) {
        guard !didLogFailure else { return }
        didLogFailure = true
        print(message)
    }

    private func degreesToRadians(_ degrees: Float) -> Float {
        degrees * .pi / 180
    }
}

@MainActor
private enum GLBAircraftLoader {
    private enum LoaderError: Error, LocalizedError {
        case invalidHeader
        case missingJSON
        case missingBinary
        case malformedAsset(String)

        var errorDescription: String? {
            switch self {
            case .invalidHeader:
                return "Invalid GLB header."
            case .missingJSON:
                return "Missing GLB JSON chunk."
            case .missingBinary:
                return "Missing GLB binary chunk."
            case .malformedAsset(let reason):
                return "Malformed GLB asset: \(reason)"
            }
        }
    }

    static func loadEntity(contentsOf url: URL) throws -> Entity {
        let data = try Data(contentsOf: url)
        let chunks = try parseChunks(from: data)
        guard let jsonData = chunks.json else { throw LoaderError.missingJSON }
        guard let binary = chunks.binary else { throw LoaderError.missingBinary }
        guard let gltf = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw LoaderError.malformedAsset("JSON root is not an object")
        }

        let root = Entity()
        root.name = "a380-glb-root"
        let materials = try makeMaterials(from: gltf, binary: binary)
        let nodeIndices = sceneNodeIndices(from: gltf)
        for nodeIndex in nodeIndices {
            try appendNode(
                index: nodeIndex,
                parentTransform: matrix_identity_float4x4,
                to: root,
                gltf: gltf,
                binary: binary,
                materials: materials
            )
        }
        return root
    }

    private static func parseChunks(from data: Data) throws -> (json: Data?, binary: Data?) {
        guard data.count >= 12 else { throw LoaderError.invalidHeader }
        let magic = readUInt32(data, offset: 0)
        let version = readUInt32(data, offset: 4)
        guard magic == 0x46546C67, version == 2 else { throw LoaderError.invalidHeader }

        var offset = 12
        var json: Data?
        var binary: Data?
        while offset + 8 <= data.count {
            let chunkLength = Int(readUInt32(data, offset: offset))
            let chunkType = readUInt32(data, offset: offset + 4)
            offset += 8
            guard offset + chunkLength <= data.count else {
                throw LoaderError.malformedAsset("Chunk exceeds file length")
            }
            let chunk = data.subdata(in: offset..<(offset + chunkLength))
            if chunkType == 0x4E4F534A {
                json = chunk
            } else if chunkType == 0x004E4942 {
                binary = chunk
            }
            offset += chunkLength
        }
        return (json, binary)
    }

    private static func appendNode(
        index: Int,
        parentTransform: simd_float4x4,
        to root: Entity,
        gltf: [String: Any],
        binary: Data,
        materials: [any Material]
    ) throws {
        let nodes = try objectArray(named: "nodes", in: gltf)
        guard index >= 0, index < nodes.count else {
            throw LoaderError.malformedAsset("Node index \(index) is out of range")
        }
        let node = nodes[index]
        let worldTransform = parentTransform * localTransformMatrix(from: node)

        if let meshIndex = int("mesh", in: node) {
            let meshEntities = try makeMeshEntities(
                meshIndex: meshIndex,
                transform: worldTransform,
                nodeName: string("name", in: node) ?? "glb-node-\(index)",
                gltf: gltf,
                binary: binary,
                materials: materials
            )
            for meshEntity in meshEntities {
                root.addChild(meshEntity)
            }
        }

        for childIndex in intArray("children", in: node) {
            try appendNode(
                index: childIndex,
                parentTransform: worldTransform,
                to: root,
                gltf: gltf,
                binary: binary,
                materials: materials
            )
        }
    }

    private static func makeMeshEntities(
        meshIndex: Int,
        transform: simd_float4x4,
        nodeName: String,
        gltf: [String: Any],
        binary: Data,
        materials: [any Material]
    ) throws -> [Entity] {
        let meshes = try objectArray(named: "meshes", in: gltf)
        guard meshIndex >= 0, meshIndex < meshes.count else {
            throw LoaderError.malformedAsset("Mesh index \(meshIndex) is out of range")
        }
        let mesh = meshes[meshIndex]
        let primitives = try objectArray(named: "primitives", in: mesh)
        var entities: [Entity] = []

        for (primitiveIndex, primitive) in primitives.enumerated() {
            guard let attributes = primitive["attributes"] as? [String: Any],
                  let positionAccessor = int("POSITION", in: attributes) else {
                continue
            }

            let sourcePositions = try readVec3Accessor(positionAccessor, gltf: gltf, binary: binary)
            guard !sourcePositions.isEmpty else { continue }
            let positions = sourcePositions.map { transformPoint($0, by: transform) }
            let normals = try int("NORMAL", in: attributes).map { accessor in
                try readVec3Accessor(accessor, gltf: gltf, binary: binary).map { transformNormal($0, by: transform) }
            }
            let textureCoordinates = try int("TEXCOORD_0", in: attributes).map { try readVec2Accessor($0, gltf: gltf, binary: binary) }
            let indices = try int("indices", in: primitive).map { try readIndexAccessor($0, gltf: gltf, binary: binary) }
                ?? Array(0..<UInt32(positions.count))

            var descriptor = MeshDescriptor(name: string("name", in: mesh) ?? "A380Primitive\(primitiveIndex)")
            descriptor.positions = MeshBuffers.Positions(positions)
            if let normals, normals.count == positions.count {
                descriptor.normals = MeshBuffers.Normals(normals)
            }
            if let textureCoordinates, textureCoordinates.count == positions.count {
                descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(textureCoordinates)
            }
            descriptor.primitives = .triangles(indices)
            descriptor.materials = .allFaces(0)

            let meshResource = try MeshResource.generate(from: [descriptor])
            let materialIndex = int("material", in: primitive)
            let material = materialIndex.flatMap { index -> (any Material)? in
                guard index >= 0, index < materials.count else { return nil }
                return materials[index]
            } ?? SimpleMaterial(color: .white, roughness: 0.45, isMetallic: false)
            let model = ModelEntity(mesh: meshResource, materials: [material])
            model.name = "\(nodeName)-mesh-\(meshIndex)-primitive-\(primitiveIndex)"
            entities.append(model)
        }

        return entities
    }

    private static func makeMaterials(from gltf: [String: Any], binary: Data) throws -> [any Material] {
        let materialObjects = (try? objectArray(named: "materials", in: gltf)) ?? []
        var textureCache: [Int: TextureResource] = [:]
        return materialObjects.enumerated().map { index, materialObject -> any Material in
            let pbr = materialObject["pbrMetallicRoughness"] as? [String: Any]
            let color = baseColor(from: pbr)
            let roughness = float("roughnessFactor", in: pbr) ?? 0.48
            let metallic = (float("metallicFactor", in: pbr) ?? 0) > 0.5
            var material = SimpleMaterial(color: color, roughness: .float(roughness), isMetallic: metallic)

            if let textureInfo = pbr?["baseColorTexture"] as? [String: Any],
               let textureIndex = int("index", in: textureInfo),
               let texture = try? textureResource(textureIndex: textureIndex, gltf: gltf, binary: binary, cache: &textureCache) {
                material.baseColor = .texture(texture)
            }

            material.triangleFillMode = .fill
            material.faceCulling = .none
            return material
        }
    }

    private static func textureResource(textureIndex: Int, gltf: [String: Any], binary: Data, cache: inout [Int: TextureResource]) throws -> TextureResource {
        if let cached = cache[textureIndex] { return cached }
        let textures = try objectArray(named: "textures", in: gltf)
        let images = try objectArray(named: "images", in: gltf)
        guard textureIndex >= 0, textureIndex < textures.count,
              let source = int("source", in: textures[textureIndex]),
              source >= 0, source < images.count,
              let bufferViewIndex = int("bufferView", in: images[source]) else {
            throw LoaderError.malformedAsset("Texture \(textureIndex) is missing image data")
        }

        let imageBytes = try bufferViewData(bufferViewIndex, gltf: gltf, binary: binary)
        guard let image = UIImage(data: imageBytes), let cgImage = image.cgImage else {
            throw LoaderError.malformedAsset("Texture \(textureIndex) could not be decoded")
        }
        let options = TextureResource.CreateOptions(semantic: .color, mipmapsMode: .allocateAndGenerateAll)
        let resource = try TextureResource(image: cgImage, withName: "A380Texture\(textureIndex)", options: options)
        cache[textureIndex] = resource
        return resource
    }

    private static func readVec3Accessor(_ accessorIndex: Int, gltf: [String: Any], binary: Data) throws -> [SIMD3<Float>] {
        let accessor = try accessorObject(accessorIndex, gltf: gltf)
        guard int("componentType", in: accessor) == 5126, string("type", in: accessor) == "VEC3" else {
            throw LoaderError.malformedAsset("Accessor \(accessorIndex) is not Float VEC3")
        }
        let layout = try accessorLayout(accessor, gltf: gltf, componentCount: 3, componentSize: 4)
        return (0..<layout.count).map { index in
            let offset = layout.offset + index * layout.stride
            return SIMD3<Float>(
                readFloat(binary, offset: offset),
                readFloat(binary, offset: offset + 4),
                readFloat(binary, offset: offset + 8)
            )
        }
    }

    private static func readVec2Accessor(_ accessorIndex: Int, gltf: [String: Any], binary: Data) throws -> [SIMD2<Float>] {
        let accessor = try accessorObject(accessorIndex, gltf: gltf)
        guard int("componentType", in: accessor) == 5126, string("type", in: accessor) == "VEC2" else {
            throw LoaderError.malformedAsset("Accessor \(accessorIndex) is not Float VEC2")
        }
        let layout = try accessorLayout(accessor, gltf: gltf, componentCount: 2, componentSize: 4)
        return (0..<layout.count).map { index in
            let offset = layout.offset + index * layout.stride
            return SIMD2<Float>(
                readFloat(binary, offset: offset),
                1 - readFloat(binary, offset: offset + 4)
            )
        }
    }

    private static func readIndexAccessor(_ accessorIndex: Int, gltf: [String: Any], binary: Data) throws -> [UInt32] {
        let accessor = try accessorObject(accessorIndex, gltf: gltf)
        let componentType = int("componentType", in: accessor) ?? 5123
        let componentSize: Int
        switch componentType {
        case 5121:
            componentSize = 1
        case 5123:
            componentSize = 2
        case 5125:
            componentSize = 4
        default:
            throw LoaderError.malformedAsset("Unsupported index component type \(componentType)")
        }
        let layout = try accessorLayout(accessor, gltf: gltf, componentCount: 1, componentSize: componentSize)
        return (0..<layout.count).map { index in
            let offset = layout.offset + index * layout.stride
            switch componentType {
            case 5121:
                return UInt32(binary[offset])
            case 5123:
                return UInt32(readUInt16(binary, offset: offset))
            default:
                return readUInt32(binary, offset: offset)
            }
        }
    }

    private static func accessorLayout(_ accessor: [String: Any], gltf: [String: Any], componentCount: Int, componentSize: Int) throws -> (offset: Int, stride: Int, count: Int) {
        guard let bufferViewIndex = int("bufferView", in: accessor) else {
            throw LoaderError.malformedAsset("Accessor is missing bufferView")
        }
        let bufferViews = try objectArray(named: "bufferViews", in: gltf)
        guard bufferViewIndex >= 0, bufferViewIndex < bufferViews.count else {
            throw LoaderError.malformedAsset("Buffer view \(bufferViewIndex) is out of range")
        }
        let bufferView = bufferViews[bufferViewIndex]
        let baseOffset = (int("byteOffset", in: bufferView) ?? 0) + (int("byteOffset", in: accessor) ?? 0)
        let stride = int("byteStride", in: bufferView) ?? (componentCount * componentSize)
        let count = int("count", in: accessor) ?? 0
        return (baseOffset, stride, count)
    }

    private static func bufferViewData(_ index: Int, gltf: [String: Any], binary: Data) throws -> Data {
        let bufferViews = try objectArray(named: "bufferViews", in: gltf)
        guard index >= 0, index < bufferViews.count else {
            throw LoaderError.malformedAsset("Buffer view \(index) is out of range")
        }
        let view = bufferViews[index]
        let offset = int("byteOffset", in: view) ?? 0
        let length = int("byteLength", in: view) ?? 0
        guard offset >= 0, length >= 0, offset + length <= binary.count else {
            throw LoaderError.malformedAsset("Buffer view \(index) exceeds binary length")
        }
        return binary.subdata(in: offset..<(offset + length))
    }

    private static func accessorObject(_ index: Int, gltf: [String: Any]) throws -> [String: Any] {
        let accessors = try objectArray(named: "accessors", in: gltf)
        guard index >= 0, index < accessors.count else {
            throw LoaderError.malformedAsset("Accessor \(index) is out of range")
        }
        return accessors[index]
    }

    private static func sceneNodeIndices(from gltf: [String: Any]) -> [Int] {
        guard let scenes = gltf["scenes"] as? [[String: Any]], !scenes.isEmpty else {
            return []
        }
        let sceneIndex = int("scene", in: gltf) ?? 0
        let scene = scenes[min(max(sceneIndex, 0), scenes.count - 1)]
        return intArray("nodes", in: scene)
    }

    private static func localTransformMatrix(from node: [String: Any]) -> simd_float4x4 {
        if let values = floatArray("matrix", in: node), values.count == 16 {
            return simd_float4x4(columns: (
                SIMD4<Float>(values[0], values[1], values[2], values[3]),
                SIMD4<Float>(values[4], values[5], values[6], values[7]),
                SIMD4<Float>(values[8], values[9], values[10], values[11]),
                SIMD4<Float>(values[12], values[13], values[14], values[15])
            ))
        }

        var transform = matrix_identity_float4x4
        if let translation = floatArray("translation", in: node), translation.count == 3 {
            transform = transform * translationMatrix(SIMD3<Float>(translation[0], translation[1], translation[2]))
        }
        if let rotation = floatArray("rotation", in: node), rotation.count == 4 {
            let quaternion = simd_quatf(ix: rotation[0], iy: rotation[1], iz: rotation[2], r: rotation[3])
            transform = transform * rotationMatrix(quaternion)
        }
        if let scale = floatArray("scale", in: node), scale.count == 3 {
            transform = transform * scaleMatrix(SIMD3<Float>(scale[0], scale[1], scale[2]))
        }
        return transform
    }

    private static func translationMatrix(_ translation: SIMD3<Float>) -> simd_float4x4 {
        simd_float4x4(columns: (
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(translation.x, translation.y, translation.z, 1)
        ))
    }

    private static func scaleMatrix(_ scale: SIMD3<Float>) -> simd_float4x4 {
        simd_float4x4(columns: (
            SIMD4<Float>(scale.x, 0, 0, 0),
            SIMD4<Float>(0, scale.y, 0, 0),
            SIMD4<Float>(0, 0, scale.z, 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    }

    private static func rotationMatrix(_ quaternion: simd_quatf) -> simd_float4x4 {
        let length = sqrt(
            quaternion.imag.x * quaternion.imag.x
                + quaternion.imag.y * quaternion.imag.y
                + quaternion.imag.z * quaternion.imag.z
                + quaternion.real * quaternion.real
        )
        guard length > 0.000001 else { return matrix_identity_float4x4 }
        let x = quaternion.imag.x / length
        let y = quaternion.imag.y / length
        let z = quaternion.imag.z / length
        let w = quaternion.real / length

        let xx = x * x
        let yy = y * y
        let zz = z * z
        let xy = x * y
        let xz = x * z
        let yz = y * z
        let wx = w * x
        let wy = w * y
        let wz = w * z

        return simd_float4x4(columns: (
            SIMD4<Float>(1 - 2 * (yy + zz), 2 * (xy + wz), 2 * (xz - wy), 0),
            SIMD4<Float>(2 * (xy - wz), 1 - 2 * (xx + zz), 2 * (yz + wx), 0),
            SIMD4<Float>(2 * (xz + wy), 2 * (yz - wx), 1 - 2 * (xx + yy), 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    }

    private static func transformPoint(_ point: SIMD3<Float>, by transform: simd_float4x4) -> SIMD3<Float> {
        let transformed = transform * SIMD4<Float>(point.x, point.y, point.z, 1)
        let divisor = abs(transformed.w) > 0.000001 ? transformed.w : 1
        return SIMD3<Float>(transformed.x / divisor, transformed.y / divisor, transformed.z / divisor)
    }

    private static func transformNormal(_ normal: SIMD3<Float>, by transform: simd_float4x4) -> SIMD3<Float> {
        let normalTransform = simd_transpose(simd_inverse(transform))
        let transformed = normalTransform * SIMD4<Float>(normal.x, normal.y, normal.z, 0)
        let normalized = simd_normalize(SIMD3<Float>(transformed.x, transformed.y, transformed.z))
        return normalized.x.isFinite && normalized.y.isFinite && normalized.z.isFinite ? normalized : normal
    }

    private static func baseColor(from pbr: [String: Any]?) -> UIColor {
        guard let values = floatArray("baseColorFactor", in: pbr), values.count >= 4 else {
            return .white
        }
        return UIColor(
            red: CGFloat(values[0]),
            green: CGFloat(values[1]),
            blue: CGFloat(values[2]),
            alpha: CGFloat(values[3])
        )
    }

    private static func objectArray(named name: String, in object: [String: Any]) throws -> [[String: Any]] {
        guard let values = object[name] as? [[String: Any]] else {
            throw LoaderError.malformedAsset("Missing object array \(name)")
        }
        return values
    }

    private static func string(_ key: String, in object: [String: Any]?) -> String? {
        object?[key] as? String
    }

    private static func int(_ key: String, in object: [String: Any]?) -> Int? {
        object?[key] as? Int
    }

    private static func float(_ key: String, in object: [String: Any]?) -> Float? {
        if let value = object?[key] as? Float { return value }
        if let value = object?[key] as? Double { return Float(value) }
        if let value = object?[key] as? Int { return Float(value) }
        return nil
    }

    private static func intArray(_ key: String, in object: [String: Any]) -> [Int] {
        guard let values = object[key] as? [Any] else { return [] }
        return values.compactMap { value in
            if let value = value as? Int { return value }
            if let value = value as? Double { return Int(value) }
            return nil
        }
    }

    private static func floatArray(_ key: String, in object: [String: Any]?) -> [Float]? {
        guard let values = object?[key] as? [Any] else { return nil }
        return values.compactMap { value in
            if let value = value as? Float { return value }
            if let value = value as? Double { return Float(value) }
            if let value = value as? Int { return Float(value) }
            return nil
        }
    }

    private static func readFloat(_ data: Data, offset: Int) -> Float {
        Float(bitPattern: readUInt32(data, offset: offset))
    }

    private static func readUInt16(_ data: Data, offset: Int) -> UInt16 {
        data.withUnsafeBytes { rawBuffer in
            UInt16(littleEndian: rawBuffer.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
        }
    }

    private static func readUInt32(_ data: Data, offset: Int) -> UInt32 {
        data.withUnsafeBytes { rawBuffer in
            UInt32(littleEndian: rawBuffer.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
        }
    }
}

private extension Entity {
    var recursiveMaterialCount: Int {
        var count = 0
        if let model = components[ModelComponent.self] {
            count += model.materials.count
        }
        for child in children {
            count += child.recursiveMaterialCount
        }
        return count
    }
}
