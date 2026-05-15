#!/usr/bin/env python3
"""Convert this project's embedded GLB aircraft asset into a USDZ package.

The script intentionally covers the GLB subset used by A380.glb:
triangle meshes with POSITION/NORMAL/TEXCOORD_0 attributes, embedded PNG
textures, and simple PBR base-color materials. It avoids third-party runtime
dependencies so the asset pipeline is reproducible on the local Xcode machine.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Iterable


COMPONENT_FORMATS = {
    5120: ("b", 1),
    5121: ("B", 1),
    5122: ("h", 2),
    5123: ("H", 2),
    5125: ("I", 4),
    5126: ("f", 4),
}

TYPE_COMPONENTS = {
    "SCALAR": 1,
    "VEC2": 2,
    "VEC3": 3,
    "VEC4": 4,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--asset-name", default="A380Complete")
    args = parser.parse_args()

    gltf, binary = read_glb(args.input)
    with tempfile.TemporaryDirectory(prefix="a380_usdz_") as temp_dir:
        temp = Path(temp_dir)
        texture_files = extract_images(gltf, binary, temp)
        usda_path = temp / f"{args.asset_name}.usda"
        write_usda(gltf, binary, texture_files, usda_path, args.asset_name)

        if not run(["usdchecker", str(usda_path)], allow_failure=True):
            print("warning: usdchecker reported issues for intermediate USDA", file=sys.stderr)

        usdc_path = temp / f"{args.asset_name}.usdc"
        run(["usdcat", str(usda_path), "-o", str(usdc_path)])

        args.output.parent.mkdir(parents=True, exist_ok=True)
        if args.output.exists():
            args.output.unlink()
        run(["usdzip", str(args.output), str(usdc_path), *map(str, texture_files)])

    return 0


def read_glb(path: Path) -> tuple[dict, bytes]:
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF" or version != 2 or length != len(data):
        raise ValueError(f"{path} is not a valid GLB v2 file")

    offset = 12
    gltf = None
    binary = None
    while offset < len(data):
        chunk_length, chunk_type = struct.unpack_from("<I4s", data, offset)
        offset += 8
        chunk = data[offset : offset + chunk_length]
        offset += chunk_length
        if chunk_type == b"JSON":
            gltf = json.loads(chunk.decode("utf-8"))
        elif chunk_type == b"BIN\0":
            binary = chunk

    if gltf is None or binary is None:
        raise ValueError(f"{path} must contain JSON and BIN chunks")
    return gltf, binary


def extract_images(gltf: dict, binary: bytes, temp: Path) -> list[Path]:
    texture_files: list[Path] = []
    for index, image in enumerate(gltf.get("images", [])):
        view = gltf["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        end = start + view["byteLength"]
        ext = ".png" if image.get("mimeType") == "image/png" else ".bin"
        output = temp / f"texture_{index:02d}{ext}"
        output.write_bytes(binary[start:end])
        texture_files.append(output)
    return texture_files


def write_usda(gltf: dict, binary: bytes, texture_files: list[Path], output: Path, asset_name: str) -> None:
    meshes = gltf.get("meshes", [])
    materials = gltf.get("materials", [])
    nodes = gltf.get("nodes", [])
    scene_index = gltf.get("scene", 0)
    scene_nodes = gltf.get("scenes", [{}])[scene_index].get("nodes", [])
    root_name = sanitize_identifier(asset_name)

    node_matrices: dict[int, list[list[float]]] = {}

    def walk(node_index: int, parent: list[list[float]]) -> None:
        node = nodes[node_index]
        local = node_matrix(node)
        current = matrix_multiply(parent, local)
        node_matrices[node_index] = current
        for child in node.get("children", []):
            walk(child, current)

    for root in scene_nodes:
        walk(root, identity_matrix())

    with output.open("w", encoding="utf-8") as handle:
        handle.write("#usda 1.0\n")
        handle.write("(\n")
        handle.write(f'    defaultPrim = "{root_name}"\n')
        handle.write("    metersPerUnit = 1\n")
        handle.write("    upAxis = \"Y\"\n")
        handle.write(")\n\n")

        handle.write(f'def Xform "{root_name}"\n')
        handle.write("{\n")
        handle.write('    def Scope "Looks"\n')
        handle.write("    {\n")
        for material_index, material in enumerate(materials):
            write_material(handle, gltf, material, material_index, texture_files, root_name)
        handle.write("    }\n\n")

        for node_index, node in enumerate(nodes):
            if "mesh" not in node:
                continue
            mesh = meshes[node["mesh"]]
            transform = node_matrices.get(node_index, identity_matrix())
            normal_transform = normal_matrix(transform)
            for primitive_index, primitive in enumerate(mesh.get("primitives", [])):
                mesh_name = sanitize_identifier(f"{node.get('name', 'Node')}_{primitive_index}")
                write_mesh(handle, gltf, binary, primitive, mesh_name, transform, normal_transform, root_name)
        handle.write("}\n")


def write_material(handle, gltf: dict, material: dict, material_index: int, texture_files: list[Path], root_name: str) -> None:
    material_name = sanitize_identifier(material.get("name") or f"Material_{material_index}")
    pbr = material.get("pbrMetallicRoughness", {})
    base = pbr.get("baseColorFactor", [1, 1, 1, 1])
    roughness = pbr.get("roughnessFactor", 0.45)
    metallic = pbr.get("metallicFactor", 0)

    handle.write(f'        def Material "{material_name}"\n')
    handle.write("        {\n")
    handle.write(f'            token outputs:surface.connect = </{root_name}/Looks/{material_name}/PreviewSurface.outputs:surface>\n')
    handle.write(f'            def Shader "PreviewSurface"\n')
    handle.write("            {\n")
    handle.write('                uniform token info:id = "UsdPreviewSurface"\n')
    handle.write(f"                color3f inputs:diffuseColor = ({fmt(base[0])}, {fmt(base[1])}, {fmt(base[2])})\n")
    handle.write(f"                float inputs:opacity = {fmt(base[3] if len(base) > 3 else 1)}\n")
    handle.write(f"                float inputs:roughness = {fmt(roughness)}\n")
    handle.write(f"                float inputs:metallic = {fmt(metallic)}\n")

    texture_info = pbr.get("baseColorTexture")
    if texture_info is not None:
        texture = gltf["textures"][texture_info["index"]]
        image_index = texture["source"]
        texture_name = texture_files[image_index].name
        handle.write(f'                color3f inputs:diffuseColor.connect = </{root_name}/Looks/{material_name}/BaseColor.outputs:rgb>\n')

    handle.write("                token outputs:surface\n")
    handle.write("            }\n")

    if texture_info is not None:
        texture = gltf["textures"][texture_info["index"]]
        image_index = texture["source"]
        texture_name = texture_files[image_index].name
        handle.write('                def Shader "BaseColor"\n')
        handle.write("            {\n")
        handle.write('                    uniform token info:id = "UsdUVTexture"\n')
        handle.write(f'                    asset inputs:file = @{texture_name}@\n')
        handle.write('                    token inputs:sourceColorSpace = "sRGB"\n')
        handle.write(f'                    float2 inputs:st.connect = </{root_name}/Looks/{material_name}/PrimvarReader.outputs:result>\n')
        handle.write("                    color3f outputs:rgb\n")
        handle.write("            }\n")
        handle.write('                def Shader "PrimvarReader"\n')
        handle.write("            {\n")
        handle.write('                    uniform token info:id = "UsdPrimvarReader_float2"\n')
        handle.write('                    string inputs:varname = "st"\n')
        handle.write("                    float2 outputs:result\n")
        handle.write("            }\n")

    handle.write("        }\n")


def write_mesh(
    handle,
    gltf: dict,
    binary: bytes,
    primitive: dict,
    mesh_name: str,
    transform: list[list[float]],
    normal_transform: list[list[float]],
    root_name: str,
) -> None:
    if primitive.get("mode", 4) != 4:
        raise ValueError(f"Only triangle primitives are supported: {mesh_name}")

    attributes = primitive.get("attributes", {})
    positions = [transform_point(transform, value) for value in read_accessor(gltf, binary, attributes["POSITION"])]
    normals = [normalize(transform_vector(normal_transform, value)) for value in read_accessor(gltf, binary, attributes["NORMAL"])]
    texcoords = read_accessor(gltf, binary, attributes["TEXCOORD_0"])
    indices = list(read_accessor(gltf, binary, primitive["indices"]))
    material_index = primitive.get("material", 0)
    material_name = sanitize_identifier(gltf["materials"][material_index].get("name") or f"Material_{material_index}")

    handle.write(f'    def Mesh "{mesh_name}" (\n')
    handle.write('        prepend apiSchemas = ["MaterialBindingAPI"]\n')
    handle.write("    )\n")
    handle.write("    {\n")
    handle.write(f"        int[] faceVertexCounts = {format_int_array([3] * (len(indices) // 3))}\n")
    handle.write(f"        int[] faceVertexIndices = {format_int_array(indices)}\n")
    handle.write(f"        point3f[] points = {format_vec3_array(positions)}\n")
    handle.write(f"        normal3f[] normals = {format_vec3_array(normals)} (\n")
    handle.write('            interpolation = "vertex"\n')
    handle.write("        )\n")
    handle.write(f"        texCoord2f[] primvars:st = {format_vec2_array(flip_v(texcoords))} (\n")
    handle.write('            interpolation = "vertex"\n')
    handle.write("        )\n")
    handle.write('        uniform token subdivisionScheme = "none"\n')
    handle.write(f"        rel material:binding = </{root_name}/Looks/{material_name}>\n")
    handle.write("    }\n\n")


def read_accessor(gltf: dict, binary: bytes, accessor_index: int) -> list:
    accessor = gltf["accessors"][accessor_index]
    view = gltf["bufferViews"][accessor["bufferView"]]
    component_type = accessor["componentType"]
    scalar_format, component_size = COMPONENT_FORMATS[component_type]
    component_count = TYPE_COMPONENTS[accessor["type"]]
    item_size = component_count * component_size
    stride = view.get("byteStride", item_size)
    offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    count = accessor["count"]
    fmt = "<" + scalar_format * component_count

    values = []
    for index in range(count):
        raw = struct.unpack_from(fmt, binary, offset + index * stride)
        if component_count == 1:
            values.append(raw[0])
        else:
            values.append(tuple(raw))
    return values


def node_matrix(node: dict) -> list[list[float]]:
    if "matrix" in node:
        values = node["matrix"]
        return [[values[row + column * 4] for column in range(4)] for row in range(4)]

    translation = node.get("translation", [0, 0, 0])
    rotation = node.get("rotation", [0, 0, 0, 1])
    scale = node.get("scale", [1, 1, 1])
    return matrix_multiply(translation_matrix(translation), matrix_multiply(quaternion_matrix(rotation), scale_matrix(scale)))


def identity_matrix() -> list[list[float]]:
    return [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]


def translation_matrix(value: Iterable[float]) -> list[list[float]]:
    x, y, z = value
    return [[1, 0, 0, x], [0, 1, 0, y], [0, 0, 1, z], [0, 0, 0, 1]]


def scale_matrix(value: Iterable[float]) -> list[list[float]]:
    x, y, z = value
    return [[x, 0, 0, 0], [0, y, 0, 0], [0, 0, z, 0], [0, 0, 0, 1]]


def quaternion_matrix(value: Iterable[float]) -> list[list[float]]:
    x, y, z, w = value
    length = math.sqrt(x * x + y * y + z * z + w * w)
    if length == 0:
        return identity_matrix()
    x, y, z, w = x / length, y / length, z / length, w / length
    xx, yy, zz = x * x, y * y, z * z
    xy, xz, yz = x * y, x * z, y * z
    wx, wy, wz = w * x, w * y, w * z
    return [
        [1 - 2 * (yy + zz), 2 * (xy - wz), 2 * (xz + wy), 0],
        [2 * (xy + wz), 1 - 2 * (xx + zz), 2 * (yz - wx), 0],
        [2 * (xz - wy), 2 * (yz + wx), 1 - 2 * (xx + yy), 0],
        [0, 0, 0, 1],
    ]


def matrix_multiply(a: list[list[float]], b: list[list[float]]) -> list[list[float]]:
    return [[sum(a[row][k] * b[k][col] for k in range(4)) for col in range(4)] for row in range(4)]


def normal_matrix(matrix: list[list[float]]) -> list[list[float]]:
    return [[matrix[row][col] for col in range(3)] + [0] for row in range(3)] + [[0, 0, 0, 1]]


def transform_point(matrix: list[list[float]], value: Iterable[float]) -> tuple[float, float, float]:
    x, y, z = value
    return (
        matrix[0][0] * x + matrix[0][1] * y + matrix[0][2] * z + matrix[0][3],
        matrix[1][0] * x + matrix[1][1] * y + matrix[1][2] * z + matrix[1][3],
        matrix[2][0] * x + matrix[2][1] * y + matrix[2][2] * z + matrix[2][3],
    )


def transform_vector(matrix: list[list[float]], value: Iterable[float]) -> tuple[float, float, float]:
    x, y, z = value
    return (
        matrix[0][0] * x + matrix[0][1] * y + matrix[0][2] * z,
        matrix[1][0] * x + matrix[1][1] * y + matrix[1][2] * z,
        matrix[2][0] * x + matrix[2][1] * y + matrix[2][2] * z,
    )


def normalize(value: Iterable[float]) -> tuple[float, float, float]:
    x, y, z = value
    length = math.sqrt(x * x + y * y + z * z)
    if length < 1e-8:
        return (0, 1, 0)
    return (x / length, y / length, z / length)


def flip_v(values: Iterable[Iterable[float]]) -> list[tuple[float, float]]:
    return [(u, 1 - v) for u, v in values]


def format_int_array(values: Iterable[int]) -> str:
    return "[" + ", ".join(str(int(value)) for value in values) + "]"


def format_vec2_array(values: Iterable[Iterable[float]]) -> str:
    return "[" + ", ".join(f"({fmt(x)}, {fmt(y)})" for x, y in values) + "]"


def format_vec3_array(values: Iterable[Iterable[float]]) -> str:
    return "[" + ", ".join(f"({fmt(x)}, {fmt(y)}, {fmt(z)})" for x, y, z in values) + "]"


def fmt(value: float) -> str:
    return f"{float(value):.7g}"


def sanitize_identifier(value: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9_]", "_", value)
    if not cleaned or cleaned[0].isdigit():
        cleaned = f"_{cleaned}"
    return cleaned


def run(command: list[str], allow_failure: bool = False) -> bool:
    if shutil.which(command[0]) is None:
        raise RuntimeError(f"Required command not found: {command[0]}")
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if result.stdout:
        print(result.stdout, end="")
    if result.returncode != 0:
        if allow_failure:
            return False
        raise RuntimeError(f"Command failed: {' '.join(command)}")
    return True


if __name__ == "__main__":
    raise SystemExit(main())
