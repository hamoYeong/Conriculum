# 현재(V2) SwiftData 저장 계약

확인 기준: 2026-09-09, 현재 앱 소스의 모델·저장 호출 경로. 사용자의 DB를 열어 실제 건수를 조사한 문서는 아니다.

## 저장 경계

현재 제품인 V2는 `ConriculumCurrent` SwiftData 컨테이너를 사용한다. V1은 기존 `Conriculum` 컨테이너와 `Persistence/V1`의 스키마를 그대로 사용하므로 두 버전의 레코드는 물리적으로 섞이지 않는다. 현재 컨테이너는 CloudKit을 사용하지 않는다.

모든 현재 레코드는 `contentVersion`을 갖고, 저장 ID에도 버전과 원본 식별자를 포함한다. 현재 저장소는 `.v2` 레코드만 조회하고 갱신한다. 이후 새 콘텐츠 버전이 같은 모델을 재사용하더라도 버전별 합성 키로 독립성을 유지할 수 있다.

## 저장 모델

| 모델 | 저장 내용 | 도메인 의미 |
| --- | --- | --- |
| `CourseProgressRecord` | 콘텐츠 버전, 마지막 방문 페이지 ID, 갱신 시각 | 사용자가 이어서 시작할 위치 |
| `PageProgressRecord` | 페이지 ID, 완료 여부·완료 시각, 도움 수준, 갱신 시각 | 페이지 완료 증거와 guided/hinted/independent 상태 |
| `GameResponseRecord` | 활동 ID, 선택 ID 목록, 연결 결과, 정오답, 시도 횟수, 응답 시각 | 단일·복수 선택과 연결형 활동의 최종 사용자 응답 |

`CourseProgressStore`는 `CourseProgress` 한 값을 위 세 모델로 정규화한다. 저장할 때 메타데이터와 모든 하위 레코드를 같은 `ModelContext`에서 갱신하고 한 번만 저장한다. 실패하면 컨텍스트를 롤백하여 마지막 성공 상태를 유지한다. 도메인 값에서 제거된 페이지나 활동 응답은 현재 버전 범위 안에서 함께 삭제한다.

완료 시각은 완료 상태가 처음 생길 때 기록하고, 완료 상태가 유지되는 저장에서는 보존한다. 완료가 취소되면 시각도 제거하므로 완료 여부와 완료 증거가 어긋난 레코드는 로드 오류로 취급한다.

## 기존 V2 진행 기록 가져오기

이전 구현은 `UserDefaults`의 `learning.progress.v2`에 `CourseProgress` JSON 전체를 저장했다. 현재 SwiftData에 진행 기록이 없을 때만 이 값을 읽어 현재 저장소에 저장한다.

- 현재 SwiftData 기록이 있으면 그것을 우선한다.
- 가져오기는 같은 데이터를 반복 저장해도 결과가 달라지지 않는다.
- 가져온 뒤에도 `learning.progress.v2` 원본은 삭제하거나 수정하지 않는다.
- 이전 JSON에 도움 수준 필드가 없으면 빈 값으로 복원한다.
- 이후 저장은 현재 SwiftData에만 쓴다.
- `learning.progress.v1`과 V1 SwiftData에는 접근하지 않는다.

이 정책은 V1 제거 전까지 되돌릴 수 있는 안전망을 남기면서, 현재 런타임의 쓰기 경로를 SwiftData 한 곳으로 고정한다.

## 검증과 오류

매핑 계층은 빈 페이지·활동·선택 식별자, 응답 ID 불일치, 중복 레코드, 지원하지 않는 도움 수준, 완료 여부와 완료 시각 불일치, 손상된 연결 JSON을 거부한다. 오류는 레코드명과 필드 경로를 포함한 `PersistenceClientError`로 전달한다.

테스트는 다음 경계를 확인한다.

- 현재와 V1 스키마의 엔티티 집합이 겹치지 않음
- 선택형·연결형 응답과 도움 수준의 왕복 저장
- 제거된 하위 레코드 동기화
- 디스크 컨테이너 재생성 후 복원
- 저장 실패 롤백
- 손상된 응답 필드 식별
- 기존 `UserDefaults` 기록 가져오기와 원본 보존

## 소스 위치

- 모델 등록: `Conriculum/Persistence/PersistenceContainerFactory.swift`
- 저장 구현: `Conriculum/Persistence/Stores/CourseProgressStore.swift`
- 도메인 모델: `Conriculum/Domain/LearningRecords/LearningRecordModels.swift`
- 런타임 연결과 이전 기록 가져오기: `Conriculum/Dependencies/ProgressClient.swift`
