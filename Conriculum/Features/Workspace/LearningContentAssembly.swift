enum LearningContentAssembly {
    /// 특정 Chapter 번호나 전체 page 수가 아니라 page 자체의 구조로 조립 가능 여부를 판단한다.
    static func isAssembled(_ page: LearningPage) -> Bool {
        switch page.kind {
        case .overview:
            page.order == nil
        case .lesson:
            page.order != nil
        }
    }
}
