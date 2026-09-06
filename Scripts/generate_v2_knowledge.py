#!/usr/bin/env python3
"""Generate the v2 bookshelf solely from the Obsidian knowledge-system-v2 folder."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


def strip_frontmatter(text: str) -> str:
    return re.sub(r"(?s)^---\n.*?\n---\n+", "", text).strip()


def section(text: str, heading: str) -> str:
    match = re.search(rf"(?ms)^## {re.escape(heading)}\s*$\n+(.*?)(?=^## |\Z)", text)
    return match.group(1).strip() if match else ""


def inline_field(text: str, label: str) -> str:
    match = re.search(rf"(?m)^\*\*{re.escape(label)}:\*\*\s*(.+)$", text)
    return match.group(1).strip() if match else ""


def clean(value: str) -> str:
    value = re.sub(r"\[\[([^\]|]+)\|([^\]]+)\]\]", r"\2", value)
    value = re.sub(r"\[\[([^\]]+)\]\]", r"\1", value)
    return value.replace("**", "").strip()


def concept_id(title: str) -> str:
    return "v2.concept." + hashlib.sha1(title.encode("utf-8")).hexdigest()[:12]


def first_sentence(value: str) -> str:
    value = clean(re.sub(r"(?m)^[-0-9]+[.)]?\s*", "", value)).replace("\n", " ")
    return value.split(". ", 1)[0].strip()


def bullets(value: str) -> list[str]:
    rows = []
    for line in value.splitlines():
        match = re.match(r"^[-0-9]+[.)]?\s+(.+)$", line.strip())
        if match:
            rows.append(clean(match.group(1)))
    return rows


def parse_concept(path: Path) -> dict:
    text = strip_frontmatter(path.read_text(encoding="utf-8"))
    title = re.search(r"(?m)^# (.+)$", text).group(1).strip()
    definition = inline_field(text, "한 줄 역할") or first_sentence(section(text, "한 문장 정의"))
    question = inline_field(text, "읽기 질문") or first_sentence(section(text, "구분 질문"))
    misconception = inline_field(text, "자주 하는 오독")
    misconceptions = [misconception] if misconception else bullets(section(text, "오해와 교정"))
    signals = inline_field(text, "코드 신호")
    example = first_sentence(section(text, "대표 예시와 경계"))
    examples = [value for value in (signals, example) if value]
    judgment = bullets(section(text, "판단 순서와 기준"))
    return {
        "id": concept_id(title),
        "title": title,
        "definition": definition or f"{title}을 코드 읽기의 판단 단서로 사용한다.",
        "essentialQuestion": question or f"{title}은 현재 코드에서 어떤 역할을 하는가?",
        "judgmentQuestions": judgment[:5] or [f"{title}을 확인할 수 있는 코드 신호는 무엇인가?"],
        "examples": examples[:3],
        "misconceptions": misconceptions[:4],
        "revisitPages": [],
        "_stem": path.stem,
        "_path": str(path),
        "_text": text,
    }


def relation_targets(text: str) -> list[tuple[str, str]]:
    body = section(text, "다음 연결")
    results = []
    for match in re.finditer(r"\[\[지식 체계 ver\.2/([^\]|]+)(?:\|([^\]]+))?\]\](?:\s*—\s*(.+))?", body):
        results.append((Path(match.group(1)).stem, clean(match.group(3) or "다음 판단 기준으로 이어진다.")))
    return results


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    collections = []
    concepts = []
    for order, directory in enumerate(sorted(path for path in args.source_root.iterdir() if path.is_dir()), start=1):
        pages = sorted(
            path for path in directory.glob("*.md")
            if not path.name.startswith("00")
            and "## 다음 연결" in path.read_text(encoding="utf-8")
        )
        category_concepts = [parse_concept(path) for path in pages]
        guide = next(iter(sorted(directory.glob("00*.md"))), None)
        guide_text = strip_frontmatter(guide.read_text(encoding="utf-8")) if guide else ""
        title_match = re.search(r"(?m)^# (.+)$", guide_text)
        collection_title = title_match.group(1).strip() if title_match else directory.name
        summary = first_sentence(section(guide_text, "이 분류의 역할") or section(guide_text, "목적"))
        collections.append({
            "id": f"v2.knowledge.collection.{order}",
            "order": order,
            "title": collection_title,
            "summary": summary or f"{collection_title}에 필요한 코드 읽기 기준",
            "systemImage": "books.vertical",
            "conceptIDs": [item["id"] for item in category_concepts],
        })
        concepts.extend(category_concepts)

    by_title = {
        key: item
        for item in concepts
        for key in (item["title"], item["_stem"])
    }
    relations = []
    for source in concepts:
        for target_title, summary in relation_targets(source["_text"]):
            target = by_title.get(target_title)
            if not target:
                raise ValueError(f"Unknown next knowledge link: {source['title']} -> {target_title}")
            relations.append({
                "id": f"v2.relation.{source['id'].split('.')[-1]}.{target['id'].split('.')[-1]}",
                "sourceConceptID": source["id"],
                "targetConceptID": target["id"],
                "kind": "leadsTo",
                "summary": summary,
            })

    for item in concepts:
        item.pop("_path")
        item.pop("_text")
        item.pop("_stem")
    catalog = {
        "schemaVersion": 1,
        "id": "learning-system-v2-knowledge.ko-KR",
        "title": "ver.2 코드 읽기 지식",
        "collections": collections,
        "concepts": concepts,
        "relations": relations,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"generated {len(collections)} collections, {len(concepts)} concepts, {len(relations)} directed relations")


if __name__ == "__main__":
    main()
