# Chapter 2 Vertical Slice 릴리스 검증

검증일: 2026-08-26

## 판정

001 Epic의 Chapter 2 vertical slice는 macOS clean build, 전체 자동 테스트, 실제 앱 E2E와 원본 read-back을 통과했다. 구현에서 확인한 제품 의미는 Manyfast 동기화 기준과 Chapter 2·지식 체계 원문에 일치하며, Chapter 1 원문은 변경하지 않았다.

## 검증 기준

- Xcode project: `Conriculum.xcodeproj`
- shared scheme: `Conriculum`
- targets: `Conriculum`, `ConriculumTests`
- destination: `platform=macOS,arch=arm64` (`My Mac`)
- configuration: `Debug`
- TCA: `1.26.1` exact pin
- 콘텐츠 기준: Chapter 2 지도와 `01`~`08` 원문, 지식 체계 지도, 개인 지식화 원칙, 값과 타입 분류 안내
- 기획 기준: `000 Manyfast 개인 지식화 기획 동기화`와 001 Epic의 공통 아키텍처 계약

## Epic read-back

| 기준 의미 | 구현 경계 | 검증 근거 | 판정 |
| --- | --- | --- | --- |
| Home에서 학습 증거와 개인 지식 변화를 구분하고 Chapter 2를 시작·재개한다. | `AppFeature`, `HomeFeature`, `HomeSnapshotComposer` | App/Home reducer·presentation·rendering tests, 실제 E2E start/resume | 일치 |
| overview와 8개 페이지를 선형 경로와 타입화 콘텐츠로 제공한다. | `chapter-02.json`, `Chapter02ContentAssembly`, 공용 `LearningPageContentView` | [콘텐츠 read-back](./ContentReadBack.md), 콘텐츠 validator·전체 조립 tests | 일치 |
| 현재 페이지의 비선형 기본 지식을 workspace sidebar에서 보여 준다. | `LearningWorkspaceFeature`, `KnowledgeContextFeature` | 페이지별 context·sidebar mode·Focus Mode tests, 실제 E2E | 일치 |
| 활동 응답·진도·증거·개인 revision·관계를 서로 다른 사용자 데이터로 저장하고 재실행에서 복구한다. | purpose-specific dependency clients, SwiftData Records/Mappers, `UserDataStore` | mapper round trip, file-backed relaunch recovery, 실제 앱 재실행 E2E | 일치 |
| 기본 지식은 보존하고 개인 표현·관계는 별도 overlay로 명시적 확인 뒤 저장한다. | `ConceptInspectorFeature`, `PersonalRelationEditorFeature`, 개인화 review | 확인 전 미저장, 확인 후 read-back, 저장 실패 rollback tests | 일치 |
| 학습 완료와 개인화 양을 합치지 않고 확인 전 후보와 저장된 변화를 구분한다. | completion evidence와 knowledge change collection의 독립 모델 | Page 08·Home summary·promotion tests, 실제 E2E | 일치 |
| 마지막 페이지는 Chapter 3으로 이동하지 않고 Chapter 2 완료 요약을 표시한다. | `ChapterLearningFeature`, `LearningWorkspaceFeature` | last-page reducer·assembly tests, 실제 E2E | 일치 |
| keyboard·VoiceOver·큰 글자·비드래그 입력 경로를 제공한다. | 공용 학습 component와 macOS SwiftUI 접근성 | [학습 컴포넌트 접근성 감사](../Accessibility/LearningComponentAudit.md), rendering/accessibility tests | 일치 |

## 원본 보호 확인

- 원본 Obsidian 학습·지식 문서는 앱 저장소 밖에 있으며 이번 구현에서는 읽기 전용 기준선으로만 사용했다.
- Chapter 1 폴더의 Markdown 9개 파일은 검증 전후 합산 SHA-256이 `3f49317d97d78c50f7b4b01b81dc24f2bc5d59c9d80f5e623ceb74c9d89a5158`로 같다.
- Manyfast/지식/학습/Stage 1/Chapter 2 지도 기준 문서 7개의 합산 SHA-256은 검증 전후 `259062f72cf34533bd8c52918b8dfca6ec8a052f669d5ee2969161e593705d53`로 같다.
- 앱 저장소 전체 Git 이력에는 Chapter 1 경로가 없다. Chapter 1 콘텐츠를 복사하거나 수정한 변경도 없다.
- 콘텐츠 세부 대조와 의도적으로 유지한 navigation 경계는 [Chapter 2 콘텐츠 Read-back](./ContentReadBack.md)에 기록했다.

## Issue 완료 지도

| Issue | GitHub | 병합 근거 |
| --- | --- | --- |
| 001-01 프로젝트 기준선과 TCA 앱 셸 | [#1](https://github.com/hamoYeong/Conriculum/issues/1) | PR #2, merge `07f2733` |
| 001-02 Domain과 콘텐츠 스키마 | [#3](https://github.com/hamoYeong/Conriculum/issues/3) | PR #4, merge `5bd7a0e` |
| 001-03 Dependency와 SwiftData 영속성 | [#5](https://github.com/hamoYeong/Conriculum/issues/5) | PR #6, merge `52b2d6f` |
| 001-04 App 라우팅과 증거 중심 Home | [#7](https://github.com/hamoYeong/Conriculum/issues/7) | PR #8, merge `a59b0e2` |
| 001-05 Learning Workspace와 페이지 이동 | [#10](https://github.com/hamoYeong/Conriculum/issues/10) | PR #11, merge `9c1adc6` |
| 001-06 공용 학습 컴포넌트 | [#12](https://github.com/hamoYeong/Conriculum/issues/12) | PR #13, merge `7fefa8c` |
| 001-07 Chapter 2 콘텐츠 조립 | [#14](https://github.com/hamoYeong/Conriculum/issues/14) | PR #15, merge `ef80a13` |
| 001-08 지식 문맥과 개인화 Vertical Slice | [#16](https://github.com/hamoYeong/Conriculum/issues/16) | PR #17, merge `0e43250` |
| 001-09 통합 검증과 릴리스 정리 | [#18](https://github.com/hamoYeong/Conriculum/issues/18) | 각 Ticket commit과 최종 PR은 Issue #18에 기록 |

Home의 샘플 데이터 안내 문구를 바로잡은 PR #9(`e5090d4`)는 001-04와 001-05 사이의 별도 copy 보정이며, 기능 범위를 추가하지 않는다.

## 최종 실행 결과

```sh
xcodebuild -quiet -project Conriculum.xcodeproj \
  -scheme Conriculum \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/conriculum-001-09-05-final-derived-data \
  -clonedSourcePackagesDirPath /tmp/conriculum-source-packages \
  -skipMacroValidation clean build

xcodebuild -quiet -project Conriculum.xcodeproj \
  -scheme Conriculum \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/conriculum-001-09-05-final-derived-data \
  -clonedSourcePackagesDirPath /tmp/conriculum-source-packages \
  -skipMacroValidation \
  -resultBundlePath /tmp/conriculum-001-09-05-final-1428.xcresult test
```

- clean build: passed
- xcresult aggregate: 136 passed, 0 failed, 0 skipped
- actual macOS E2E: Issue #18의 9개 시나리오 passed
- compiler warning: 0
- Xcode 환경 진단: 빈 DVT build-number 경고 2줄. 앱 소스나 테스트 실패와 무관하다.
- `git diff --check`: passed
- 문서 링크: repository 상대 링크와 GitHub Issue #1, #3, #5, #7, #10, #12, #14, #16, #18 확인

xcresult의 장치별 표시는 동적 파라미터 테스트 1개를 두 실행으로 펼쳐 `passedTests: 137`로 표시한다. 최상위 집계의 `totalTestCount`와 `passedTests`는 모두 136이며 최종 결과는 `Passed`다.

## 후속 범위

이번 검증에서 새로 발견된 릴리스 차단 결함은 없다. Chapter 3 이후 콘텐츠, 전체 지식 그래프 편집, 계정·동기화, 최종 시각 디자인 확정 등 001 Epic이 명시한 범위 밖 항목은 이 vertical slice에 섞지 않는다.
