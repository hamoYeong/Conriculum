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


def subsection(markdown: str, heading: str) -> str:
    match = re.search(
        rf"(?ms)^### {re.escape(heading)}\s*$\n(.*?)(?=^### |\Z)",
        markdown,
    )
    return match.group(1).strip() if match else ""


def build_word_system(block_id: str, markdown: str) -> dict:
    if "conriculum-component: word-system" not in markdown:
        raise ValueError(f"Word system is missing its component contract: {block_id}")
    rows = parse_markdown_table(subsection(markdown, "역할 카드"))
    entries = [
        {
            "id": f"{block_id}.word-{index}",
            "term": row[0],
            "parentSystem": row[1],
            "role": row[2],
            "firstThought": row[3],
        }
        for index, row in enumerate(rows, start=1)
        if len(row) >= 4 and all(row[:4])
    ]
    if not entries:
        raise ValueError(f"Word system has no complete entries: {block_id}")
    return {"entries": entries}


def build_knowledge_unlock(block_id: str, markdown: str) -> dict:
    if "conriculum-component: knowledge-unlock" not in markdown:
        raise ValueError(f"Knowledge unlock is missing its component contract: {block_id}")
    rows = parse_markdown_table(subsection(markdown, "해금 카드"))
    cards = [
        {
            "id": f"{block_id}.card-{index}",
            "title": row[0],
            "summary": row[1],
        }
        for index, row in enumerate(rows, start=1)
        if len(row) >= 2 and all(row[:2])
    ]
    result = {
        "cards": cards,
        "completionCriteria": subsection(markdown, "해금 기준"),
        "beginnerHint": subsection(markdown, "막히면"),
        "advancedTip": subsection(markdown, "이미 안다면"),
    }
    if not cards or any(not result[key] for key in ("completionCriteria", "beginnerHint", "advancedTip")):
        raise ValueError(f"Knowledge unlock is incomplete: {block_id}")
    return result


def concept_id(title: str) -> str:
    digest = hashlib.sha1(title.encode("utf-8")).hexdigest()[:12]
    return f"v2.concept.{digest}"


def load_knowledge_titles(root: Path | None) -> list[str]:
    if root is None:
        return []
    titles = []
    for path in root.rglob("*.md"):
        text = strip_frontmatter(path.read_text(encoding="utf-8"))
        if "## 다음 연결" not in text:
            continue
        match = re.search(r"(?m)^# (.+)$", text)
        if match:
            titles.append(match.group(1).strip())
    return titles


def linked_knowledge_ids(markdown: str, titles: list[str]) -> list[str]:
    common = {"읽기", "코드", "하기", "흐름", "패턴", "값", "상태"}
    scored = []
    for title in titles:
        score = markdown.count(title) * 20
        tokens = [
            token for token in re.findall(r"[A-Za-z@]+|[가-힣]+", title)
            if len(token) > 1 and token not in common
        ]
        score += sum(markdown.lower().count(token.lower()) for token in tokens)
        if score:
            scored.append((score, title))
    scored.sort(key=lambda item: (-item[0], item[1]))
    return [concept_id(title) for _, title in scored[:4]]


def extract_feedback(markdown: str) -> str:
    matches = list(re.finditer(
        r"(?m)^> \[!(?!game)[^\]]+\]-?[^\n]*\n((?:>.*(?:\n|$))*)",
        markdown,
    ))
    if not matches:
        return ""
    return clean_inline("\n".join(
        line.removeprefix(">").strip()
        for line in matches[-1].group(1).splitlines()
    ).strip())


def remove_activity_annotations(markdown: str) -> str:
    markdown = re.sub(
        r"(?m)^> \[!game\]-?[^\n]*\n(?:>.*(?:\n|$))*",
        "",
        markdown,
    )
    markdown = re.sub(
        r"(?m)^> \[!(?!game)[^\]]+\]-?[^\n]*\n(?:>.*(?:\n|$))*",
        "",
        markdown,
    )
    markdown = re.sub(r"(?m)^<!-- conriculum-activity:.*?-->\s*$", "", markdown)
    markdown = re.sub(r"(?m)^\*\*선택 카드.*?:\*\*\s*$", "", markdown)
    return re.sub(r"\n{3,}", "\n\n", markdown).strip()


def normalized_choice(value: str) -> str:
    return re.sub(r"[^0-9a-zA-Z가-힣]+", "", clean_inline(value)).lower()


def infer_correct_option(options: list[str], feedback: str) -> int:
    ordinal_markers = (
        (("첫 선택지", "첫번째", "첫째"), 0),
        (("두 번째", "두번째", "둘째"), 1),
        (("세 번째", "세번째", "셋째"), 2),
        (("네 번째", "네번째", "넷째"), 3),
    )
    for markers, index in ordinal_markers:
        if any(marker in feedback for marker in markers) and index < len(options):
            return index

    normalized_feedback = normalized_choice(feedback)
    scores = []
    for option in options:
        normalized = normalized_choice(option)
        score = len(normalized) if normalized and normalized in normalized_feedback else 0
        if score == 0:
            tokens = re.findall(r"[0-9a-zA-Z가-힣]+", clean_inline(option))
            score = sum(len(token) for token in tokens if token.lower() in feedback.lower())
        scores.append(score)
    best = max(range(len(options)), key=lambda index: scores[index])
    return best if scores[best] > 0 else 0


def activity_contract(markdown: str) -> tuple[str, dict[str, str]]:
    match = re.search(r"<!-- conriculum-activity:\s*([^;]+);\s*(.*?)\s*-->", markdown)
    if not match:
        raise ValueError("Stage 1 activity is missing a conriculum-activity contract")
    fields = {}
    for item in match.group(2).split(";"):
        if ":" in item:
            key, value = item.split(":", 1)
            fields[key.strip()] = value.strip()
    return match.group(1).strip(), fields


def build_game_activity(activity_id: str, title: str, markdown: str) -> dict:
    contract_kind, fields = activity_contract(markdown)
    feedback = extract_feedback(markdown)
    cleaned = remove_activity_annotations(markdown)
    numbered = re.findall(r"(?m)^\d+\.\s+(.+?)\s*$", cleaned)
    options = []
    pairs = []
    correct_ids = []

    if contract_kind == "matching":
        table_match = re.search(
            r"(?m)(^\|[^\n]+\|\n^\|[-: |]+\|\n(?:^\|[^\n]+\|\n?)+)",
            cleaned,
        )
        if not table_match:
            raise ValueError(f"Matching activity has no table: {activity_id}")
        table_lines = table_match.group(1).splitlines()
        headers = [clean_inline(cell) for cell in table_lines[0].strip().strip("|").split("|")]
        rows = parse_markdown_table(table_match.group(1))
        source_index = headers.index(fields["source"])
        target_index = headers.index(fields["target"])
        pairs = [
            {
                "id": f"{activity_id}.pair-{index}",
                "left": row[source_index],
                "right": row[target_index],
            }
            for index, row in enumerate(rows, start=1)
        ]
        prompt = (cleaned[: table_match.start()] + cleaned[table_match.end() :]).strip() or title
        kind = "matching"
    else:
        if len(numbered) < 2:
            raise ValueError(f"Choice activity needs at least two cards: {activity_id}")
        first_option = re.search(r"(?m)^1\.\s+", cleaned)
        prompt = cleaned[: first_option.start()].strip() or title
        options = [
            {"id": f"{activity_id}.option-{index}", "title": clean_inline(option)}
            for index, option in enumerate(numbered, start=1)
        ]
        correct_indexes = [int(value) for value in fields["correct"].split(",")]
        correct_ids = [options[index - 1]["id"] for index in correct_indexes]
        kind = "singleChoice" if contract_kind == "choice" and len(correct_ids) == 1 else "multipleChoice"

    return {
        "id": activity_id,
        "kind": kind,
        "promptMarkdown": prompt,
        "options": options,
        "pairs": pairs,
        "correctOptionIDs": correct_ids,
        "correctFeedback": feedback or "모든 카드가 원문의 역할 관계와 일치한다.",
        "incorrectFeedback": (
            "아직 맞지 않는 연결이나 빠진 단서가 있습니다. 코드의 모양·자리·주변 단어를 다시 비교해 보세요."
        ),
    }


def build_game_activities(block_id: str, title: str, markdown: str) -> list[dict]:
    if title.startswith("게임 3"):
        sources = [
            source.strip()
            for source in re.split(r"(?m)(?=^### 수상한 카드\s*$)", markdown)
            if MARKER_TEXT in source
        ]
    elif title.startswith("게임 4"):
        sources = [
            source.strip()
            for source in re.split(r"(?m)(?=^### \d+\s*$)", markdown)
            if MARKER_TEXT in source
        ]
    else:
        sources = [markdown]
    return [
        build_game_activity(
            f"{block_id}.activity-{index}",
            title,
            source,
        )
        for index, source in enumerate(sources, start=1)
    ]


MARKER_TEXT = "conriculum-activity:"


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


def parse_page(
    source_root: Path,
    stage: int,
    chapter_id: str,
    page_path: Path,
    knowledge_titles: list[str],
) -> dict:
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
        block_id = f"{page_path.stem.lower().replace(' ', '-')}.block-{index}"
        kind = block_kind(stage, match.group(1).strip())
        word_system = build_word_system(block_id, body) if kind == "wordSystem" else None
        knowledge_unlock = build_knowledge_unlock(block_id, body) if kind == "unlock" else None
        block = {
            "id": block_id,
            "order": index,
            "kind": kind,
            "title": match.group(1).strip(),
            "markdown": "" if word_system or knowledge_unlock else body,
            "activities": build_game_activities(
                block_id,
                match.group(1).strip(),
                body,
            ) if stage == 1 and kind in ("game", "boss") else [],
        }
        if word_system:
            block["wordSystem"] = word_system
        if knowledge_unlock:
            block["knowledgeUnlock"] = knowledge_unlock
        blocks.append(block)
    page_number = int(page_path.stem.split()[0])
    page_id = f"v2.s{stage}.{chapter_id}.p{page_number}"
    goal_heading = "클리어 목표" if stage == 1 else "읽기 미션"
    goal = clean_inline(first_section(text, goal_heading))
    if len(goal) > 180:
        goal = goal.split(".")[0].strip() + "."
    if stage == 1:
        word_block = next((block for block in blocks if block["kind"] == "wordSystem"), None)
        knowledge_entries = (word_block.get("wordSystem") or {}).get("entries", []) if word_block else []
        knowledge_seeds = [
            {
                "id": concept_id(entry["term"]),
                "title": entry["term"],
                "definition": f"{entry['parentSystem']} 체계에서 {entry['role']}",
                "essentialQuestion": entry["firstThought"],
            }
            for entry in knowledge_entries
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
        "knowledgeConceptIDs": linked_knowledge_ids(text, knowledge_titles)
            or [concept_id("값")],
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
    parser.add_argument("--knowledge-root", type=Path)
    args = parser.parse_args()
    knowledge_titles = load_knowledge_titles(args.knowledge_root)

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
                page = parse_page(
                    args.source_root,
                    stage_number,
                    chapter_key,
                    page_path,
                    knowledge_titles,
                )
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
                        "resource": str(resource_file.relative_to(args.output_root.parent)),
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
