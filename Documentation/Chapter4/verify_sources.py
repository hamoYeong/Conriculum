#!/usr/bin/env python3
"""Check promoted Chapter 4 payloads against their reviewable Obsidian sources.

Run from any directory. Pass --vault PATH to also compare the live vault with
checked-in snapshots and resolve every Chapter 4 wikilink in the full vault.
This checks source parity; Swift ContentValidator checks the runtime schema.
"""
import argparse
import json
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
RESOURCES = REPO / 'Conriculum/Resources'
SNAPSHOTS = Path(__file__).resolve().parent / 'Obsidian'


def read_json(relative):
    return json.loads((RESOURCES / relative).read_text())


def normalize(text):
    return re.sub(r'\s+', ' ', text).strip()


def strings(value):
    if isinstance(value, dict):
        for child in value.values():
            yield from strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from strings(child)
    elif isinstance(value, str):
        yield value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--vault', type=Path)
    args = parser.parse_args()
    chapter = read_json('Curriculum/Stage01/Chapter04/chapter-04.json')
    manifest = read_json('ContentManifest/content-identity.json')
    paths = {entry['stableID']: entry['sourcePath'] for entry in manifest['identities']}
    translations = {'primary': '핵심', 'supporting': '보조', 'conceptRevision': '나의 개념 표현'}
    count = 0
    for page in [chapter['overview']] + chapter['pages']:
        source = (SNAPSHOTS / paths[page['id']]).read_text()
        assert page['id'] in source and page['goal'] in source, page['id']
        positions = [source.index(section['id']) for section in page['sections']]
        assert positions == sorted(positions), f"Section order: {page['id']}"
        for section in page['sections']:
            if section.get('title'):
                assert section['title'] in source
            if section.get('activityID'):
                assert section['activityID'] in source
            payload = section['content']['payload']
            for value in strings(payload):
                expected = paths[value][:-3] if value.startswith('concept-') else translations.get(value, value)
                assert normalize(expected) in normalize(source), (page['id'], value)
                count += 1
        for value in strings(page['knowledgeContext']):
            expected = paths[value][:-3] if value.startswith('concept-') else value
            assert normalize(expected) in normalize(source), (page['id'], value)
        for destination in page['navigation'].values():
            if destination:
                # Chapter 5 is intentionally not bundled yet; its source page exists.
                target = paths.get(destination['pageID'])
                if target:
                    assert target[:-3] in source, (page['id'], destination)
        if args.vault:
            for target in re.findall(r'\[\[([^\]|]+)', source):
                target_path = target.split('#')[0].rstrip('\\')
                assert (args.vault / (target_path + '.md')).is_file(), target
    catalog = read_json('KnowledgeCatalog/values-and-types.json')
    # Existing notes copied for connection review retain their earlier wording.
    promoted_ids = {'concept-' + name for name in [
        'condition-question', 'comparison-operator', 'condition-boundary',
        'logical-composition', 'named-condition', 'condition-counterexample',
        'example-validation',
    ]}
    for concept in catalog['concepts']:
        if concept['id'] not in promoted_ids:
            continue
        source = normalize((SNAPSHOTS / paths[concept['id']]).read_text())
        for key in ['title', 'definition', 'essentialQuestion', 'judgmentQuestions', 'examples', 'misconceptions']:
            for value in strings(concept[key]):
                assert normalize(value) in source, (concept['id'], key)
    # Every catalog concept has one canonical revisit section. Runtime references
    # must contain the same page link and explanation as the Obsidian source.
    revisit_count = 0
    banned_revisit_headings = {
        '## 이 지식을 사용하는 학습 페이지',
        '## Chapter 4에서 다시 쓰기',
        '## Chapter 4와 연결되는 지식',
    }
    for concept in catalog['concepts']:
        source_path = SNAPSHOTS / paths[concept['id']]
        source = source_path.read_text()
        assert source.count('\n## 다시 보기\n') == 1, concept['id']
        assert not any(heading in source for heading in banned_revisit_headings), concept['id']
        references = concept.get('revisitPages')
        assert references is not None, concept['id']
        page_ids = [reference['pageID'] for reference in references]
        assert len(page_ids) == len(set(page_ids)), concept['id']
        assert references == sorted(
            references,
            key=lambda reference: (
                reference['chapterOrder'],
                reference.get('pageOrder') or 0,
                reference['pageID'],
            ),
        ), concept['id']
        for reference in references:
            assert paths[reference['pageID']][:-3] in source, (concept['id'], reference['pageID'])
            assert reference['connection'] in source, (concept['id'], reference['pageID'])
            revisit_count += 1
    assert revisit_count == 149, revisit_count
    # Check old and new pages' optional links, plus both ends of documented graph edges.
    linked_pages = 0
    for number in [2, 3, 4]:
        resource = read_json(f'Curriculum/Stage01/Chapter{number:02}/chapter-{number:02}.json')
        for page in [resource['overview']] + resource['pages']:
            path = SNAPSHOTS / paths[page['id']]
            if not path.exists():
                continue
            source = path.read_text()
            if '- 가까운 지식:' not in source:
                continue
            for nearby in page['knowledgeContext']['nearbyKnowledge']:
                assert nearby['reason'] in source, (page['id'], nearby)
                assert paths[nearby['conceptID']][:-3] in source
            linked_pages += 1
    linked_edges = 0
    for edge in catalog['relations']:
        endpoint_paths = [SNAPSHOTS / paths[edge[key]] for key in ['sourceConceptID', 'targetConceptID']]
        marker = '<!-- relation: ' + edge['id'] + ' -->'
        if not any(path.exists() and marker in path.read_text() for path in endpoint_paths):
            continue
        for path in endpoint_paths:
            source = path.read_text()
            assert marker in source and edge['summary'] in source, (edge['id'], path)
        linked_edges += 1
    snapshots = list(SNAPSHOTS.rglob('*.md'))
    if args.vault:
        for path in snapshots:
            assert path.read_bytes() == (args.vault / path.relative_to(SNAPSHOTS)).read_bytes(), path
            for target in re.findall(r'\[\[([^\]|]+)', path.read_text()):
                target_path = target.split('#')[0].rstrip('\\')
                assert (args.vault / (target_path + '.md')).is_file(), (path, target)
    print(f'PASS: 10 pages, {count} payload strings, {len(promoted_ids)} promoted concepts, {len(snapshots)} source snapshots; {revisit_count} revisit links, {linked_pages} nearby scopes, {linked_edges} two-ended graph links')


if __name__ == '__main__':
    main()
