#!/usr/bin/env python3
"""Convert the Obsidian Stage 1/2 curriculum into the app's independent v2 JSON."""

from __future__ import annotations

import argparse
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
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()

    stages = []
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
                resource_dir = args.output_root / "learning" / f"Stage{stage_number:02d}" / f"Chapter{chapter_index:02d}"
                resource_dir.mkdir(parents=True, exist_ok=True)
                resource_file = resource_dir / f"{page['id'].replace('.', '-')}.json"
                resource_file.write_text(json.dumps(page, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
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


if __name__ == "__main__":
    main()
