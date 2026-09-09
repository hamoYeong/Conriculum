# V1 제거 준비 점검

점검 기준: 2026-09-09, `issue/28-learning-system-v2` 브랜치와 구현 계약 「콘텐츠 ver.1–ver.2 병렬 운영과 안전한 제거 계약」.

## 제품 전제

Conriculum은 아직 배포되지 않았고 V1을 사용한 실제 사용자가 없다. 따라서 V1은 출시된 이전 버전이 아니라 개발 중 교체된 구현으로 취급한다.

이 결정에 따라 구현 계약의 아래 항목은 적용 대상 없음으로 확정한다.

- V1 진행 기록 보관·열람·내보내기
- 저장된 V1 선택과 위치의 업데이트 호환
- V1 딥 링크·북마크의 종료 안내나 V2 대응표
- V1 종료 공지와 지원 문구
- V1 진입점 제거 뒤의 안정화 릴리스
- 배포 빌드 롤백을 위한 별도 V1 태그와 바이너리 보관

개발 과정에서 생성한 V1 로컬 데이터는 제품 데이터로 간주하지 않는다. V1 레코드를 V2 완료 기록으로 이전하지 않으며, V2는 처음 설치한 앱처럼 빈 진행 상태에서 시작한다. 소스 복구는 Git 기록과 `release/ver-1` 브랜치의 `18558eb` 커밋으로 충분하다.

## 결론

사용자 데이터·출시 호환 선행 조건은 모두 해소되었다. V2 단독 경로 검증과 아래 기술적 결합 제거를 마치면 V1 코드와 에셋을 한 이슈에서 완전 삭제할 수 있다.

현재 PR은 이슈 #28의 완료 조건에 따라 V1 병렬 동작을 보존한다. 실제 삭제는 후속 이슈에서 수행하되, 별도의 보관 기능이나 안정화 릴리스를 기다릴 필요는 없다.

## 확인된 V2 준비 상태

- [x] 신규 실행의 기본 선택은 V2다.
- [x] V2 manifest, 학습 페이지, 지식 카탈로그가 `Resources/Content`에 독립적으로 존재한다.
- [x] V2 홈, 학습, 지식 책장 라우트가 존재한다.
- [x] V2 진행 기록은 `ConriculumCurrent` SwiftData 컨테이너에 저장되고 V1 컨테이너와 스키마가 분리되어 있다.
- [x] 마지막 위치, 완료 증거, 도움 수준, 단일·복수 선택과 연결 응답을 V2 저장소에서 복원한다.
- [x] V1 전용 소스와 리소스의 주 경계는 각 레이어의 `V1/` 폴더로 이동했다.
- [x] V1과 V2를 함께 포함한 전체 macOS 테스트가 통과한다.

## 완전 삭제 이슈의 남은 기술 작업

### 1. 앱 루트를 V2 전용으로 단순화

- `AppAssembly`의 V1 SwiftData 컨테이너와 네 V1 클라이언트를 제거한다.
- `ConriculumApp`의 V1 의존성 주입과 V1 model container 연결을 제거한다.
- `AppFeature`와 `AppView`에서 V1 workspace 상태·라우트·화면을 제거한다.
- 앱 시작이 V1 컨테이너 생성 성공 여부에 의존하지 않게 한다.

### 2. 홈과 버전 선택 제거

- `HomeFeature`의 V1 로드, snapshot, pending review, V1 진입 액션을 제거한다.
- `HomeView`의 V1 홈과 “ver.1 기존 과정 보기” 버튼을 제거한다.
- 버전 토글과 `ContentSettingsClient`를 제거하고 V2 홈을 유일한 홈으로 사용한다.
- `ContentVersion.v1`과 선택 버전 복원 테스트를 제거한다.
- V2 진행은 빈 SwiftData 또는 현재 V2 기록에서만 시작한다.

### 3. 지식 화면과 공용 UI의 V1 결합 제거

- `KnowledgeSystemFeature`의 V1 로딩 분기, V1 클라이언트, V1 학습 delegate를 제거한다.
- `KnowledgeSystemView` Preview를 V2 지식 JSON으로 전환한다.
- V1 전용 `LearnedKnowledgeResolver`와 지식 변경 모음 UI를 V1 코드와 함께 제거한다.
- `LearningComponentChrome`에서 V1 콘텐츠 타입을 사용하는 컴포넌트를 제거하고 V2가 쓰는 공용 부분만 남긴다.
- `ContentResourceDecoder`의 V1 전용 오류 변환 분기를 제거한다.

### 4. 전용 소스·에셋·테스트 삭제

아래 경계를 삭제한다.

- `Conriculum/Content/V1`
- `Conriculum/Dependencies/V1`
- `Conriculum/Domain/V1`
- `Conriculum/Features/V1`
- `Conriculum/Persistence/V1`
- `Conriculum/Resources/V1`
- `ConriculumTests` 아래의 모든 V1 전용 테스트
- `Documentation/Persistence/V1`

버전 폴더 밖에 남은 App, Home 테스트에는 V1과 V2 시나리오가 섞여 있다. 파일을 통째로 지우지 말고 V2 수용 조건만 남긴다. V1 전용 Home·KnowledgeSystem·챕터 이동 테스트는 이미 `ConriculumTests/Features/V1` 아래로 격리했다.

### 5. V2 단독 검증

- [ ] V1 심볼과 `Resources/V1` 참조가 제품·테스트 타깃에 남지 않는다.
- [ ] clean build와 전체 테스트가 통과한다.
- [ ] 빈 저장소에서 V2 홈→챕터→학습→지식 책장 흐름이 열린다.
- [ ] 앱 재실행 뒤 V2 마지막 위치, 완료 증거, 게임 응답, 도움 수준이 복원된다.
- [ ] 오프라인에서 V2 학습 JSON·지식 카탈로그·용어 도움을 사용할 수 있다.
- [ ] 키보드와 VoiceOver로 Stage 1 단일·복수 선택, 연결 활동과 Stage 2 학습을 완료할 수 있다.
- [ ] V1을 제거한 빌드가 개발 중 생성된 V1 저장 데이터를 읽거나 V2로 이전하지 않는다.

## 커밋 순서

후속 삭제 이슈에서는 리뷰와 되돌리기가 쉽도록 다음 흐름을 각각 커밋한다.

1. 앱 루트·라우팅·홈을 V2 전용으로 전환
2. 지식 화면과 공용 UI의 V1 결합 제거
3. V1 소스·리소스·Persistence 삭제
4. V1 테스트·문서·버전 설정 삭제
5. V2 단독 회귀 검증 보강
