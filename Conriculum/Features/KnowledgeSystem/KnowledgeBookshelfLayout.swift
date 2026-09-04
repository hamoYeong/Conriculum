import Foundation

/// Reserve an exact number of fixed-width cards; the detail receives all remaining space.
struct KnowledgeBookshelfLayout: Equatable {
    static let cardWidth: CGFloat = 240
    static let columnSpacing: CGFloat = 14
    static let shelfPadding: CGFloat = 22
    static let dividerWidth: CGFloat = 1
    static let minimumDetailWidth: CGFloat = 310

    let shelfWidth: CGFloat
    let columns: Int?
    let showsSideDetail: Bool

    static func width(forColumns columns: Int) -> CGFloat {
        CGFloat(columns) * cardWidth + CGFloat(max(0, columns - 1)) * columnSpacing + 2 * shelfPadding
    }

    static func resolve(availableWidth: CGFloat, hasDetail: Bool) -> Self {
        if hasDetail {
            for columns in [3, 2, 1] {
                let shelfWidth = width(forColumns: columns)
                if availableWidth >= shelfWidth + dividerWidth + minimumDetailWidth {
                    return Self(shelfWidth: shelfWidth, columns: columns, showsSideDetail: true)
                }
            }
        }
        return Self(shelfWidth: availableWidth, columns: nil, showsSideDetail: false)
    }
}
