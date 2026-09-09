/// 현재 과정과 V1 과정이 각자의 JSON을 같은 지식 화면 계약으로 전달하는 루트 값.
struct KnowledgeCatalog: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let id: String
    let title: String
    let collections: [KnowledgeCollection]
    let concepts: [KnowledgeConcept]
    let relations: [KnowledgeRelation]
}
