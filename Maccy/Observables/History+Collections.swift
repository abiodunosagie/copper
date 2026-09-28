import Defaults
import Foundation

// Collections: named labels on history items that the docked panel can filter by.
extension History {
  // Adds a collection name; returns false for an empty or duplicate name.
  @discardableResult
  func createCollection(named rawName: String) -> Bool {
    let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty,
          !Defaults[.collections].contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else {
      return false
    }
    Defaults[.collections].append(name)
    return true
  }

  @MainActor
  func setCollection(_ name: String?, for item: HistoryItemDecorator) {
    item.item.collection = name
    try? Storage.shared.context.save()
    refilter()
  }

  // Removes the collection; its items stay in history without a collection.
  @MainActor
  func deleteCollection(_ name: String) {
    all.filter { $0.item.collection == name }.forEach { $0.item.collection = nil }
    try? Storage.shared.context.save()
    Defaults[.collections].removeAll { $0 == name }
    if collectionFilter == name {
      collectionFilter = nil
    } else {
      refilter()
    }
  }
}
