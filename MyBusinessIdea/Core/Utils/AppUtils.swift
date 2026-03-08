import Foundation
import SwiftUI
import UIKit

enum AppError: LocalizedError, Equatable {
    case message(String)
    case api(String)
    case invalidResponse
    case networkUnavailable
    case timeout
    case premiumRequired
    case cancelled

    var errorDescription: String? {
        switch self {
        case .message(let value), .api(let value):
            return value
        case .invalidResponse:
            return "Invalid server response."
        case .networkUnavailable:
            return "Unable to connect to the server."
        case .timeout:
            return "The request timed out."
        case .premiumRequired:
            return "Premium is required for this action."
        case .cancelled:
            return "Cancelled."
        }
    }
}

enum CurrencySupport {
    static func normalize(_ code: String?) -> String {
        guard let code else { return "USD" }
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalized.count == 3 else { return "USD" }
        return Locale.commonISOCurrencyCodes.contains(normalized) ? normalized : "USD"
    }

    static func detectFromDevice() -> String {
        let locale = Locale.current
        let code = locale.currency?.identifier ?? locale.currencyCode ?? "USD"
        return normalize(code)
    }

    static func format(amount: Int, currencyCode: String) -> String {
        let normalized = normalize(currencyCode)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = normalized
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(normalized) \(amount)"
    }
}

enum IdeaTextExporter {
    static func buildShareText(for idea: Idea) -> String {
        [
            idea.title,
            "",
            "Description:",
            idea.description,
            "",
            "Find ideas and generate your free plan in our app: \(AppConfig.playStorePromoURL.absoluteString)",
            "",
            "Investment: \(CurrencySupport.format(amount: idea.investment, currencyCode: idea.currencyCode))",
            "",
            "View action plan:",
            idea.actionPlan
        ]
        .joined(separator: "\n")
    }

    static func buildPDFData(for idea: Idea) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.data { context in
            context.beginPage()
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold)
            ]
            let headingAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
            ]
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular)
            ]

            let margin: CGFloat = 32
            var y: CGFloat = 32

            func draw(_ text: String, attributes: [NSAttributedString.Key: Any], height: CGFloat) {
                let rect = CGRect(x: margin, y: y, width: pageRect.width - margin * 2, height: height)
                text.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
                y += height + 12
            }

            draw(idea.title, attributes: titleAttributes, height: 42)
            draw("Description", attributes: headingAttributes, height: 24)
            draw(idea.description, attributes: bodyAttributes, height: 120)
            draw("Investment", attributes: headingAttributes, height: 24)
            draw(CurrencySupport.format(amount: idea.investment, currencyCode: idea.currencyCode), attributes: bodyAttributes, height: 24)
            draw("Action plan", attributes: headingAttributes, height: 24)
            draw(idea.actionPlan, attributes: bodyAttributes, height: pageRect.height - y - 48)
        }
    }
}

enum ActionPlanParser {
    static func parse(_ markdown: String) -> GeneratedPlanSections {
        let lines = markdown
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        var sections: [GeneratedPlanSections.Section] = []
        var currentTitle = "Action plan"
        var currentLines: [String] = []

        for line in lines where !line.isEmpty {
            if line.hasPrefix("## ") {
                if !currentLines.isEmpty {
                    sections.append(.init(title: currentTitle, lines: currentLines))
                }
                currentTitle = String(line.dropFirst(3))
                currentLines = []
            } else {
                currentLines.append(line)
            }
        }

        if !currentLines.isEmpty {
            sections.append(.init(title: currentTitle, lines: currentLines))
        }

        return GeneratedPlanSections(sections: sections)
    }
}

enum YouTubeParser {
    static func parseResults(html: String, limit: Int) -> [RelatedVideo] {
        let pattern = #""videoId":"([^"]+)".*?"title":\{"runs":\[\{"text":"(.*?)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, options: [], range: nsRange)

        var seen: Set<String> = []
        var items: [RelatedVideo] = []

        for match in matches {
            guard match.numberOfRanges >= 3,
                  let videoIDRange = Range(match.range(at: 1), in: html),
                  let titleRange = Range(match.range(at: 2), in: html) else {
                continue
            }

            let videoId = String(html[videoIDRange])
            let rawTitle = String(html[titleRange])
                .replacingOccurrences(of: "\\u0026", with: "&")
                .replacingOccurrences(of: "\\\"", with: "\"")

            guard seen.insert(videoId).inserted,
                  let url = URL(string: "https://www.youtube.com/watch?v=\(videoId)") else {
                continue
            }

            items.append(RelatedVideo(videoId: videoId, title: rawTitle, url: url))
            if items.count == limit {
                break
            }
        }

        return items
    }
}

extension String {
    func normalizedSecurityAnswer() -> String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension ISO8601DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

extension Date {
    func formattedBirthDate() -> String {
        ISO8601DateFormatter.shortDate.string(from: self)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

