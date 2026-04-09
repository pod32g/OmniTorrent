import Foundation

enum FormatHelpers {
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    static func formatRate(_ bytesPerSec: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(bytesPerSec)))/s"
    }

    static func formatETA(_ seconds: Int) -> String {
        guard seconds > 0 else { return "\u{2014}" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "\(seconds)s"
    }

    static func formatProgress(_ progress: Float) -> String {
        "\(Int(progress * 100))%"
    }

    static func formatRatio(uploaded: Int64, downloaded: Int64) -> String {
        guard downloaded > 0 else { return "\u{221E}" }
        let ratio = Double(uploaded) / Double(downloaded)
        return String(format: "%.1f", ratio)
    }
}
