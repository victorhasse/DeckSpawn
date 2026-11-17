import Foundation

/// Resolves hand and foot joints on the Stormtrooper Mixamo skeleton.
/// Accepts both full hierarchy paths and flattened USD joint names.
nonisolated struct StormtrooperJointRig {
    enum Joint: CaseIterable, Hashable {
        case leftHand, rightHand, leftFoot, rightFoot

        fileprivate var normalizedName: String {
            switch self {
            case .leftHand: return "lefthand"
            case .rightHand: return "righthand"
            case .leftFoot: return "leftfoot"
            case .rightFoot: return "rightfoot"
            }
        }
    }

    private let chains: [Joint: [Int]]

    init?(jointNames: [String]) {
        let normalized = jointNames.map(Self.normalize)
        var indicesByFullPath: [String: Int] = [:]
        var indicesBySimpleName: [String: Int] = [:]
        for (index, path) in jointNames.enumerated() {
            if indicesByFullPath[path] == nil { indicesByFullPath[path] = index }
            if indicesBySimpleName[normalized[index]] == nil {
                indicesBySimpleName[normalized[index]] = index
            }
        }

        func chain(for joint: Joint) -> [Int]? {
            guard let endpoint = indicesBySimpleName[joint.normalizedName] else { return nil }
            var chain: [Int] = []
            var seen = Set<Int>()
            var current: Int? = endpoint
            while let index = current {
                guard !seen.contains(index), chain.count < 40 else { return nil }
                seen.insert(index)
                chain.insert(index, at: 0)
                let path = jointNames[index]
                if let slash = path.lastIndex(of: "/") {
                    current = indicesByFullPath[String(path[..<slash])]
                } else {
                    current = Self.parent(of: normalized[index]).flatMap {
                        indicesBySimpleName[$0]
                    }
                }
            }
            return chain.count >= 3 ? chain : nil
        }

        var discovered: [Joint: [Int]] = [:]
        for joint in Joint.allCases {
            discovered[joint] = chain(for: joint)
        }
        guard !discovered.isEmpty else { return nil }
        chains = discovered
    }

    func chain(for joint: Joint) -> [Int]? { chains[joint] }

    static func activeJoint(
        leftStart: SIMD3<Float>?, rightStart: SIMD3<Float>?,
        leftCurrent: SIMD3<Float>?, rightCurrent: SIMD3<Float>?,
        left: Joint, right: Joint, default preferred: Joint
    ) -> Joint {
        if let l0 = leftStart, let r0 = rightStart,
           let l1 = leftCurrent, let r1 = rightCurrent {
            let ld = l1 - l0
            let rd = r1 - r0
            let l = ld.x * ld.x + ld.y * ld.y + ld.z * ld.z
            let r = rd.x * rd.x + rd.y * rd.y + rd.z * rd.z
            // Small offsets at rest should not cause random limb switches.
            if abs(l - r) > 0.00002 { return l > r ? left : right }
        }
        if leftCurrent != nil && rightCurrent == nil { return left }
        if rightCurrent != nil && leftCurrent == nil { return right }
        return preferred
    }

    private static func normalize(_ path: String) -> String {
        String(path.split(separator: "/").last ?? Substring(path))
            .lowercased()
            .replacingOccurrences(of: "mixamorig", with: "")
            .filter { $0.isLetter || $0.isNumber }
    }

    private static func parent(of name: String) -> String? {
        switch name {
        case "lefthand": return "leftforearm"
        case "righthand": return "rightforearm"
        case "leftforearm": return "leftarm"
        case "rightforearm": return "rightarm"
        case "leftarm": return "leftshoulder"
        case "rightarm": return "rightshoulder"
        case "leftshoulder", "rightshoulder": return "spine2"
        case "spine2": return "spine1"
        case "spine1": return "spine"
        case "spine": return "hips"
        case "leftfoot": return "leftleg"
        case "rightfoot": return "rightleg"
        case "leftleg": return "leftupleg"
        case "rightleg": return "rightupleg"
        case "leftupleg", "rightupleg": return "hips"
        default: return nil
        }
    }
}
