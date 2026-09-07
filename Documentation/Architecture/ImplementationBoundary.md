# 현재 학습 체계 구현 경계

이 문서는 Obsidian의 `학습 체계 ver.2/구현 계약`을 현재 앱 구조에 적용한 결정 기록이다. 현재 제품 기준은 ver.2이며, 소스 코드에서 버전 접두사가 없는 이름은 현재 구현을 뜻한다.

## 보존할 경계

- ver.1 구현은 `V1/` 폴더와 `V1` 접두사로 격리하고 기존 SwiftData ID와 기록을 유지한다.
- 현재 콘텐츠의 ID와 진행 키는 기존 사용자 데이터와의 호환을 위해 계속 `ContentVersion.v2`와 결합한다.
- 현재 manifest 또는 page 하나의 실패는 ver.1 로딩에 전파하지 않는다.
- 홈의 초기 선택은 현재 버전인 ver.2이며, 사용자가 명시적으로 바꾼 선택은 별도 설정에 저장한다.

## 공유할 경계

- `Bundle → Data → Decodable` 변환은 `BundledJSONResource`를 주입받는 기존 `ContentResourceDecoder`를 함께 사용한다.
- 글꼴, 카드 표면, 내비게이션 버튼 같은 시각 기반은 공유할 수 있다.
- Stage 1 게임과 Stage 2 읽기 활동은 학습 목적이 다르므로 별도 SwiftUI 렌더러로 둔다.

## 출시 범위

현재 단계에서는 ver.1 제거와 진행 자동 이전을 하지 않는다. 현재 Stage 1·2 문서를 독립 JSON에 담고, 홈 토글과 Chapter 직접 진입, 버전별 이어하기를 제공한다. ver.1 제거는 `ProjectStructure.md`의 삭제 경계를 따른 별도 작업으로 진행한다.
