enum Chapter02ContentAssembly {
    static let assembledLessonCount = 8

    static func isAssembled(_ page: LearningPage) -> Bool {
        guard page.kind == .lesson else { return true }
        guard let order = page.order else { return false }
        return order <= assembledLessonCount
    }
}
