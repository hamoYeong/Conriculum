# Chapter 4 구현과 검증

- 이슈: [#26](https://github.com/hamoYeong/Conriculum/issues/26)
- 브랜치: `feat/26-chapter-4-conditions`
- 검증일: 2026-09-05

## 구현 결과

Obsidian의 `학습 체계/00 학습 체계 지도.md`에 있는 새 Chapter 생성 계약을 기준으로 지도·학습 경험 설계·Overview·9개 lesson을 먼저 작성했다. 원문을 다시 읽고 본문 문구와 링크를 대조한 뒤 Chapter JSON, 공용 지식 catalog와 content identity manifest에 반영했다. Git 저장소에는 앱에서 사용하는 JSON만 유지하고 Obsidian Markdown 사본은 포함하지 않는다.

| 경로 | 맡은 판단 | 공용 SwiftUI 작업 컴포넌트 |
| --- | --- | --- |
| 1 | 모호한 규칙을 명확한 질문으로 바꾸기 | ChoiceWithReasonComponent |
| 2 | 질문·Bool 결과·텍스트 구분 | ChoiceWithReasonComponent |
| 3 | 관계에 맞는 비교 연산 선택 | FreeResponseComponent |
| 4 | 경계 포함 여부와 전후 사례 | FreeResponseComponent |
| 5 | 모두·하나 이상·부정 | FreeResponseComponent |
| 6 | 작은 판단과 전체 판단에 이름 붙이기 | FreeResponseComponent |
| 7 | 조합·경계 오류의 반례와 수정 | FreeResponseComponent |
| 8 | 새 문제에 독립 적용 | FreeResponseComponent |
| 9 | 비연속 조건 코드의 책임·흐름·변경 영향 | SemanticChunkReadingComponent |

모든 lesson은 공용 나침반과 마무리, 핵심 지식 하나와 보조 최대 두 개를 사용한다. 전이 페이지의 모델은 응답 작성 뒤 공개한다. 선택 확장과 개인 지식 반영은 마무리 뒤에 둔다. 기존 공용 section schema·renderer가 모든 상호작용을 지원하므로 Chapter 전용 renderer나 새 tag를 추가하지 않았다. Xcode Preview 세 개는 실제 Chapter 4 JSON으로 Overview·조건 조합·의미 단위 조각 화면을 조립한다.

새 지식 6개와 유형이 있는 관계 10개를 catalog에 추가했다. 기존 Bool과 의미 단위 조각 지식 노트에는 Chapter 4 사용 페이지를 연결했다. 기존 concept·page·activity ID는 유지했다.

## Chapter 3 → Chapter 4

Chapter 3 마지막 페이지의 다음 목적지를 `chapter-04-overview`로 연결하고 Chapter 4를 번들 등록 목록에 추가했다. 완료 요약의 다음 챕터 버튼은 기존 `ChapterLearningFeature → LearningWorkspaceFeature → AppFeature` delegate 경로를 사용한다.

첫 진입은 Overview를 연다. 기존 Chapter 4 기록이 있으면 유효한 저장 위치에서 이어가고 완료 페이지 목록을 유지한다. 저장 위치가 사라졌으면 Overview로 복구한다. 저장에 실패하면 완료 요약과 오류를 유지해 다시 시도할 수 있다. Chapter 4의 마지막 목적지는 후속 Chapter 5이며, Chapter 5 자체는 이번 구현 범위에 포함하지 않았다.

## 검증 결과

- macOS Xcode 전체 테스트: 192개 테스트 중 191개 통과. 유일한 실패는 새 재시도 테스트의 `date` 의존성 미설정이었다.
- 고정 시각을 주입한 뒤 `ChapterFourNavigationTests`를 재실행해 전부 통과했다. 새 진입·이어하기·삭제된 저장 위치 복구·저장 실패 후 재시도를 실제 reducer 경로로 확인했다.
- Chapter 4의 모든 section을 480pt·760pt 폭에서 NSHostingView로 조립해 높이와 폭을 검사했다. 좁은 폭의 조건 조합·의미 단위 조각 컴포넌트 PNG도 육안 확인했다.
- 실제 in-memory SwiftData 저장소로 활동 자동 저장과 저장소 재생성 후 응답 read-back을 확인했다. 활동 응답만 저장해도 개인 개념 revision이 생기지 않음을 확인했다.
- 콘텐츠 validator, 기존 Chapter 2·3, 공용 접근성·렌더링·홈·지식 체계 회귀 테스트가 통과했다. VoiceOver를 켠 수동 전 구간 학습은 이번에 수행하지 않았다.
- 마지막 페이지의 Swift 코드 원문을 실행해 `true` 결과를 확인했다.
- `verify_sources.py`로 Chapter 2·3·4 JSON의 30개 페이지, 지식 36개, `다시 보기` 149개, 가까운 지식 범위 30개와 지식 관계의 stable ID를 확인했다.
- `git diff --check` 통과.

```sh
python3 Documentation/Chapter4/verify_sources.py
xcodebuild -project Conriculum.xcodeproj -scheme Conriculum \
  -destination 'platform=macOS' test
```

전체 결과: `Test-Conriculum-2026.09.05_00-35-49-+0900.xcresult`

이동 테스트 재검증: `Test-Conriculum-2026.09.05_00-37-47-+0900.xcresult`

## 기존 학습과 새 지식의 다시 보기 연결

Chapter 2·3의 기존 학습과 Chapter 4의 새 지식을 양방향으로 다시 대조했다. 앱 catalog에 포함된 지식 36개는 각 Obsidian 지식 노트의 `## 다시 보기` 섹션 하나에 직접 사용 페이지와 완료 뒤 살펴볼 가까운 지식 페이지를 합쳤다. 같은 지식과 페이지가 두 경로에 모두 있으면 직접 사용을 우선하고, Chapter와 페이지 순서로 정렬했다. 기존 Chapter 1 자료만 참조하는 지식 노트 3개도 같은 단일 섹션 형식으로 정리했다.

Knowledge Catalog의 `revisitPages`에는 총 149개 연결의 Chapter·페이지 stable ID, 제목, 순서, 연결 종류와 이유를 저장했다. SwiftUI의 전체 지식 체계 상세와 학습 중 지식 상세는 이 목록을 보여 주며, 항목을 선택하면 해당 Chapter의 학습 페이지로 이동한다. 링크 노출과 이동은 배운 지식이나 내 지식 상태를 열지 않는다.

기존 지식과 새 지식 사이에 지식 그래프 관계 12개를 양쪽 노트에 기록했고, Chapter 2·3·4의 21개 페이지에는 해당 페이지에서 이해에 도움이 되는 가까운 지식을 연결했다. `학습 체계/00 학습 체계 지도.md`에도 단일 다시 보기 섹션, 중복 우선순위, 정렬, JSON과 SwiftUI 이동, 학습 상태 분리, 새 Chapter 작성 시 기존 페이지 재검토 규칙을 추가했다.

전체 macOS 회귀 테스트는 197개 테스트(매개변수 실행 209회)가 모두 통과했다. 결과 번들은 `Test-Conriculum-2026.09.05_09-40-05-+0900.xcresult`다.
