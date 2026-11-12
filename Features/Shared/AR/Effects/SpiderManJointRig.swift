import Foundation

/// Resolves Mixamo hand/foot chains, with flat names or full USD skeleton paths.
/// No indices or rest-pose positions are hardcoded for Spider-Man's assets.
struct SpiderManJointRig {
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

    /// The first version picked the preparatory hand on Spiderman_Tecnic.usdz.
    /// Calibration for THIS clip: the launching wrist is the opposite one.
    static func webThrowingHand(oppositeOf preparationHand: Joint) -> Joint {
        switch preparationHand {
        case .leftHand: return .rightHand
        case .rightHand: return .leftHand
        // Never called for feet; preserve value for defensive robustness.
        case .leftFoot, .rightFoot: return preparationHand
        }
    }

    private let chains: [Joint: [Int]]

    init?(jointNames: [String]) {
        let normalized = jointNames.map(Self.normalize)
        var byPath: [String: Int] = [:]
        var byName: [String: Int] = [:]
        for (index, name) in jointNames.enumerated() {
            if byPath[name] == nil { byPath[name] = index }
            if byName[normalized[index]] == nil { byName[normalized[index]] = index }
        }
        func makeChain(for joint: Joint) -> [Int]? {
            guard let start = byName[joint.normalizedName] else { return nil }
            var result = [Int]()
            var seen = Set<Int>()
            var next: Int? = start
            while let index = next {
                guard !seen.contains(index), result.count < 40 else { return nil }
                seen.insert(index)
                result.insert(index, at: 0)
                let path = jointNames[index]
                if let slash = path.lastIndex(of: "/") {
                    next = byPath[String(path[..<slash])]
                } else {
                    next = Self.parent(of: normalized[index]).flatMap { byName[$0] }
                }
            }
            return result.count >= 3 ? result : nil
        }
        var chains: [Joint: [Int]] = [:]
        for joint in Joint.allCases {
            if let chain = makeChain(for: joint) { chains[joint] = chain }
        }
        guard !chains.isEmpty else { return nil }
        self.chains = chains
    }

    func chain(for joint: Joint) -> [Int]? { chains[joint] }

    private static func normalize(_ value: String) -> String {
        String(value.split(separator: "/").last ?? Substring(value))
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
