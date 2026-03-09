import SwiftUI

struct IdeaDetailView: View {
    @EnvironmentObject private var appState: AppState
    let idea: Idea

    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    SecondaryPillButton(title: "Export text", systemImage: "doc.text", tint: AppColors.accentStart) {
                        shareItems = [IdeaTextExporter.buildShareText(for: idea)]
                        showShareSheet = true
                    }

                    SecondaryPillButton(title: "Export PDF (Premium)", systemImage: "square.and.arrow.up", tint: AppColors.accentStart) {
                        guard appState.purchaseManager.isPremium else {
                            appState.showPremiumSheet = true
                            return
                        }
                        let data = IdeaTextExporter.buildPDFData(for: idea)
                        let url = FileManager.default.temporaryDirectory.appendingPathComponent("idea-\(idea.id).pdf")
                        try? data.write(to: url, options: .atomic)
                        shareItems = [url]
                        showShareSheet = true
                    }
                }

                if let videos = appState.relatedVideos[idea.id], !videos.isEmpty {
                    SectionHeader(title: "YouTube")
                    ForEach(videos) { video in
                        Link(destination: video.url) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(video.title)
                                    .font(.headline)
                                    .foregroundStyle(AppColors.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(video.url.absoluteString)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.inkMuted)
                                    .lineLimit(1)
                            }
                            .appCard()
                        }
                        .buttonStyle(.plain)
                    }
                }

                InlineBannerAdView(unitID: AppConfig.detailBannerAdUnitID, minimumHeight: 120)

                SectionHeader(title: "View action plan")
                ForEach(ActionPlanParser.parse(idea.actionPlan).sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.title)
                            .font(.title3.bold())
                        ForEach(section.lines, id: \.self) { line in
                            Text(line)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(AppColors.ink)
                        }
                    }
                    .appCard()
                }
            }
            .padding(20)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(idea.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                FavoriteButton(isFavorite: idea.isFavorite) {
                    appState.toggleIdeaFavorite(idea)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
        .task {
            await appState.fetchRelatedVideos(for: idea)
            AnalyticsService.log("native_impression_plan", params: [:])
        }
    }
}

