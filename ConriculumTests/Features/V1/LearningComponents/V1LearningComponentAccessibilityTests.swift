import Foundation
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
struct V1LearningComponentAccessibilityTests {
    private enum KeyboardPath: Equatable {
        case buttons
        case picker
        case radioGroup
        case textFieldOrPicker
        case textEditor
        case textFields
    }

    @Test
    func everyInteractiveFixtureHasANonDragKeyboardPath() throws {
        let chapter = try ContentResourceDecoder().decode(
            V1Chapter.self,
            from: .chapter02
        )
        var paths: [V1LearningSectionTag: KeyboardPath] = [:]
        for section in chapter.allPages.flatMap(\.sections) {
            guard let path = keyboardPath(for: section.content) else {
                continue
            }
            if let existingPath = paths[section.content.tag] {
                #expect(existingPath == path)
            } else {
                paths[section.content.tag] = path
            }
        }

        #expect(paths == [
            .cardSorting: .buttons,
            .matching: .picker,
            .choiceWithReason: .radioGroup,
            .fillInBlank: .textFieldOrPicker,
            .codeAssembly: .picker,
            .freeResponse: .textEditor,
            .recallCheck: .textFields,
        ])
    }

    @Test
    func cardSortingCanAssignAValidCardWithoutDragging() throws {
        let section = try #require(
            try interactiveSection(tag: .cardSorting)
        )
        guard case let .cardSorting(content) = section.content else {
            Issue.record("cardSorting fixture를 찾지 못했다.")
            return
        }
        let card = try #require(content.cards.first)
        let group = try #require(content.groups.first)
        var receivedFields: [V1ActivityResponseField] = []
        let activity = V1LearningActivityInput(
            activityID: try #require(section.activityID),
            fields: []
        ) { _, fields in
            receivedFields = fields
        }
        let component = V1CardSortingComponent(
            content: content,
            activity: activity
        )

        component.updateAssignment(cardID: card.id, to: group.id)

        #expect(receivedFields == [
            V1ActivityResponseField(
                key: V1LearningActivityFieldKey.card(card.id),
                values: [group.id]
            )
        ])
    }

    @Test
    func codeAssemblyOptionCardsWriteEveryLineWithoutDragging() throws {
        let section = try #require(
            try interactiveSection(tag: .codeAssembly)
        )
        guard case let .codeAssembly(content) = section.content else {
            Issue.record("codeAssembly fixture를 찾지 못했다.")
            return
        }
        let piece = try #require(content.pieces.first)
        var receivedFields: [[V1ActivityResponseField]] = []
        let activity = V1LearningActivityInput(
            activityID: try #require(section.activityID),
            fields: []
        ) { _, fields in
            receivedFields.append(fields)
        }
        let component = V1CodeAssemblyComponent(
            content: content,
            activity: activity
        )
        let lineCount = content.starterCode.components(
            separatedBy: .newlines
        ).count

        for index in 0..<lineCount {
            component.selectionBinding(at: index).wrappedValue = piece.id
        }

        #expect(receivedFields.count == lineCount)
        #expect(
            receivedFields.enumerated().allSatisfy { pair in
                let (index, fields) = pair
                return fields == [
                    V1ActivityResponseField(
                        key: V1LearningActivityFieldKey.codeLine(index),
                        values: [piece.id]
                    )
                ]
            }
        )
    }

    @Test
    func everyVisibleSaveStateHasASpokenDescription() {
        let states: [V1ActivityDraftSaveState] = [
            .pending,
            .saving,
            .saved(Date(timeIntervalSince1970: 1_700_000_000)),
            .validationError("입력 오류"),
            .persistenceError("저장 오류"),
        ]

        #expect(
            states.allSatisfy {
                $0.accessibilityDescription?.isEmpty == false
            }
        )
        #expect(V1ActivityDraftSaveState.idle.accessibilityDescription == nil)
    }

    private func interactiveSection(
        tag: V1LearningSectionTag
    ) throws -> V1LearningSection? {
        let chapter = try ContentResourceDecoder().decode(
            V1Chapter.self,
            from: .chapter02
        )
        return chapter.allPages
            .flatMap(\.sections)
            .first { $0.content.tag == tag }
    }

    private func keyboardPath(
        for content: V1LearningSectionContent
    ) -> KeyboardPath? {
        switch content {
        case .cardSorting:
            .buttons
        case .matching:
            .picker
        case .choiceWithReason:
            .radioGroup
        case .fillInBlank:
            .textFieldOrPicker
        case .codeAssembly:
            .picker
        case .freeResponse:
            .textEditor
        case .recallCheck:
            .textFields
        default:
            nil
        }
    }
}
