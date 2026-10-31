import Foundation

/// Finds both Mixamo wrists in the joint list returned by RealityKit.
/// Names can be full paths or flat (e.g. mixamorig_LeftHand).
/// No character-specific magic joint indices are hardcoded.
struct GokuHandRig {
    let leftChain: [Int]
    let rightChain: [Int]

    init?(jointNames: [String]) {
        let normalized = jointNames.map(Self.normalize)
        guard let left = normalized.firstIndex(of: "lefthand"),
              let right = normalized.firstIndex(of: "righthand") else { return nil }
        // Duplicate joint labels must never crash the game. Keep the first.
        var byFullName: [String: Int] = [:]
        var byNormalized: [String: Int] = [:]
        for (index, name) in jointNames.enumerated() {
            if byFullName[name] == nil { byFullName[name] = index }
            if byNormalized[normalized[index]] == nil { byNormalized[normalized[index]] = index }
        }
        func chain(start: Int) -> [Int]? {
            var stack: [Int] = []
            var seen = Set<Int>()
            var current: Int? = start
            while let index = current {
                guard !seen.contains(index), stack.count < 32 else { return nil }
                seen.insert(index)
                stack.insert(index, at: 0)
                let path = jointNames[index]
                if let slash = path.lastIndex(of: "/") {
                    let parentPath = String(path[..<slash])
                    current = byFullName[parentPath]
                } else {
                    current = Self.parentName(of: normalized[index]).flatMap { byNormalized[$0] }
                }
            }
            return stack.isEmpty ? nil : stack
        }
        guard let leftChain = chain(start: left),
              let rightChain = chain(start: right),
              leftChain.count >= 3, rightChain.count >= 3 else { return nil }
        self.leftChain = leftChain
        self.rightChain = rightChain
    }

    private static func normalize(_ name: String) -> String {
        let suffix = String(name.split(separator: "/").last ?? Substring(name))
        return suffix.lowercased()
            .replacingOccurrences(of: "mixamorig", with: "")
            .filter { $0.isLetter || $0.isNumber }
    }

    private static func parentName(of name: String) -> String? {
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
        default: return nil
        }
    }
}
