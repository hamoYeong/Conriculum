# Chapter 2 콘텐츠 Read-back

검증일: 2026-08-25

## 기준 원문

- `00 Chapter 2 지도.md`
- `01 현실의 정보를 값으로 바라보기.md`
- `02 값의 종류 비교하기.md`
- `03 정보에 맞는 타입 선택하기.md`
- `04 의미가 드러나는 이름 붙이기.md`
- `05 변하지 않는 값을 선언하기.md`
- `06 타입 명시와 타입 추론 비교하기.md`
- `07 여러 정보를 값으로 구조화하기.md`
- `08 새로운 문제에 적용하고 돌아보기.md`

위 9개 원문을 `chapter-02.json`의 타입화 데이터와 페이지별 조립 테스트에 대조했다.

## 페이지별 확인

| 페이지 | 목표와 흐름 | 필수 활동 | 지식·개인화 | 판정 |
| --- | --- | --- | --- | --- |
| Overview | 6개 완료 기준과 8페이지 경로 | 학습 시작 | direct 3개와 인접 2개 | 일치 |
| 01 | 값과 규칙 구분 | 분류·대응·선택·완료 | 값·리터럴·구체적 값/규칙, 표현 후보 | 일치 |
| 02 | 네 기본 타입 비교 | 분류·대응·선택·완료 | 타입과 String/Int/Double/Bool, 표현 후보 | 일치 |
| 03 | 의미·할 일·상태로 타입 선택 | 선택·분류·자유 작성·완료 | 타입 선택과 네 기본 타입, 판단 기준 후보 | 일치 |
| 04 | 역할이 드러나는 이름 | 대응·코드 조립·선택·완료 | 식별자와 이름 짓기, 개선 기준 후보 | 일치 |
| 05 | 책임 범위로 let/var 판단 | 코드 조립·분류·선택·완료 | 상수/변수·문제 경계, 변경 책임 후보 | 일치 |
| 06 | 타입 추론과 명시 비교 | 대응·빈칸·선택·완료 | 추론/명시·리터럴·이름, 선택 기준 후보 | 일치 |
| 07 | 한 사례의 값 역할과 경계 | 역할 분류·자유 작성·경계 분류·완료 | 값 묶기 표현 후보와 source/target/evidence 관계 | 일치 |
| 08 | 새 문제 적용과 회고 | 분류 2종·코드 조립·자유 작성·회상·완료 | Chapter 핵심 지식, 관계, 확인된 변화/대기 후보 분리 | 일치 |

## 공통 계약

- Overview와 8개 lesson은 `LearningPageContentView`의 공용 section renderer를 사용한다.
- Chapter fixture는 `LearningSectionTag` 22개를 모두 실제 콘텐츠로 포함한다.
- 각 lesson은 목표, 현재 위치, direct knowledge, page knowledge context를 가진다.
- 각 lesson은 학습 상태 선택, 조건부 확장·심화 과제, 완료 판단, 기본·나의 표현 비교, 개인 지식 반영 후보를 정확히 하나씩 가진다.
- 개인 지식 반영과 관계 activity는 선택 사항이고, 완료 판단 activity는 필수다.
- 모든 section/activity/concept/evidence 참조는 존재하는 stable ID를 가리킨다.
- 모든 lesson의 실제 activity 하나를 통해 autosave debounce와 저장 결과를 검증한다.
- Page 07·08의 관계는 source, target, 관계 문장, 이유, 근거 activity를 가진다.
- Page 08 요약은 확인된 표현, 확인된 연결, 확인 전 후보를 서로 다른 필드와 UI 구획으로 유지한다.

## 의도적으로 유지한 경계

- 원문 navigation metadata에는 Page 01의 이전이 Overview로 기록되어 있지만, 001-05 결정에 따라 학습을 시작한 뒤 Page 01의 이전 버튼은 비활성화한다.
- 원문 navigation metadata에는 Page 08 다음이 Chapter 3으로 기록되어 있지만, 앱은 먼저 Chapter 2 완료 요약을 표시한다. Chapter 3으로 자동 이동하지 않는다.
- 개인화 저장 결과를 sidebar와 Page 08 요약에 동적으로 주입하는 흐름은 001-08 범위다. 이번 조립에서는 후보·관계·요약 schema와 공용 component 연결을 보존한다.
- 페이지별 전용 SwiftUI View를 만들지 않는다. 콘텐츠 차이는 schema payload로만 표현한다.

## 시각·접근성 확인

- Overview는 표준 및 접근성 글자 크기에서 확인했다.
- Page 04~08은 760×900 표준 창 크기의 실제 조립 화면을 캡처해 제목, 목표, 학습 블록, 고정 내비게이션과 긴 한국어 문장 잘림 여부를 확인했다.
- Page 08의 마지막 primary action은 `완료 요약`으로 표시된다.
- 공용 component의 keyboard, VoiceOver label/hint, Dynamic Type 검증은 `Documentation/Accessibility/LearningComponentAudit.md`를 따른다.

## 용어

- 도메인과 schema에서는 선택형 추가 학습을 `enrichment`로 표현한다.
- 사용자에게는 `확장·심화 과제`의 의미로 설명한다.
- Swift 언어 문법과 Foundation API 이름을 제외하고 `extension`을 도메인 용어로 사용하지 않는다.
