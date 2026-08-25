# 학습 컴포넌트 접근성 감사

- 감사일: 2026-08-25
- 범위: `LearningSectionContent`를 표시하는 공용 macOS SwiftUI 컴포넌트
- 기준: 마우스와 드래그 없이 완료 가능, VoiceOver가 제목·조작 목적·현재 상태·오류를 말로 전달

## Keyboard-only walkthrough

| 활동 | 키보드 경로 | 결과 |
| --- | --- | --- |
| 카드 분류 | 카드 Button 선택 → 분류 영역 Button 실행 | 통과 |
| 연결하기 | 항목별 Picker 선택 → 이유 TextField 입력 | 통과 |
| 선택과 이유 | radio group 선택 → 이유 TextField 입력 | 통과 |
| 빈칸 채우기 | 빈칸별 TextField 또는 Picker | 통과 |
| 코드 조립 | 각 코드 줄의 Picker에서 이름 선택 | 통과 |
| 자유 응답 | TextEditor 입력 → 예시 Button 실행 | 통과 |
| 되짚기 | 기록별 TextField 입력 | 통과 |
| 완료 점검 | 상태 Button 선택 | 통과 |
| 개인 지식 후보 | TextEditor/TextField 입력 → 확인 Button과 대화상자 | 통과 |

카드 분류에는 드래그와 같은 assignment 함수를 쓰는 버튼 경로와 VoiceOver 사용자 지정 action이 있다. 코드 조립의 이름 조각은 참고 정보로 읽히며, 실제 입력은 각 줄의 Picker만으로 완료할 수 있다.

## VoiceOver 의미 감사

- 학습 block 제목은 level 2 heading, 완료 기준 제목은 level 3 heading으로 노출한다.
- 모든 Button, Picker, TextField, TextEditor에 화면 문맥을 포함한 label을 제공한다.
- 선택·배치·저장 상태는 아이콘이나 색 외에 `선택됨`, `배치됨`, `저장됨` 등의 value와 text로 전달한다.
- 카드 분류와 코드 조립은 드래그 대체 조작을 hint로 설명한다.
- Swift 코드와 가로 목록은 하나의 의미 있는 요소로 묶고 전체 내용을 value로, 가로 탐색 방법을 hint로 제공한다.
- 저장 대기·저장 중·저장됨·검증 오류·영속화 오류는 말로 읽을 description을 가지며, 영속화 오류의 재시도 Button은 입력을 유지한다는 hint를 제공한다.
- 개인 지식 반영과 관계 저장은 학습 응답 저장과 별도라는 확인 대화상자를 유지한다.

## 자동 검증

- 실제 Chapter 2 fixture의 모든 입력 tag가 비드래그 keyboard 경로를 갖는지 확인한다.
- 카드 분류의 비드래그 assignment와 코드 조립의 줄별 Picker binding을 동작 테스트한다.
- 모든 가시적 draft 저장 상태에 spoken description이 있는지 확인한다.
- 모든 컴포넌트를 표준 및 accessibility 글자 크기로 렌더링해 clipping과 비정상 크기를 검사한다.

001-07에서 실제 Chapter 페이지를 조립한 뒤에는 동일한 순서로 통합 화면의 Keyboard/VoiceOver walkthrough를 다시 실행한다.
