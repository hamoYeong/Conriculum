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
        let usesExpandableRings = stableConcepts.count > 16

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
            let radiusX: CGFloat
            let radiusY: CGFloat
            if usesExpandableRings {
                let radius = Self.expandableRingSpacing
                    * CGFloat(ringIndex + 1)
                radiusX = radius
                radiusY = radius
            } else {
                let scale = radiusScales[ringIndex]
                radiusX = maximumRadiusX * scale
                radiusY = maximumRadiusY * scale
            }
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
            return CGSize(width: 540, height: 420)
        case 3...8:
            return CGSize(width: 820, height: 540)
        case 9...16:
            return CGSize(width: 1_160, height: 700)
        default:
            let ringCount = expandableRingCapacities(
                forConceptCount: max(count - 1, 0)
            ).count
            let outerRadius = expandableRingSpacing * CGFloat(ringCount)
            return CGSize(
                width: max(
                    1_160,
                    2 * (outerRadius + nodeSize.width / 2 + 48)
                ),
                height: max(
                    700,
                    2 * (outerRadius + nodeSize.height / 2 + 42)
                )
            )
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
        case 8...15:
            capacities = [6, concepts.count - 6]
        default:
            capacities = expandableRingCapacities(
                forConceptCount: concepts.count
            )
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

    /// 큰 catalog는 고정된 세 ring에 남은 노드를 몰아넣지 않는다.
    /// ring 반지름과 수용량을 함께 늘려 인접·교차 ring 모두 노드 대각선보다 멀게 둔다.
    private static func expandableRingCapacities(
        forConceptCount count: Int
    ) -> [Int] {
        guard count > 0 else { return [] }

        var remaining = count
        var ringNumber = 1
        var capacities: [Int] = []
        while remaining > 0 {
            let capacity = min(remaining, ringNumber * 6)
            capacities.append(capacity)
            remaining -= capacity
            ringNumber += 1
        }
        return capacities
    }

    /// 테스트가 사용하는 2pt 외곽 여백까지 포함한 노드 대각선에 추가 간격을 둔다.
    private static var expandableRingSpacing: CGFloat {
        hypot(nodeSize.width + 4, nodeSize.height + 4) + 24
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
