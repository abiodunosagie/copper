import Foundation

// Splits a search into a copy-date range and the remaining text:
// "yesterday invoice" finds items with "invoice" copied yesterday.
struct DateQuery: Equatable {
  var range: Range<Date>?
  var text: String

  // Longest phrases first so "last week" wins over a plain "week".
  static let phrases = ["last month", "this month", "last week", "this week", "yesterday", "today"]

  static func parse(_ query: String, now: Date = .now, calendar: Calendar = .current) -> DateQuery {
    let lowered = query.lowercased()
    for phrase in phrases {
      guard let found = lowered.range(of: phrase),
            isWholeWords(found, in: lowered),
            let range = range(for: phrase, now: now, calendar: calendar) else { continue }

      // Search is case-insensitive, so the lowered text is fine to search with.
      let remaining = lowered.replacingCharacters(in: found, with: " ")
      let text = remaining.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
      return DateQuery(range: range, text: text)
    }
    return DateQuery(range: nil, text: query)
  }

  private static func isWholeWords(_ range: Range<String.Index>, in text: String) -> Bool {
    let before = range.lowerBound == text.startIndex || text[text.index(before: range.lowerBound)] == " "
    let after = range.upperBound == text.endIndex || text[range.upperBound] == " "
    return before && after
  }

  private static func range(for phrase: String, now: Date, calendar: Calendar) -> Range<Date>? {
    let startOfToday = calendar.startOfDay(for: now)
    func interval(_ component: Calendar.Component, offset: Int) -> Range<Date>? {
      guard let current = calendar.dateInterval(of: component, for: now),
            let start = calendar.date(byAdding: component, value: offset, to: current.start),
            let end = calendar.date(byAdding: component, value: 1, to: start) else { return nil }
      return start..<end
    }

    switch phrase {
    case "today":
      guard let end = calendar.date(byAdding: .day, value: 1, to: startOfToday) else { return nil }
      return startOfToday..<end
    case "yesterday":
      guard let start = calendar.date(byAdding: .day, value: -1, to: startOfToday) else { return nil }
      return start..<startOfToday
    case "this week": return interval(.weekOfYear, offset: 0)
    case "last week": return interval(.weekOfYear, offset: -1)
    case "this month": return interval(.month, offset: 0)
    case "last month": return interval(.month, offset: -1)
    default: return nil
    }
  }
}

extension Search {
  // Search that understands date words ("yesterday", "last week") before matching the rest.
  func searchWithDates(string query: String, within items: [Searchable]) -> [SearchResult] {
    let parsed = DateQuery.parse(query)
    guard let range = parsed.range else { return search(string: query, within: items) }
    return search(string: parsed.text, within: items.filter { range.contains($0.item.lastCopiedAt) })
  }
}
