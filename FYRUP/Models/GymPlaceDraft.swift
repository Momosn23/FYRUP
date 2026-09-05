import Foundation

/// A manually edited or deliberately emptied meeting point must never be
/// replaced when a view reappears or the saved favourite changes.
struct GymPlaceDraft: Equatable {
    private(set) var value = ""
    private(set) var userEdited = false
    private(set) var usesFavorite = false

    mutating func synchronize(sport: SportKind?, favorite: String?) {
        guard !userEdited else { return }
        value = sport == .gym ? favorite ?? "" : ""
        usesFavorite = sport == .gym && favorite != nil
    }
    mutating func edit(_ text: String) { value = text; userEdited = true; usesFavorite = false }
    mutating func useFavorite(_ favorite: String?) {
        userEdited = false; synchronize(sport: .gym, favorite: favorite)
    }
}
