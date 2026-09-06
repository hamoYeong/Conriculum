import Foundation

/// ver.2 manifest는 ver.1 Chapter schema와 독립적으로 진입 순서와 리소스 소유권을 정의한다.
struct V2ContentManifest: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let contentVersion: ContentVersion
    let id: String
    let locale: String
    let title: String
    let stages: [V2Stage]

    var chapters: [V2Chapter] {
        stages.flatMap(\.chapters)
    }

    func stage(id: String) -> V2Stage? {
        stages.first { $0.id == id }
    }

    func chapter(id: String) -> V2Chapter? {
        chapters.first { $0.id == id }
    }

    func pageReference(id: String) -> V2PageReference? {
        chapters.lazy.flatMap(\.pages).first { $0.id == id }
    }
}

struct V2Stage: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable, Equatable, Sendable {
        case game
        case learning
    }

    let id: String
    let order: Int
    let title: String
    let summary: String
    let kind: Kind
    let chapters: [V2Chapter]
}

struct V2Chapter: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let stageID: String
    let order: Int
    let title: String
    let summary: String
    let pages: [V2PageReference]

    var firstPageID: String? {
        pages.sorted {
            ($0.order, $0.id) < ($1.order, $1.id)
        }.first?.id
    }
}

struct V2PageReference: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let order: Int
    let title: String
    let goal: String
    let resource: String
}

/// Obsidian 페이지의 의미 있는 절을 보존한 ver.2 독립 페이지 schema.
struct V2LearningPage: Codable, Equatable, Identifiable, Sendable {
    let schemaVersion: Int
    let contentVersion: ContentVersion
    let id: String
    let stageID: String
    let chapterID: String
    let order: Int
    let title: String
    let goal: String
    let sourcePath: String
    let blocks: [V2ContentBlock]
    let termRefs: [V2TermReference]
    let knowledgeConceptIDs: [KnowledgeConceptID]
}

struct V2ContentBlock: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable, Equatable, Sendable {
        case mission
        case wordSystem
        case scene
        case game
        case boss
        case unlock
        case codeStage
        case prediction
        case clueScan
        case chunking
        case flow
        case changeExperiment
        case reconstruction
        case transfer
        case closure
        case support
    }

    let id: String
    let order: Int
    let kind: Kind
    let title: String
    let markdown: String
    let activities: [V2GameActivity]
    let wordSystem: V2WordSystem?
    let knowledgeUnlock: V2KnowledgeUnlock?
}

struct V2WordSystem: Codable, Equatable, Sendable {
    struct Entry: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let term: String
        let parentSystem: String
        let role: String
        let firstThought: String
    }

    let entries: [Entry]
}

struct V2KnowledgeUnlock: Codable, Equatable, Sendable {
    struct Card: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let title: String
        let summary: String
    }

    let cards: [Card]
    let completionCriteria: String
    let beginnerHint: String
    let advancedTip: String
}

struct V2GameActivity: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable, Equatable, Sendable {
        case singleChoice
        case multipleChoice
        case matching
    }

    struct Option: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let title: String
    }

    struct Pair: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let left: String
        let right: String
    }

    let id: String
    let kind: Kind
    let promptMarkdown: String
    let options: [Option]
    let pairs: [Pair]
    let correctOptionIDs: Set<String>
    let correctFeedback: String
    let incorrectFeedback: String
}

struct V2TermReference: Codable, Equatable, Identifiable, Sendable {
    struct Anchor: Codable, Equatable, Sendable {
        let blockID: String
        let occurrence: Int
    }

    let id: String
    let termID: String
    let anchor: Anchor
    let placement: String
}
