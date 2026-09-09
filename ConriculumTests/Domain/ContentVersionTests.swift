import Testing

@testable import Conriculum

struct ContentVersionTests {
    @Test
    func sameRawValueInDifferentVersionsProducesDifferentIdentity() {
        let v1 = VersionedContentID(version: .v1, rawValue: "chapter-1")
        let v2 = VersionedContentID(version: .v2, rawValue: "chapter-1")

        #expect(v1 != v2)
        #expect(Set([v1, v2]).count == 2)
    }

    @Test
    func progressKeyKeepsVersionNamespace() {
        #expect(
            ProgressKey(version: .v1, contentID: "page-1")
                != ProgressKey(version: .v2, contentID: "page-1")
        )
    }
}
