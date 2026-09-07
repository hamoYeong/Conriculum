# 프로젝트 폴더 구조 원칙

## 기준 버전

ver.2가 현재 제품 기준이다. 따라서 버전 접두사가 없는 폴더, 파일, Swift 타입은 현재 구현을 뜻한다. ver.1 전용 구현은 각 레이어 아래의 `V1/` 폴더에 두고 파일과 최상위 타입에도 `V1` 접두사를 붙인다.

콘텐츠 ID와 저장 키의 `v2` 표기는 소스 구조 접두사가 아니라 이미 저장된 데이터의 정체성이다. `v2.s1.c1` 같은 ID와 `learning.progress.v2` 같은 키는 마이그레이션 없이 이름을 바꾸지 않는다.

## 폴더가 깊어지는 순서

폴더는 아래 네 기준을 순서대로 적용해 깊어진다.

1. 레이어: `App`, `Content`, `Dependencies`, `Domain`, `Features`, `Persistence`, `Resources`
2. 버전 소유권: 현재 또는 공유 구현은 바로 배치하고, ver.1 전용 구현만 `V1/` 아래에 배치한다.
3. 기능 또는 역할: 예를 들어 `Content/Decoding`, `Content/Loading`, `Features/Home`, `Features/Learning`으로 나눈다.
4. 세부 구현: 서로 함께 바뀌는 파일이 세 개 이상이거나 별도 테스트 경계가 필요할 때만 한 단계 더 나눈다.

즉, 파일 종류만 같다는 이유로 먼저 묶지 않는다. 어느 레이어의 어떤 버전이 어떤 기능을 담당하는지 바깥 폴더부터 읽히게 한다.

## 현재 구조

```text
Conriculum/
├── App/                         # 현재와 V1을 조립하고 화면 전환을 소유
├── Content/
│   ├── Models.swift             # 현재 학습 JSON 모델
│   ├── Decoding/                # 버전 공용 JSON 디코딩 기반
│   ├── Loading/                 # 현재 번들 콘텐츠 로딩
│   ├── Validation/              # 현재 콘텐츠 검증
│   └── V1/                      # V1 로딩·스키마·검증
├── Dependencies/
│   ├── ContentClient.swift      # 현재 콘텐츠 의존성
│   ├── ProgressClient.swift     # 현재 진행 의존성
│   └── V1/                      # V1 전용 클라이언트
├── Domain/
│   ├── Knowledge/               # 현재와 V1이 함께 쓰는 지식 모델
│   └── V1/                      # V1 커리큘럼·학습 기록·프로필
├── Features/
│   ├── Home/                    # 버전 선택과 현재 홈
│   ├── Learning/                # 현재 학습 화면과 Stage 컴포넌트
│   ├── KnowledgeSystem/         # 버전별 카탈로그를 받는 책장 셸
│   ├── Shared/                  # 양쪽 학습 화면이 실제로 함께 쓰는 UI
│   └── V1/                      # V1 홈 표현·학습 컴포넌트·워크스페이스
├── Persistence/
│   └── V1/                     # V1 SwiftData 컨테이너·스토어·레코드·매핑
└── Resources/
    ├── Content/                 # 현재 manifest, learning, knowledge
    └── V1/                      # V1 manifest, curriculum, catalog
```

테스트는 제품 코드의 동일한 경로를 거울처럼 따른다. 예를 들어 `Features/Learning`은 `ConriculumTests/Features/Learning`, `Features/V1/Workspace`는 `ConriculumTests/Features/V1/Workspace`에서 검증한다.

## 의존 방향

```text
App ────────> 현재 기능
 └──────────> V1 호환 기능

현재 기능 ──> Shared
V1 기능 ───> Shared
Shared ──X─> V1
현재 기능 ─X─> V1
```

`App`은 버전 선택과 두 구현의 조립을 위해 양쪽을 알 수 있다. 공유 레이어는 어느 한 버전의 타입에 의존하지 않아야 한다. 현재 구현이 V1 타입을 필요로 한다면 공유 추출이 덜 되었거나 조립 책임이 `App` 밖으로 새어 나온 것으로 본다.

V1 SwiftData `@Model` 클래스의 Swift 타입 이름은 예외적으로 기존 이름을 유지한다. 클래스 이름 변경이 저장 스키마의 엔티티 정체성을 바꿔 기존 사용자 기록을 잃게 만들 수 있기 때문이다. 대신 파일명과 상위 폴더로 V1 소유권을 표시하며, 컨테이너·환경·스토어처럼 스키마 정체성이 아닌 타입에는 `V1` 접두사를 붙인다.

## V1 제거 준비 기준

V1 제거 작업은 다음 경계를 순서대로 삭제할 수 있어야 한다.

- 제품과 테스트의 모든 `V1/` 폴더
- `App`과 `Home`에 남아 있는 V1 라우트, 토글 분기, 의존성 조립
- `Resources/V1`과 `Persistence/V1`
- `ContentVersion.v1` 및 V1 설정 복원 코드

이 과정에서 접두사가 없는 현재 `Content`, `Learning`, `KnowledgeSystem` 구현과 `Shared`는 수정 없이 남는 것이 목표다. V1 삭제 전까지는 V1 저장 기록을 자동 이전하거나 삭제하지 않는다.

## 새 파일 배치 질문

새 파일을 추가할 때 아래 순서로 판단한다.

1. 현재 제품만 쓰는가? 버전 접두사 없이 해당 레이어와 기능 폴더에 둔다.
2. V1만 쓰는가? 같은 레이어의 `V1/` 아래에 두고 파일과 최상위 타입에 `V1`을 붙인다.
3. 양쪽이 실제로 쓰는가? 버전 폴더 밖의 `Shared` 또는 역할별 공용 폴더에 둔다.
4. 단지 미래에 공유할 것 같은가? 아직 공유하지 말고 현재 소유 위치에 둔다.
5. 폴더를 더 만들 만큼 응집된 파일이 세 개 이상인가? 아니라면 기존 기능 폴더에 둔다.
