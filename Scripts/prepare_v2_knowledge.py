#!/usr/bin/env python3
"""Bring the Stage 1 foundations into the v2 vault and author a directed path."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


STAGE_ONE_FOUNDATIONS = (
    "02 값과 타입/값.md",
    "02 값과 타입/리터럴.md",
    "02 값과 타입/String.md",
    "02 값과 타입/Int.md",
    "02 값과 타입/Double.md",
    "02 값과 타입/Bool.md",
    "02 값과 타입/타입.md",
    "02 값과 타입/상수와 변수.md",
    "02 값과 타입/식별자와 이름 짓기.md",
    "03 표현식과 연산/표현식.md",
    "03 표현식과 연산/산술 연산.md",
    "03 표현식과 연산/비교 연산.md",
    "03 표현식과 연산/논리 연산과 조건 조합.md",
    "03 표현식과 연산/계산 순서.md",
)


ORDER = {
    "00 코드 첫 단어": [
        "값", "리터럴", "String", "Int", "Double", "Bool", "타입",
        "상수와 변수", "식별자와 이름 짓기", "표현식", "산술 연산",
        "계산 순서", "비교 연산", "논리 연산과 조건 조합",
    ],
    "01 방향과 단서": [
        "실행 결과에서 시작하기", "진입점 찾기", "이름과 프레임워크 단서",
        "의미 단위 조각", "사실 추정 질문 구분하기",
    ],
    "02 값과 상태": [
        "선언 읽기", "Optional과 값 없음", "enum과 가능한 상태",
        "컬렉션과 원소 흐름", "상태 소유권",
    ],
    "03 실행과 변환": [
        "함수 호출과 반환", "if와 guard", "switch와 빠짐없는 분기",
        "반복과 컬렉션 변환",
    ],
    "04 책임과 경계": [
        "클로저와 실행 시점", "struct class enum의 책임", "초기화와 멤버 연결",
        "protocol과 교체 가능한 약속", "generic과 extension", "의존성과 주입",
    ],
    "05 화면과 생명주기": [
        "View 트리", "modifier 사슬", "State와 Binding",
        "사용자 행동과 다시 그리기", "Environment와 navigation",
    ],
    "06 외부 세계와 부작용": [
        "Codable과 요청 응답", "async await Task", "로딩 오류 빈 성공 상태",
        "SwiftData 모델과 문맥", "부작용 경계",
    ],
    "07 구조와 변경": [
        "기능 흐름", "MVVM 읽기", "단방향 상태 흐름", "변경 영향", "테스트 증거",
    ],
    "08 읽기 패턴": [
        "불러오기 패턴", "변환하기 패턴", "저장하기 패턴", "실패 복구 패턴",
    ],
}


def without_section(text: str, heading: str) -> str:
    return re.sub(
        rf"(?ms)^## {re.escape(heading)}\s*$.*?(?=^## |\Z)",
        "",
        text,
    ).rstrip()


def import_foundations(v1_root: Path, v2_root: Path) -> None:
    destination = v2_root / "00 코드 첫 단어"
    destination.mkdir(parents=True, exist_ok=True)
    selected_titles = {Path(item).stem for item in STAGE_ONE_FOUNDATIONS}
    for relative in STAGE_ONE_FOUNDATIONS:
        source = v1_root / relative
        text = source.read_text(encoding="utf-8")
        text = without_section(text, "유형이 있는 지식 관계")
        text = without_section(text, "다시 보기")
        text = re.sub(
            r"\[\[지식 체계/[^\]|]+/([^\]|]+)(?:\|([^\]]+))?\]\]",
            lambda match: (
                f"[[지식 체계 ver.2/00 코드 첫 단어/{match.group(1)}|{match.group(2) or match.group(1)}]]"
                if match.group(1) in selected_titles else (match.group(2) or match.group(1))
            ),
            text,
        )
        frontmatter = "---\ntags: [knowledge-system-v2, stage-1-foundation]\n---\n\n"
        (destination / source.name).write_text(frontmatter + text.strip() + "\n", encoding="utf-8")


def concept_paths(v2_root: Path) -> dict[str, Path]:
    result = {}
    for category, titles in ORDER.items():
        directory = v2_root / category
        candidates = {path.stem: path for path in directory.glob("*.md") if not path.name.startswith("00")}
        for title in titles:
            if title not in candidates:
                raise ValueError(f"Missing v2 knowledge page: {category}/{title}.md")
            result[title] = candidates[title]
    return result


def wiki_link(path: Path, root: Path) -> str:
    return f"[[지식 체계 ver.2/{path.relative_to(root).with_suffix('')}|{path.stem}]]"


def author_relations(v2_root: Path) -> None:
    paths = concept_paths(v2_root)
    ordered_titles = [title for titles in ORDER.values() for title in titles]
    for index, title in enumerate(ordered_titles):
        path = paths[title]
        text = without_section(path.read_text(encoding="utf-8"), "선행 지식")
        text = without_section(text, "다음 연결")
        previous = paths[ordered_titles[index - 1]] if index > 0 else None
        following = paths[ordered_titles[index + 1]] if index + 1 < len(ordered_titles) else None
        prerequisite = (
            f"- {wiki_link(previous, v2_root)} — 이 기준을 먼저 구분하면 현재 개념의 역할을 더 정확히 판단할 수 있다."
            if previous else "- 없음 — 이 지식 경로의 출발점이다."
        )
        next_link = (
            f"- {wiki_link(following, v2_root)} — 현재 기준을 바탕으로 다음 코드 단서와 책임을 읽는다."
            if following else "- 없음 — 이 지식 경로의 마지막 확인 지점이다."
        )
        text += f"\n\n## 선행 지식\n\n{prerequisite}\n\n## 다음 연결\n\n{next_link}\n"
        path.write_text(text, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("v1_root", type=Path)
    parser.add_argument("v2_root", type=Path)
    args = parser.parse_args()
    import_foundations(args.v1_root, args.v2_root)
    author_relations(args.v2_root)
    print(f"prepared {sum(map(len, ORDER.values()))} directed v2 knowledge pages")


if __name__ == "__main__":
    main()
