#!/usr/bin/env python3
"""Author the directed path between current knowledge pages."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


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


def concept_paths(knowledge_root: Path) -> dict[str, Path]:
    result = {}
    for category, titles in ORDER.items():
        directory = knowledge_root / category
        candidates = {path.stem: path for path in directory.glob("*.md") if not path.name.startswith("00")}
        for title in titles:
            if title not in candidates:
                raise ValueError(f"Missing knowledge page: {category}/{title}.md")
            result[title] = candidates[title]
    return result


def wiki_link(path: Path, root: Path) -> str:
    return f"[[{root.name}/{path.relative_to(root).with_suffix('')}|{path.stem}]]"


def author_relations(knowledge_root: Path) -> None:
    paths = concept_paths(knowledge_root)
    ordered_titles = [title for titles in ORDER.values() for title in titles]
    for index, title in enumerate(ordered_titles):
        path = paths[title]
        text = without_section(path.read_text(encoding="utf-8"), "선행 지식")
        text = without_section(text, "다음 연결")
        previous = paths[ordered_titles[index - 1]] if index > 0 else None
        following = paths[ordered_titles[index + 1]] if index + 1 < len(ordered_titles) else None
        prerequisite = (
            f"- {wiki_link(previous, knowledge_root)} — 이 기준을 먼저 구분하면 현재 개념의 역할을 더 정확히 판단할 수 있다."
            if previous else "- 없음 — 이 지식 경로의 출발점이다."
        )
        next_link = (
            f"- {wiki_link(following, knowledge_root)} — 현재 기준을 바탕으로 다음 코드 단서와 책임을 읽는다."
            if following else "- 없음 — 이 지식 경로의 마지막 확인 지점이다."
        )
        text += f"\n\n## 선행 지식\n\n{prerequisite}\n\n## 다음 연결\n\n{next_link}\n"
        path.write_text(text, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("knowledge_root", type=Path)
    args = parser.parse_args()
    author_relations(args.knowledge_root)
    print(f"prepared {sum(map(len, ORDER.values()))} directed knowledge pages")


if __name__ == "__main__":
    main()
