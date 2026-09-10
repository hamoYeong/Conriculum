# SwiftData 저장 계약

확인 기준: 2026-09-09, 현재 앱 소스의 모델·저장 호출 경로. 사용자의 DB를 열어 실제 건수를 조사한 문서는 아니다.

## 저장 경계

앱은 `Conriculum` SwiftData 컨테이너를 사용한다. 이 컨테이너는 CloudKit을 사용하지 않는다.

과정 진행은 하나의 `CourseProgressRecord`로 저장한다. 페이지와 활동 레코드는 각각 페이지 ID와 활동 ID로 구분하며, 저장 ID에는 레코드 namespace와 원본 식별자를 포함한다.

## 저장 모델

| 모델 | 저장 내용 | 도메인 의미 |
| --- | --- | --- |
| `CourseProgressRecord` | 마지막 방문 페이지 ID, 갱신 시각 | 사용자가 이어서 시작할 위치 |
| `PageProgressRecord` | 페이지 ID, 완료 여부·완료 시각, 도움 수준, 갱신 시각 | 페이지 완료 증거와 guided/hinted/independent 상태 |
| `GameResponseRecord` | 활동 ID, 선택 ID 목록, 연결 결과, 정오답, 시도 횟수, 응답 시각 | 단일·복수 선택과 연결형 활동의 최종 사용자 응답 |

`CourseProgressStore`는 `CourseProgress` 한 값을 위 세 모델로 정규화한다. 저장할 때 메타데이터와 모든 하위 레코드를 같은 `ModelContext`에서 갱신하고 한 번만 저장한다. 실패하면 컨텍스트를 롤백하여 마지막 성공 상태를 유지한다. 도메인 값에서 제거된 페이지나 활동 응답은 같은 저장 작업에서 함께 삭제한다.

완료 시각은 완료 상태가 처음 생길 때 기록하고, 완료 상태가 유지되는 저장에서는 보존한다. 완료가 취소되면 시각도 제거하므로 완료 여부와 완료 증거가 어긋난 레코드는 로드 오류로 취급한다.

## 검증과 오류

매핑 계층은 빈 페이지·활동·선택 식별자, 응답 ID 불일치, 중복 레코드, 지원하지 않는 도움 수준, 완료 여부와 완료 시각 불일치, 손상된 연결 JSON을 거부한다. 오류는 레코드명과 필드 경로를 포함한 `PersistenceClientError`로 전달한다.

테스트는 다음 경계를 확인한다.

- 스키마가 세 진행 레코드만 포함함
- 선택형·연결형 응답과 도움 수준의 왕복 저장
- 제거된 하위 레코드 동기화
- 디스크 컨테이너 재생성 후 복원
- 저장 실패 롤백
- 손상된 응답 필드 식별

## 소스 위치

- 모델 등록: `Conriculum/Persistence/PersistenceContainerFactory.swift`
- 저장 구현: `Conriculum/Persistence/Stores/CourseProgressStore.swift`
- 도메인 모델: `Conriculum/Domain/LearningRecords/LearningRecordModels.swift`
- 런타임 연결: `Conriculum/Dependencies/ProgressClient.swift`
