#!/usr/bin/env python3
"""Add explicit, human-readable interaction contracts to Stage 1 Obsidian pages.

The source remains useful in Obsidian while the HTML comments give the JSON
generator an unambiguous activity kind and answer contract.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path


MARKER = "conriculum-activity:"


def clean(value: str) -> str:
    return re.sub(r"[`*\"'\s.,(){}\[\]:;]+", "", value).lower()


def callout_feedback(markdown: str) -> str:
    match = re.search(r"(?m)^> \[![^\]]+\]-?[^\n]*\n((?:>.*(?:\n|$))*)", markdown)
    if not match:
        return ""
    return " ".join(line.removeprefix(">").strip() for line in match.group(1).splitlines())


def infer_choice_answers(options: list[str], feedback: str) -> list[int]:
    if "앞의 두 가지" in feedback and len(options) >= 2:
        return [1, 2]
    normalized_feedback = clean(feedback)
    scores = []
    for option in options:
        normalized = clean(option)
        score = len(normalized) if normalized and normalized in normalized_feedback else 0
        if not score:
            score = sum(
                len(token)
                for token in re.findall(r"[0-9a-zA-Z가-힣]+", option)
                if len(token) > 1 and token.lower() in feedback.lower()
            )
        scores.append(score)
    best = max(range(len(options)), key=scores.__getitem__)
    return [best + 1]


def code_tokens(markdown: str) -> list[str]:
    code = "\n".join(re.findall(r"```(?:swift)?\n(.*?)```", markdown, re.S))
    raw = re.findall(
        r'"(?:\\.|[^"\\])*"|@[A-Za-z_]\w*|[A-Za-z_]\w*|\d+(?:\.\d+)?|==|!=|>=|<=|&&|\|\||->|[+*/%<>]=?|[{}()\[\].,:?]',
        code,
    )
    combined: list[str] = []
    index = 0
    while index < len(raw):
        if raw[index] == "{" and index + 1 < len(raw) and raw[index + 1] == "}":
            combined.append("{}")
            index += 2
        elif raw[index] == "(" and index + 1 < len(raw) and raw[index + 1] == ")":
            combined.append("()")
            index += 2
        else:
            combined.append(raw[index])
            index += 1
    ignored = {"let", "var", "private", "in"}
    result = []
    for token in combined:
        if token in ignored or token in result:
            continue
        result.append(token)
    return result


def token_answer_indexes(tokens: list[str], feedback: str) -> list[int]:
    normalized_feedback = clean(feedback)
    indexes = []
    for index, token in enumerate(tokens, start=1):
        candidate = clean(token)
        literal = token.strip('"')
        matches = candidate and candidate in normalized_feedback
        matches = matches or (literal and f"`{literal}`" in feedback)
        if token in {"{}", "{"}:
            matches = matches or "블록" in feedback or "`{}`" in feedback
        mentions = list(re.finditer(re.escape(literal), feedback, re.I)) if literal else []
        negative_pattern = re.compile(
            re.escape(literal) + r"`?[ \t]*(?:을|를|은|는)?[ \t]*(?:몰라도|미지|아니다|제외|아닌)",
            re.I,
        ) if literal else None
        if mentions and negative_pattern and len(negative_pattern.findall(feedback)) == len(mentions):
            matches = False
        if matches:
            indexes.append(index)
    if not indexes:
        fallback = next(
            (index for index, token in enumerate(tokens, start=1) if token.startswith('"') or token[0].isdigit()),
            1,
        )
        indexes = [fallback]
    return indexes


def activity_guide(title: str, detail: str) -> str:
    return f"> [!game]- 활동 방식 · {title}\n> {detail}\n\n"


def annotate_choice(block: str) -> str:
    if MARKER in block:
        return block
    options = re.findall(r"(?m)^\d+\.\s+(.+)$", block)
    if not options:
        return block
    answers = infer_choice_answers(options, callout_feedback(block))
    first = re.search(r"(?m)^1\.\s+", block)
    contract = (
        activity_guide("판단 카드 고르기", "근거가 되는 카드를 모두 고른 뒤 답을 확인한다.")
        + f"<!-- conriculum-activity: choice; correct: {','.join(map(str, answers))} -->\n\n"
    )
    return block[: first.start()] + contract + block[first.start() :]


def annotate_matching(block: str, source: str, target: str, title: str) -> str:
    if MARKER in block:
        return block
    table = re.search(r"(?m)^\|", block)
    if not table:
        return block
    contract = (
        activity_guide(title, "왼쪽 카드와 오른쪽 카드를 직접 연결하고, 모든 연결을 마친 뒤 한 번에 확인한다.")
        + f"<!-- conriculum-activity: matching; source: {source}; target: {target} -->\n\n"
    )
    return block[: table.start()] + contract + block[table.start() :]


def selection_contract(section: str, title: str) -> str:
    if MARKER in section:
        section = re.sub(
            r"(?m)^> \[!game\]-?[^\n]*\n(?:>.*(?:\n|$))*\n?",
            "",
            section,
        )
        section = re.sub(
            r"(?m)^<!-- conriculum-activity: (?:multiple-choice|choice); correct: [^\n]*-->[ \t]*\n+"
            r"\*\*선택 카드[^\n]*\*\*[ \t]*\n+(?:\d+\. [^\n]*\n?)+[ \t]*\n?",
            "",
            section,
        )
    feedback_match = re.search(r"(?m)^> \[![^\]]+\]-?", section)
    if not feedback_match:
        return section
    feedback = callout_feedback(section)
    tokens = code_tokens(section)
    if len(tokens) < 2:
        return section
    correct = token_answer_indexes(tokens, feedback)
    selected = [tokens[index - 1] for index in correct]
    selected += [token for token in tokens if token not in selected][: max(0, 8 - len(selected))]
    selected = selected[:10]
    correct = [index + 1 for index, token in enumerate(selected) if token in {tokens[item - 1] for item in correct}]
    contract_kind = "choice" if len(correct) == 1 else "multiple-choice"
    detail = (
        "답이 되는 코드 단서 카드 하나를 고르면 바로 확인한다."
        if contract_kind == "choice"
        else "질문에 답이 되는 코드 단서를 모두 고른 뒤 한 번에 확인한다."
    )
    cards = "\n".join(f"{index}. `{token}`" for index, token in enumerate(selected, start=1))
    contract = (
        activity_guide(title, detail)
        + f"<!-- conriculum-activity: {contract_kind}; correct: {','.join(map(str, correct))} -->\n\n"
        + ("**선택 카드:**\n\n" if contract_kind == "choice" else "**선택 카드 (복수 선택 가능):**\n\n")
        + cards
        + "\n\n"
    )
    return section[: feedback_match.start()] + contract + section[feedback_match.start() :]


def annotate_contrast(block: str) -> str:
    if MARKER in block:
        return block
    table_contract = annotate_matching(block, "후보", "판별 단서", "대조 카드 연결하기")
    suspicious = re.search(r"(?m)^### 수상한 카드\s*$", table_contract)
    if not suspicious:
        return table_contract
    tail = table_contract[suspicious.start() :]
    feedback_match = re.search(r"(?m)^> \[![^\]]+\]-?", tail)
    if not feedback_match:
        return table_contract
    feedback = callout_feedback(tail)
    correct = 2 if any(word in feedback for word in ("아니다", "없다", "틀리")) else 1
    contract = (
        activity_guide("주장 판정하기", "주장이 앞의 대조 근거와 맞는지 판단한 뒤 확인한다.")
        + f"<!-- conriculum-activity: choice; correct: {correct} -->\n\n"
        + "1. 근거가 있다\n2. 근거가 없다\n\n"
    )
    insertion = suspicious.start() + feedback_match.start()
    return table_contract[:insertion] + contract + table_contract[insertion:]


def annotate_game_four(block: str) -> str:
    parts = re.split(r"(?m)(?=^### \d+\s*$)", block)
    return "".join(
        selection_contract(part, "코드 단서 고르기") if re.match(r"^### \d+", part) else part
        for part in parts
    )


def transform(text: str) -> str:
    headings = list(re.finditer(r"(?m)^## (.+)$", text))
    replacements = []
    for index, match in enumerate(headings):
        title = match.group(1).strip()
        start = match.end()
        end = headings[index + 1].start() if index + 1 < len(headings) else len(text)
        block = text[start:end]
        if title.startswith("게임 1"):
            updated = annotate_choice(block)
        elif title.startswith("게임 2"):
            updated = annotate_matching(block, "코드 구절", "붙일 역할 카드", "구절과 역할 연결하기")
        elif title.startswith("게임 3"):
            updated = annotate_contrast(block)
        elif title.startswith("게임 4"):
            updated = annotate_game_four(block)
        elif title == "보스 코드":
            updated = selection_contract(block, "보스 단서 모두 찾기")
        else:
            continue
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
    print(f"annotated {changed} of {len(paths)} Stage 1 pages")


if __name__ == "__main__":
    main()
