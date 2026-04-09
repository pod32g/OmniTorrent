import SwiftUI
import Charts
import OmniTorrentEngine

struct SpeedGraphView: View {
    let speedHistory: [SpeedSample]

    var body: some View {
        Chart {
            ForEach(speedHistory) { sample in
                LineMark(
                    x: .value("Time", sample.id),
                    y: .value("Speed", sample.downloadRate)
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Time", sample.id),
                    y: .value("Speed", sample.uploadRate)
                )
                .foregroundStyle(.green)
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: 40)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}
