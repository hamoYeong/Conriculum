import Foundation

/// Stable catalog identity and relation degree produce a repeatable graph.
/// No randomized force simulation is used, so filtering to the same inputs
/// always restores the same node positions.
struct KnowledgeGraphLayout: Equatable {
    static let nodeSize = CGSize(width: 166, height: 74)

    let canvasSize: CGSize
    let positions: [KnowledgeConceptID: CGPoint]

    init(
        concepts: [KnowledgeSystemSnapshot.ConceptItem],
        collections: [KnowledgeSystemSnapshot.CollectionItem],
        relations: [KnowledgeRelation],
        availableSize: CGSize
    ) {
        let minimumSize = Self.minimumCanvasSize(
            forConceptCount: concepts.count
        )
        canvasSize = CGSize(
            width: max(availableSize.width, minimumSize.width),
            height: max(availableSize.height, minimumSize.height)
        )

        guard !concepts.isEmpty else {
            positions = [:]
            return
        }

        let collectionOrder = Dictionary(
            uniqueKeysWithValues: collections.enumerated().map {
                ($0.element.id, $0.offset)
            }
        )
        let stableConcepts = concepts.sorted { lhs, rhs in
            let lhsCollection = collectionOrder[
                lhs.collectionID,
                default: .max
            ]
            let rhsCollection = collectionOrder[
                rhs.collectionID,
                default: .max
            ]
            if lhsCollection != rhsCollection {
                return lhsCollection < rhsCollection
            }
            return lhs.id.rawValue < rhs.id.rawValue
        }
        let visibleIDs = Set(stableConcepts.map(\.id))
        let degrees = relations.reduce(into: [KnowledgeConceptID: Int]()) {
            result,
            relation in
            guard visibleIDs.contains(relation.sourceConceptID),
                  visibleIDs.contains(relation.targetConceptID)
            else { return }
            result[relation.sourceConceptID, default: 0] += 1
            result[relation.targetConceptID, default: 0] += 1
        }
        let stableOrder = Dictionary(
            uniqueKeysWithValues: stableConcepts.enumerated().map {
                ($0.element.id, $0.offset)
            }
        )
        let hub = stableConcepts.max { lhs, rhs in
            let lhsDegree = degrees[lhs.id, default: 0]
            let rhsDegree = degrees[rhs.id, default: 0]
            if lhsDegree != rhsDegree {
                return lhsDegree < rhsDegree
            }
            return stableOrder[lhs.id, default: .max]
                > stableOrder[rhs.id, default: .max]
        } ?? stableConcepts[0]

        let center = CGPoint(
            x: canvasSize.width / 2,
            y: canvasSize.height / 2
        )
        var positioned: [KnowledgeConceptID: CGPoint] = [hub.id: center]
        let remaining = stableConcepts.filter { $0.id != hub.id }
        let rings = Self.rings(from: remaining)

        let maximumRadiusX = max(
            126,
            canvasSize.width / 2 - 48 - Self.nodeSize.width / 2
        )
        let maximumRadiusY = max(
            104,
            canvasSize.height / 2 - 42 - Self.nodeSize.height / 2
        )
        let radiusScales = Self.radiusScales(forRingCount: rings.count)

        for (ringIndex, ring) in rings.enumerated() {
            let scale = radiusScales[ringIndex]
            let radiusX = maximumRadiusX * scale
            let radiusY = maximumRadiusY * scale
            let angleStep = (Double.pi * 2) / Double(max(ring.count, 1))
            let startAngle = -Double.pi / 2
                + (ringIndex.isMultiple(of: 2) ? 0 : angleStep / 2)

            for (index, concept) in ring.enumerated() {
                let angle = startAngle + Double(index) * angleStep
                positioned[concept.id] = CGPoint(
                    x: center.x + radiusX * cos(angle),
                    y: center.y + radiusY * sin(angle)
                )
            }
        }

        positions = positioned
    }

    func position(for conceptID: KnowledgeConceptID) -> CGPoint? {
        positions[conceptID]
    }

    private static func minimumCanvasSize(
        forConceptCount count: Int
    ) -> CGSize {
        switch count {
        case 0...2:
            CGSize(width: 540, height: 420)
        case 3...8:
            CGSize(width: 820, height: 540)
        case 9...16:
            CGSize(width: 1_160, height: 700)
        default:
            CGSize(width: 1_480, height: 900)
        }
    }

    private static func rings(
        from concepts: [KnowledgeSystemSnapshot.ConceptItem]
    ) -> [[KnowledgeSystemSnapshot.ConceptItem]] {
        guard !concepts.isEmpty else { return [] }

        let capacities: [Int]
        switch concepts.count {
        case 0...7:
            capacities = [concepts.count]
        case 8...16:
            capacities = [6, concepts.count - 6]
        default:
            capacities = [6, 10, concepts.count - 16]
        }

        var cursor = concepts.startIndex
        return capacities.compactMap { capacity in
            guard capacity > 0 else { return nil }
            let end = concepts.index(
                cursor,
                offsetBy: min(capacity, concepts.distance(from: cursor, to: concepts.endIndex))
            )
            defer { cursor = end }
            return Array(concepts[cursor..<end])
        }
    }

    private static func radiusScales(forRingCount count: Int) -> [CGFloat] {
        switch count {
        case 0: []
        case 1: [0.78]
        case 2: [0.56, 1]
        default: [0.42, 0.72, 1]
        }
    }
}
