/// 지식 JSON을 지식 화면으로 전달하는 루트 값.
struct KnowledgeCatalog: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let id: String
    let title: String
    let collections: [KnowledgeCollection]
    let concepts: [KnowledgeConcept]
    let relations: [KnowledgeRelation]
}
