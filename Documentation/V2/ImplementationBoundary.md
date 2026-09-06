# 학습 체계 ver.2 구현 경계

이 문서는 Obsidian의 `학습 체계 ver.2/구현 계약`을 앱 구조에 적용한 결정 기록이다.

## 보존할 경계

- ver.1의 `CurriculumClient`, 기존 JSON, SwiftData ID와 기록은 변경하지 않는다.
- 모든 새 ver.2 ID와 진행 키는 `ContentVersion.v2`와 결합한다.
- ver.2 manifest 또는 page 하나의 실패는 ver.1 로딩에 전파하지 않는다.
- 홈의 초기 선택은 ver.1이며, 사용자가 명시적으로 바꾼 선택만 별도 설정에 저장한다.

## 공유할 경계

- `Bundle → Data → Decodable` 변환은 `BundledJSONResource`를 주입받는 기존 `ContentResourceDecoder`를 함께 사용한다.
- 글꼴, 카드 표면, 내비게이션 버튼 같은 시각 기반은 공유할 수 있다.
- Stage 1 게임과 Stage 2 읽기 활동은 학습 목적이 다르므로 별도 SwiftUI 렌더러로 둔다.

## 출시 범위

이번 이슈는 Phase 1~3의 사용자 확인 가능한 vertical slice다. ver.1 제거와 진행 자동 이전은 하지 않는다. ver.2의 모든 Stage 1·2 문서를 독립 JSON에 담고, 홈 토글과 Chapter 직접 진입, 버전별 이어하기를 제공한다.
