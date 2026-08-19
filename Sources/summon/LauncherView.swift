import AppKit
import SummonKit
import SwiftUI

enum CandidateListID {
    static func row(plugin: String, candidateID: String) -> String {
        "\(plugin)\u{1E}\(candidateID)"
    }
}

private struct ListedCandidate: Identifiable {
    var id: String
    var index: Int
    var candidate: Candidate
}

struct LauncherView: View {
    @ObservedObject var model: LauncherModel

    private var selectedPluginName: String {
        model.selectedPlugin?.manifest.name ?? ""
    }

    private var listedRows: [ListedCandidate] {
        let plugin = selectedPluginName
        return model.candidates.enumerated().map { index, candidate in
            ListedCandidate(
                id: CandidateListID.row(plugin: plugin, candidateID: candidate.id),
                index: index,
                candidate: candidate
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Search", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .medium))
                .padding(.horizontal, 4)

            Divider()

            if !model.tabs.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(model.tabs.enumerated()), id: \.element.manifest.name) { index, plugin in
                        let selected = index == model.selectedTabIndex
                        Button(plugin.manifest.title) {
                            model.selectTab(at: index)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(selected ? Color.accentColor.opacity(0.25) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .font(.system(size: 12, weight: selected ? .semibold : .regular))
                    }
                    Spacer()
                }
            }

            if model.tabs.isEmpty {
                Text("No plugins found")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.candidates.isEmpty {
                Text("No results")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                candidateList
                    .id(selectedPluginName)
            }
        }
        .padding(16)
        .frame(width: 560, height: 420)
    }

    private var candidateList: some View {
        let rows = listedRows
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(rows) { row in
                        CandidateRow(
                            candidate: row.candidate,
                            selected: row.index == model.selectedCandidateIndex
                        )
                        .id(row.id)
                        .onTapGesture {
                            model.selectedCandidateIndex = row.index
                            model.confirm()
                        }
                    }
                }
            }
            .onChange(of: model.selectedCandidateIndex) { _, index in
                if rows.indices.contains(index) {
                    proxy.scrollTo(rows[index].id)
                }
            }
        }
    }
}

private struct CandidateRow: View {
    var candidate: Candidate
    var selected: Bool

    var body: some View {
        HStack(spacing: 10) {
            icon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(candidate.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                if let subtitle = candidate.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(selected ? Color.accentColor.opacity(0.22) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var icon: Image {
        if let path = candidate.icon, !path.isEmpty {
            let nsImage = NSWorkspace.shared.icon(forFile: path)
            nsImage.size = NSSize(width: 28, height: 28)
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "doc.text")
    }
}
