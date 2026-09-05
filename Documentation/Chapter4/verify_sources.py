#!/usr/bin/env python3
"""Validate the bundled Chapter 2-4 JSON knowledge and revisit references."""
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
RESOURCES = REPO / "Conriculum/Resources"


def read_json(relative):
    return json.loads((RESOURCES / relative).read_text())


def main():
    chapters = [
        read_json(f"Curriculum/Stage01/Chapter{number:02}/chapter-{number:02}.json")
        for number in (2, 3, 4)
    ]
    catalog = read_json("KnowledgeCatalog/values-and-types.json")
    manifest = read_json("ContentManifest/content-identity.json")
    identities = {
        (entry["kind"], entry["stableID"])
        for entry in manifest["identities"]
    }
    pages = {}
    nearby_scopes = 0
    for chapter in chapters:
        assert ("chapter", chapter["id"]) in identities, chapter["id"]
        for page in [chapter["overview"]] + chapter["pages"]:
            assert page["id"] not in pages, page["id"]
            assert ("page", page["id"]) in identities, page["id"]
            pages[page["id"]] = (chapter, page)
            nearby = page["knowledgeContext"]["nearbyKnowledge"]
            nearby_scopes += bool(nearby)
            for item in nearby:
                assert ("knowledgeConcept", item["conceptID"]) in identities, item
                assert item["reason"].strip(), item

    concept_ids = {concept["id"] for concept in catalog["concepts"]}
    assert len(concept_ids) == len(catalog["concepts"]) == 36
    revisit_count = 0
    for concept in catalog["concepts"]:
        assert ("knowledgeConcept", concept["id"]) in identities, concept["id"]
        references = concept.get("revisitPages")
        assert references is not None, concept["id"]
        page_ids = [reference["pageID"] for reference in references]
        assert len(page_ids) == len(set(page_ids)), concept["id"]
        assert references == sorted(
            references,
            key=lambda reference: (
                reference["chapterOrder"],
                reference.get("pageOrder") or 0,
                reference["pageID"],
            ),
        ), concept["id"]
        for reference in references:
            chapter, page = pages[reference["pageID"]]
            assert reference["chapterID"] == chapter["id"], reference
            assert reference["chapterOrder"] == chapter["order"], reference
            assert reference["chapterTitle"] == chapter["title"], reference
            assert reference["pageTitle"] == page["title"], reference
            assert reference["connection"].strip(), reference
            assert reference["kind"] in {"direct", "nearby"}, reference
            revisit_count += 1
    assert revisit_count == 149, revisit_count

    for relation in catalog["relations"]:
        assert relation["sourceConceptID"] in concept_ids, relation["id"]
        assert relation["targetConceptID"] in concept_ids, relation["id"]
        assert relation["summary"].strip(), relation["id"]

    print(
        "PASS: "
        f"{len(chapters)} chapters, {len(pages)} pages, "
        f"{len(concept_ids)} concepts, {revisit_count} revisit links, "
        f"{nearby_scopes} nearby scopes, {len(catalog['relations'])} relations"
    )


if __name__ == "__main__":
    main()
