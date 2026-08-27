import CoreGraphics
import Testing

@testable import Conriculum

@MainActor
struct KnowledgeGraphLayoutTests {
    @Test
    func sameCatalogAndSizeAlwaysProduceTheSameLayout() throws {
        let snapshot = try makeSnapshot()
        let size = CGSize(width: 900, height: 640)

        let first = KnowledgeGraphLayout(
            concepts: snapshot.concepts,
            collections: snapshot.collections,
            relations: snapshot.baseRelations,
            availableSize: size
        )
        let second = KnowledgeGraphLayout(
            concepts: snapshot.concepts,
            collections: snapshot.collections,
            relations: snapshot.baseRelations,
            availableSize: size
        )

        #expect(first == second)
        #expect(first.positions.count == snapshot.concepts.count)
        #expect(
            first.position(for: "concept-type")
                == CGPoint(
                    x: first.canvasSize.width / 2,
                    y: first.canvasSize.height / 2
                )
        )
    }

    @Test
    func everyNodeStaysInsideTheScrollableCanvas() throws {
        let snapshot = try makeSnapshot()
        let layout = KnowledgeGraphLayout(
            concepts: snapshot.concepts,
            collections: snapshot.collections,
            relations: snapshot.baseRelations,
            availableSize: CGSize(width: 520, height: 360)
        )
        let halfWidth = KnowledgeGraphLayout.nodeSize.width / 2
        let halfHeight = KnowledgeGraphLayout.nodeSize.height / 2

        #expect(layout.positions.values.allSatisfy { point in
            point.x >= halfWidth
                && point.x <= layout.canvasSize.width - halfWidth
                && point.y >= halfHeight
                && point.y <= layout.canvasSize.height - halfHeight
        })
    }

    @Test
    func filteredCatalogNodesDoNotOverlap() throws {
        let snapshot = try makeSnapshot()
        for conceptCount in 1...snapshot.concepts.count {
            let layout = KnowledgeGraphLayout(
                concepts: Array(snapshot.concepts.prefix(conceptCount)),
                collections: snapshot.collections,
                relations: snapshot.baseRelations,
                availableSize: CGSize(width: 900, height: 640)
            )
            let positions = layout.positions.values.map { point in
                CGRect(
                    x: point.x - KnowledgeGraphLayout.nodeSize.width / 2,
                    y: point.y - KnowledgeGraphLayout.nodeSize.height / 2,
                    width: KnowledgeGraphLayout.nodeSize.width,
                    height: KnowledgeGraphLayout.nodeSize.height
                )
                .insetBy(dx: -2, dy: -2)
            }

            for index in positions.indices {
                for otherIndex in positions.indices where otherIndex > index {
                    #expect(
                        !positions[index].intersects(positions[otherIndex])
                    )
                }
            }
        }
    }

    @Test
    func emptyFilteredResultHasNoPositions() {
        let layout = KnowledgeGraphLayout(
            concepts: [],
            collections: [],
            relations: [],
            availableSize: CGSize(width: 720, height: 520)
        )

        #expect(layout.positions.isEmpty)
    }

    private func makeSnapshot() throws -> KnowledgeSystemSnapshot {
        let catalog = try ContentResourceDecoder().decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        )
        return KnowledgeSystemSnapshotComposer().compose(
            catalog: catalog,
            revisions: [],
            personalRelations: []
        )
    }
}
