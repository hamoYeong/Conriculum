#!/usr/bin/env python3
"""Convert the Obsidian Stage 1/2 curriculum into the app's independent v2 JSON."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


STAGES = (
    (1, "Stage 1 - 코드의 단어와 모양에 익숙해지기", "game"),
    (2, "Stage 2 - AI 구현을 의미 단위로 읽는 기초", "learning"),
)


def strip_frontmatter(text: str) -> str:
    lines = text.splitlines()
    if lines and (lines[0] == "---" or lines[0].startswith("tags:")):
        start = 1
        while start < len(lines) and lines[start] != "---":
            start += 1
        lines = lines[start + 1 :]
    return "\n".join(lines).strip()


def first_section(text: str, heading: str) -> str:
    match = re.search(
        rf"^## {re.escape(heading)}\s*$\n+(.*?)(?=^## |\Z)",
        text,
        flags=re.MULTILINE | re.DOTALL,
    )
    if not match:
        return ""
    body = match.group(1).strip()
    return next((p.strip() for p in re.split(r"\n\s*\n", body) if p.strip()), "")


def clean_inline(value: str) -> str:
    value = re.sub(r"\[\[([^\]|]+)\|([^\]]+)\]\]", r"\2", value)
    value = re.sub(r"\[\[([^\]]+)\]\]", r"\1", value)
    return value.replace("**", "").strip()


def parse_markdown_table(markdown: str) -> list[list[str]]:
    rows = []
    for line in markdown.splitlines():
        if not line.strip().startswith("|"):
            continue
        cells = [clean_inline(cell) for cell in line.strip().strip("|").split("|")]
        if cells and all(re.fullmatch(r"[-: ]+", cell) for cell in cells):
            continue
        rows.append(cells)
    return rows[1:] if len(rows) > 1 else []


def concept_id(title: str) -> str:
    digest = hashlib.sha1(title.encode("utf-8")).hexdigest()[:12]
    return f"v2.concept.{digest}"


def chapter_order(path: Path) -> int:
    match = re.match(r"Chapter (\d+)", path.name)
    return int(match.group(1)) if match else 99


def chapter_title(path: Path) -> str:
    return re.sub(r"^(?:Chapter \d+|Final Chapter)\s*-\s*", "", path.name)


def block_kind(stage: int, title: str) -> str:
    if stage == 1:
        if title == "클리어 목표": return "mission"
        if title == "단어 체계": return "wordSystem"
        if title == "장면 카드": return "scene"
        if title.startswith("게임"): return "game"
        if title == "보스 코드": return "boss"
        if title == "지식 카드 해금": return "unlock"
        return "support"

    mappings = (
        ("읽기 미션", "mission"),
        ("코드 무대", "codeStage"),
        ("결과 먼저", "prediction"),
        ("단서 스캔", "clueScan"),
        ("조각 묶기", "chunking"),
        ("흐름 잇기", "flow"),
        ("변경 실험", "changeExperiment"),
        ("한 문장 복원", "reconstruction"),
        ("전이", "transfer"),
    )
    if any(word in title for word in ("마무리", "확인")):
        return "closure"
    for prefix, kind in mappings:
        if title.startswith(prefix):
            return kind
    return "support"


def parse_page(source_root: Path, stage: int, chapter_id: str, page_path: Path) -> dict:
    text = strip_frontmatter(page_path.read_text(encoding="utf-8"))
    title_match = re.search(r"^# (.+)$", text, flags=re.MULTILINE)
    if not title_match:
        raise ValueError(f"Missing title: {page_path}")
    title = title_match.group(1).strip()
    matches = list(re.finditer(r"^## (.+)$", text, flags=re.MULTILINE))
    blocks = []
    for index, match in enumerate(matches, start=1):
        end = matches[index].start() if index < len(matches) else len(text)
        body = text[match.end() : end].strip()
        body = re.sub(r"\n*\[\[학습 체계 ver\.2/.+?\]\].*$", "", body, flags=re.DOTALL).strip()
        blocks.append(
            {
                "id": f"{page_path.stem.lower().replace(' ', '-')}.block-{index}",
                "order": index,
                "kind": block_kind(stage, match.group(1).strip()),
                "title": match.group(1).strip(),
                "markdown": body,
            }
        )
    page_number = int(page_path.stem.split()[0])
    page_id = f"v2.s{stage}.{chapter_id}.p{page_number}"
    goal_heading = "클리어 목표" if stage == 1 else "읽기 미션"
    goal = clean_inline(first_section(text, goal_heading))
    if len(goal) > 180:
        goal = goal.split(".")[0].strip() + "."
    if stage == 1:
        word_block = next((block for block in blocks if block["kind"] == "wordSystem"), None)
        knowledge_rows = parse_markdown_table(word_block["markdown"]) if word_block else []
        knowledge_seeds = [
            {
                "id": concept_id(row[0]),
                "title": row[0],
                "definition": f"{row[1]} 체계에서 {row[2]}",
                "essentialQuestion": row[3],
            }
            for row in knowledge_rows
            if len(row) >= 4 and row[0]
        ]
    else:
        knowledge_seeds = [{
            "id": concept_id(f"Stage 2 · {title}"),
            "title": title,
            "definition": goal,
            "essentialQuestion": "이 코드를 의미 단위로 읽을 때 무엇을 먼저 확인해야 할까?",
        }]
    return {
        "schemaVersion": 1,
        "contentVersion": "v2",
        "id": page_id,
        "stageID": f"v2.s{stage}",
        "chapterID": f"v2.s{stage}.{chapter_id}",
        "order": page_number,
        "title": title,
        "goal": goal,
        "sourcePath": str(page_path.relative_to(source_root)),
        "blocks": blocks,
        "termRefs": [],
        "knowledgeConceptIDs": [seed["id"] for seed in knowledge_seeds],
        "_knowledgeSeeds": knowledge_seeds,
    }


def build_knowledge_catalog(stages: list[dict], pages: list[dict]) -> dict:
    page_by_id = {page["id"]: page for page in pages}
    concepts = {}
    collection_owner = {}
    collections = []
    relations = []

    for stage in stages:
        for chapter in stage["chapters"]:
            collection_id = chapter["id"].replace(".c", ".knowledge.c")
            concept_ids = []
            for reference in chapter["pages"]:
                page = page_by_id[reference["id"]]
                revisit = {
                    "chapterID": chapter["id"],
                    "chapterOrder": chapter["order"],
                    "chapterTitle": chapter["title"],
                    "pageID": page["id"],
                    "pageOrder": page["order"],
                    "pageTitle": page["title"],
                    "kind": "direct",
                    "connection": page["goal"],
                }
                for seed in page["_knowledgeSeeds"]:
                    if seed["id"] not in concepts:
                        concepts[seed["id"]] = {
                            **seed,
                            "judgmentQuestions": [
                                seed["essentialQuestion"],
                                "코드의 모양·자리·주변 단어 중 어떤 단서가 판단 근거인가?",
                            ],
                            "examples": [page["title"]],
                            "misconceptions": [
                                "코드를 처음부터 모두 번역해야만 이 개념을 찾을 수 있다고 생각한다."
                            ],
                            "revisitPages": [revisit],
                        }
                        collection_owner[seed["id"]] = collection_id
                    else:
                        concept = concepts[seed["id"]]
                        if all(item["pageID"] != page["id"] for item in concept["revisitPages"]):
                            concept["revisitPages"].append(revisit)
                        if page["title"] not in concept["examples"]:
                            concept["examples"].append(page["title"])
                    if collection_owner[seed["id"]] == collection_id:
                        concept_ids.append(seed["id"])

            concept_ids = list(dict.fromkeys(concept_ids))
            collections.append({
                "id": collection_id,
                "order": len(collections) + 1,
                "title": f"Stage {stage['order']} · {chapter['title']}",
                "summary": chapter["summary"],
                "systemImage": "rectangle.3.group" if stage["kind"] == "game" else "point.3.connected.trianglepath.dotted",
                "conceptIDs": concept_ids,
            })
            for left, right in zip(concept_ids, concept_ids[1:]):
                relations.append({
                    "id": f"v2.relation.{left.rsplit('.', 1)[-1]}.{right.rsplit('.', 1)[-1]}",
                    "sourceConceptID": left,
                    "targetConceptID": right,
                    "kind": "leadsTo",
                    "summary": "같은 학습 흐름에서 다음 판단 단서로 이어진다.",
                })

    return {
        "schemaVersion": 1,
        "id": "learning-system-v2-knowledge.ko-KR",
        "title": "ver.2 코드 읽기 지식",
        "collections": collections,
        "concepts": list(concepts.values()),
        "relations": relations,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()

    stages = []
    parsed_pages = []
    for stage_number, directory_name, kind in STAGES:
        stage_dir = args.source_root / directory_name
        stage_map = strip_frontmatter((stage_dir / f"00 Stage {stage_number} 지도.md").read_text(encoding="utf-8"))
        stage_title = re.search(r"^# Stage \d+ 지도 — (.+)$", stage_map, flags=re.MULTILINE).group(1)
        stage_summary_heading = "이 Stage가 필요한 이유" if stage_number == 1 else "목적"
        stage_summary = clean_inline(first_section(stage_map, stage_summary_heading))
        chapter_dirs = sorted(
            (item for item in stage_dir.iterdir() if item.is_dir()),
            key=chapter_order,
        )
        chapters = []
        for chapter_index, chapter_dir in enumerate(chapter_dirs, start=1):
            chapter_key = f"c{chapter_index}"
            chapter_id = f"v2.s{stage_number}.{chapter_key}"
            map_path = next(chapter_dir.glob("00*.md"))
            map_text = strip_frontmatter(map_path.read_text(encoding="utf-8"))
            summary = clean_inline(first_section(map_text, "목표"))
            page_paths = sorted(
                (item for item in chapter_dir.glob("[0-9][0-9] *.md") if not item.name.startswith("00")),
                key=lambda item: int(item.stem.split()[0]),
            )
            references = []
            for page_path in page_paths:
                page = parse_page(args.source_root, stage_number, chapter_key, page_path)
                parsed_pages.append(page)
                resource_dir = args.output_root / "learning" / f"Stage{stage_number:02d}" / f"Chapter{chapter_index:02d}"
                resource_dir.mkdir(parents=True, exist_ok=True)
                resource_file = resource_dir / f"{page['id'].replace('.', '-')}.json"
                serializable_page = {key: value for key, value in page.items() if not key.startswith("_")}
                resource_file.write_text(json.dumps(serializable_page, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
                references.append(
                    {
                        "id": page["id"],
                        "order": page["order"],
                        "title": page["title"],
                        "goal": page["goal"],
                        "resource": str(resource_file.relative_to(args.output_root.parent.parent)),
                    }
                )
            chapters.append(
                {
                    "id": chapter_id,
                    "stageID": f"v2.s{stage_number}",
                    "order": chapter_index,
                    "title": chapter_title(chapter_dir),
                    "summary": summary,
                    "pages": references,
                }
            )
        stages.append(
            {
                "id": f"v2.s{stage_number}",
                "order": stage_number,
                "title": stage_title,
                "summary": stage_summary,
                "kind": kind,
                "chapters": chapters,
            }
        )

    manifest = {
        "schemaVersion": 1,
        "contentVersion": "v2",
        "id": "learning-system-v2.ko-KR",
        "locale": "ko-KR",
        "title": "AI 코드 읽기",
        "stages": stages,
    }
    args.output_root.mkdir(parents=True, exist_ok=True)
    (args.output_root / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    knowledge_dir = args.output_root / "knowledge"
    knowledge_dir.mkdir(parents=True, exist_ok=True)
    (knowledge_dir / "catalog.json").write_text(
        json.dumps(
            build_knowledge_catalog(stages, parsed_pages),
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
