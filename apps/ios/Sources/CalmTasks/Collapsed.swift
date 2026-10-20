import Foundation

/// Which columns the user folded away. Stored as a comma separated list of status keys.
enum Collapsed {
    static let storageKey = "calm.collapsed"

    static func set(_ raw: String) -> Set<String> {
        Set(raw.split(separator: ",").map(String.init))
    }

    static func toggled(_ key: String, in raw: String) -> String {
        var keys = set(raw)
        if keys.contains(key) { keys.remove(key) } else { keys.insert(key) }
        return keys.sorted().joined(separator: ",")
    }
}
