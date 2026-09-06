#!/usr/bin/env python3
"""Give Stage 1 reference sections an explicit, parseable component contract."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


def callout_body(markdown: str, kind: str) -> str:
    match = re.search(
        rf"(?m)^> \[!{kind}\]-?[^\n]*\n((?:>.*(?:\n|$))*)",
        markdown,
    )
    if not match:
        return ""
    return "\n".join(
        line.removeprefix(">").strip()
        for line in match.group(1).splitlines()
    ).strip()


def transform_word_system(body: str) -> str:
    if "conriculum-component: word-system" in body:
        return body
    table = re.search(
        r"(?m)(^\|[^\n]+\|\n^\|[-: |]+\|\n(?:^\|[^\n]+\|\n?)+)",
        body,
    )
    if not table:
        raise ValueError("단어 체계 절에 표가 없습니다")
    return (
        "\n\n<!-- conriculum-component: word-system -->\n\n"
        "### 역할 카드\n\n"
        f"{table.group(1).strip()}\n\n"
    )


def transform_unlock(body: str) -> str:
    if "conriculum-component: knowledge-unlock" in body:
        return body
    table = re.search(
        r"(?m)(^\|[^\n]+\|\n^\|[-: |]+\|\n(?:^\|[^\n]+\|\n?)+)",
        body,
    )
    if not table:
        raise ValueError("지식 카드 해금 절에 표가 없습니다")

    remainder = body[table.end():]
    first_callout = re.search(r"(?m)^> \[!", remainder)
    criteria = remainder[: first_callout.start() if first_callout else len(remainder)].strip()
    beginner = callout_body(remainder, "question")
    advanced = callout_body(remainder, "tip")
    navigation = "\n".join(re.findall(r"(?m)^\[\[.+\]\]\s*$", remainder))

    sections = [
        "\n\n<!-- conriculum-component: knowledge-unlock -->",
        "### 해금 카드\n\n" + table.group(1).strip(),
        "### 해금 기준\n\n" + criteria,
        "### 막히면\n\n" + beginner,
        "### 이미 안다면\n\n" + advanced,
        navigation,
    ]
    return "\n\n".join(section for section in sections if section.strip()) + "\n\n"


def transform(text: str) -> str:
    headings = list(re.finditer(r"(?m)^## (.+)$", text))
    replacements: list[tuple[int, int, str]] = []
    for index, match in enumerate(headings):
        title = match.group(1).strip()
        if title not in {"단어 체계", "지식 카드 해금"}:
            continue
        start = match.end()
        end = headings[index + 1].start() if index + 1 < len(headings) else len(text)
        body = text[start:end]
        updated = transform_word_system(body) if title == "단어 체계" else transform_unlock(body)
        replacements.append((start, end, updated))
    for start, end, updated in reversed(replacements):
        text = text[:start] + updated + text[end:]
    return text


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    args = parser.parse_args()
    paths = [
        path for path in args.source_root.rglob("[0-9][0-9] *.md")
        if not path.name.startswith("00")
    ]
    changed = 0
    for path in paths:
        before = path.read_text(encoding="utf-8")
        after = transform(before)
        if after != before:
            path.write_text(after, encoding="utf-8")
            changed += 1
    print(f"structured {changed} of {len(paths)} Stage 1 pages")


if __name__ == "__main__":
    main()
