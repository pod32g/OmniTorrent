import Foundation

actor GeoIPLookup {
    static let shared = GeoIPLookup()

    private var cache: [String: String] = [:]  // IP -> country code (e.g. "US")
    private var pending: Set<String> = []

    func countryCode(for ip: String) -> String? {
        cache[ip]
    }

    func lookup(_ ip: String) async -> String? {
        if let cached = cache[ip] { return cached }
        guard !pending.contains(ip) else { return nil }
        pending.insert(ip)

        defer { pending.remove(ip) }

        // Use ip-api.com (free, no key needed, 45 req/min)
        guard let url = URL(string: "http://ip-api.com/json/\(ip)?fields=countryCode") else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let code = json["countryCode"] as? String {
                cache[ip] = code
                return code
            }
        } catch {}

        return nil
    }

    /// Convert country code to flag emoji
    static func flag(for countryCode: String) -> String {
        let base: UInt32 = 127397
        return countryCode.uppercased().unicodeScalars.compactMap {
            UnicodeScalar(base + $0.value)
        }.map { String($0) }.joined()
    }
}
