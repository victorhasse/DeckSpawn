import RealityKit
import simd

/// Cúpula elipsoidal orientada em +Y, com a borda inferior no plano XZ (y = 0).
/// Diferentemente de uma tampa frontal, envolve o corpo inteiro do defensor.
enum GuardDomeMesh {
    private struct Triangles {
        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        mutating func add(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>,
                          doubleSided: Bool = false) {
            appendFace(a, b, c)
            if doubleSided { appendFace(c, b, a) }
        }

        private mutating func appendFace(_ a: SIMD3<Float>, _ b: SIMD3<Float>,
                                         _ c: SIMD3<Float>) {
            let cross = simd_cross(b - a, c - a)
            guard simd_length_squared(cross) > 0.0000000001 else { return }
            let n = simd_normalize(cross)
            let start = UInt32(vertices.count)
            vertices.append(contentsOf: [a, b, c])
            normals.append(contentsOf: [n, n, n])
            indices.append(contentsOf: [start, start + 1, start + 2])
        }

        mutating func quad(_ a: SIMD3<Float>, _ b: SIMD3<Float>,
                           _ c: SIMD3<Float>, _ d: SIMD3<Float>,
                           doubleSided: Bool = false) {
            add(a, b, c, doubleSided: doubleSided)
            add(a, c, d, doubleSided: doubleSided)
        }

        func mesh() -> MeshResource {
            var desc = MeshDescriptor(name: "GuardDome")
            desc.positions = MeshBuffers.Positions(vertices)
            desc.normals = MeshBuffers.Normals(normals)
            desc.primitives = .triangles(indices)
            return (try? MeshResource.generate(from: [desc]))
                ?? MeshResource.generateSphere(radius: 0.001)
        }
    }

    /// Ponto em uma cúpula: o eixo vertical do RealityKit é Y.
    private static func cap(_ p: SIMD2<Float>, radius: Float, height: Float,
                            lift: Float = 0) -> SIMD3<Float> {
        let normalized = min(0.9999, simd_length_squared(p) / (radius * radius))
        return SIMD3<Float>(p.x, height * sqrt(max(0, 1 - normalized)) + lift, p.y)
    }

    private static func stroke(_ a: SIMD2<Float>, _ b: SIMD2<Float>,
                               width: Float, radius: Float, height: Float,
                               mesh: inout Triangles, lift: Float = 0.003) {
        let dir = b - a
        let len = simd_length(dir)
        guard len > 0.000001 else { return }
        let sideways = SIMD2<Float>(-dir.y, dir.x) * (width * 0.5 / len)
        mesh.quad(cap(a + sideways, radius: radius, height: height, lift: lift),
                  cap(a - sideways, radius: radius, height: height, lift: lift),
                  cap(b - sideways, radius: radius, height: height, lift: lift),
                  cap(b + sideways, radius: radius, height: height, lift: lift),
                  doubleSided: true)
    }

    static func hemisphere(radius: Float, height: Float) -> MeshResource {
        var mesh = Triangles()
        let rings = 16
        let segments = 40
        func point(_ theta: Float, _ angle: Float) -> SIMD3<Float> {
            SIMD3<Float>(radius * sin(theta) * cos(angle),
                         height * cos(theta),
                         radius * sin(theta) * sin(angle))
        }
        for ring in 0..<rings {
            let t0 = Float(ring) / Float(rings) * (.pi / 2)
            let t1 = Float(ring + 1) / Float(rings) * (.pi / 2)
            for segment in 0..<segments {
                let a0 = Float(segment) / Float(segments) * (2 * .pi)
                let a1 = Float(segment + 1) / Float(segments) * (2 * .pi)
                // Ordem invertida em relação ao protótipo: normais para FORA.
                mesh.quad(point(t0, a0), point(t0, a1),
                          point(t1, a1), point(t1, a0))
            }
        }
        return mesh.mesh()
    }

    static func rim(radius: Float, height: Float) -> MeshResource {
        var mesh = Triangles()
        for i in 0..<48 {
            let a = Float(i) * (2 * .pi / 48)
            let b = Float(i + 1) * (2 * .pi / 48)
            let r = radius * 0.9999
            stroke(SIMD2<Float>(r * cos(a), r * sin(a)),
                   SIMD2<Float>(r * cos(b), r * sin(b)),
                   width: radius * 0.025, radius: radius, height: height,
                   mesh: &mesh)
        }
        return mesh.mesh()
    }

    /// Hexágonos distribuídos sobre a SUPERFÍCIE lateral do domo.
    /// A versão anterior projetava os hexágonos do eixo Y para cima:
    /// de frente, quase todo o padrão ficava escondido no topo.
    private static func shellPoint(theta: Float, azimuth: Float,
                                   radius: Float, height: Float,
                                   outward: Float = 0.004) -> SIMD3<Float> {
        let s = sin(theta)
        let c = cos(theta)
        let p = SIMD3<Float>(radius * s * cos(azimuth), height * c,
                             radius * s * sin(azimuth))
        let n = simd_normalize(SIMD3<Float>(
            s * cos(azimuth) / max(radius, 0.001),
            c / max(height, 0.001),
            s * sin(azimuth) / max(radius, 0.001)))
        return p + n * outward
    }

    private static func shellStroke(_ a: SIMD3<Float>, _ b: SIMD3<Float>,
                                    width: Float, mesh: inout Triangles) {
        let d = b - a
        guard simd_length_squared(d) > 0.00000001 else { return }
        let midpoint = (a + b) * 0.5
        let radial = simd_normalize(SIMD3<Float>(midpoint.x, midpoint.y * 0.7,
                                                  midpoint.z))
        let side = simd_cross(d, radial)
        guard simd_length_squared(side) > 0.00000001 else { return }
        let half = simd_normalize(side) * (width * 0.5)
        mesh.quad(a + half, a - half, b - half, b + half,
                  doubleSided: true)
    }

    static func hexagons(radius: Float, height: Float) -> MeshResource {
        var mesh = Triangles()
        let rings = 5
        let unit: Float = 0.125
        for ring in 0..<rings {
            let theta = Float(ring + 1) * (.pi / 2) / Float(rings + 1)
            let count = max(9, Int((2 * .pi * sin(theta)) / 0.28))
            for column in 0..<count {
                let offset: Float = ring.isMultiple(of: 2) ? 0 : 0.5
                let phi = 2 * Float.pi * (Float(column) + offset) / Float(count)
                let angularWidth = unit / max(0.32, sin(theta))
                for edge in 0..<6 {
                    let t0 = Float(edge) * (.pi / 3)
                    let t1 = Float(edge + 1) * (.pi / 3)
                    let a = shellPoint(
                        theta: theta + cos(t0) * unit,
                        azimuth: phi + sin(t0) * angularWidth,
                        radius: radius, height: height)
                    let b = shellPoint(
                        theta: theta + cos(t1) * unit,
                        azimuth: phi + sin(t1) * angularWidth,
                        radius: radius, height: height)
                    shellStroke(a, b, width: radius * 0.007, mesh: &mesh)
                }
            }
        }
        return mesh.mesh()
    }

    static func cracks(radius: Float, height: Float) -> MeshResource {
        var mesh = Triangles()
        for i in 0..<4 {
            let angle = Float(i) * Float.pi / 2 + 0.25
            let forward = SIMD2<Float>(cos(angle), sin(angle))
            let side = SIMD2<Float>(-forward.y, forward.x)
            let a = SIMD2<Float>(0, 0)
            let b = forward * (radius * 0.30)
            let c = forward * (radius * 0.60) + side * (radius * 0.10)
            let d = forward * (radius * 0.84) - side * (radius * 0.05)
            stroke(a, b, width: radius * 0.022, radius: radius, height: height, mesh: &mesh)
            stroke(b, c, width: radius * 0.014, radius: radius, height: height, mesh: &mesh)
            stroke(c, d, width: radius * 0.010, radius: radius, height: height, mesh: &mesh)
            stroke(c, c + side * (radius * 0.13), width: radius * 0.009,
                   radius: radius, height: height, mesh: &mesh)
        }
        return mesh.mesh()
    }
}
