# 프로젝트 폴더 구조 원칙

## 기준 버전

ver.2가 현재 제품 기준이다. 소스 코드의 폴더, 파일, Swift 타입에는 버전 접두사를 붙이지 않는다. 콘텐츠 ID와 저장 키의 `v2` 표기는 소스 구조 접두사가 아니라 이미 저장된 데이터의 정체성이므로 `v2.s1.c1`, `learning.progress.v2` 같은 값은 바꾸지 않는다.

## 폴더가 깊어지는 순서

폴더는 아래 기준을 순서대로 적용해 깊어진다.

1. 레이어: `App`, `Content`, `Dependencies`, `Domain`, `Features`, `Persistence`, `Resources`
2. 기능 또는 역할: 예를 들어 `Content/Decoding`, `Content/Loading`, `Features/Home`, `Features/Learning`으로 나눈다.
3. 세부 구현: 서로 함께 바뀌는 파일이 세 개 이상이거나 별도 테스트 경계가 필요할 때만 한 단계 더 나눈다.

파일 종류만 같다는 이유로 먼저 묶지 않는다. 어느 레이어가 어떤 기능을 담당하는지 바깥 폴더부터 읽히게 한다.

## 현재 구조

```text
Conriculum/
├── App/                         # 의존성 조립과 화면 전환
├── Content/
│   ├── Models.swift             # 학습 JSON 모델
│   ├── Decoding/                # JSON 디코딩과 오류 문맥
│   ├── Loading/                 # 번들 콘텐츠 로딩
│   └── Validation/              # 콘텐츠 무결성 검증
├── Dependencies/                # 콘텐츠와 진행 기록 의존성
├── Domain/
│   ├── Identifiers/             # 안정적인 타입 ID
│   ├── Knowledge/               # 기본·개인 지식 모델
│   ├── LearningRecords/         # 진행·응답·도움 수준
│   └── Workspace/               # 학습 화면 상태 값
├── Features/
│   ├── Home/                    # 학습 지도와 진입점
│   ├── Learning/                # 학습 화면과 Stage 컴포넌트
│   ├── Knowledge/               # 개념 상세 공용 표현
│   ├── KnowledgeSystem/         # 지식 책장
│   └── Shared/                  # 공용 학습 UI
├── Persistence/
│   ├── Models/                  # SwiftData 레코드
│   ├── Mapping/                 # 도메인 ↔ 레코드 변환
│   ├── Stores/                  # 진행 단위 원자적 저장
│   ├── PersistenceContainerFactory.swift
│   └── PersistenceEnvironmentRegistry.swift
└── Resources/
    └── Content/                 # manifest, learning, knowledge
```

테스트는 제품 코드의 경로를 거울처럼 따른다. 예를 들어 `Features/Learning`은 `ConriculumTests/Features/Learning`에서 검증한다.

## 의존 방향

```text
App ────────> Features
Features ───> Dependencies, Domain, Shared
Dependencies ──> Content, Persistence
Content, Persistence ──> Domain
Shared ──X─> 개별 Feature
```

상위 조립 계층은 하위 기능을 알 수 있지만, 공용 UI와 도메인 모델은 특정 화면에 의존하지 않는다.

## 새 파일 배치 질문

1. 앱 전환과 의존성 조립인가? `App`에 둔다.
2. JSON 모델·로딩·검증인가? `Content`에 둔다.
3. 외부 효과를 기능에 제공하는가? `Dependencies`에 둔다.
4. UI와 무관한 제품 값인가? `Domain`에 둔다.
5. 사용자가 보는 하나의 기능인가? `Features/<기능>`에 둔다.
6. 여러 기능이 실제로 쓰는 UI인가? `Features/Shared`에 둔다.
7. 저장 모델·매핑·트랜잭션인가? `Persistence`에 둔다.
8. 폴더를 더 만들 만큼 응집된 파일이 세 개 이상인가? 아니라면 기존 기능 폴더에 둔다.
