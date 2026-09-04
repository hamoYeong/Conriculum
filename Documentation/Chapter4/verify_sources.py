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
                assert (args.vault / (target.split('#')[0] + '.md')).is_file(), target
    catalog = read_json('KnowledgeCatalog/values-and-types.json')
    new_ids = {entry['stableID'] for entry in manifest['identities']
               if entry['kind'] == 'knowledgeConcept' and (SNAPSHOTS / entry['sourcePath']).is_file()}
    for concept in catalog['concepts']:
        if concept['id'] not in new_ids or concept['id'] in ['concept-bool', 'concept-semantic-chunk-reading']:
            continue
        source = normalize((SNAPSHOTS / paths[concept['id']]).read_text())
        for key in ['title', 'definition', 'essentialQuestion', 'judgmentQuestions', 'examples', 'misconceptions']:
            for value in strings(concept[key]):
                assert normalize(value) in source, (concept['id'], key)
    snapshots = list(SNAPSHOTS.rglob('*.md'))
    if args.vault:
        for path in snapshots:
            assert path.read_bytes() == (args.vault / path.relative_to(SNAPSHOTS)).read_bytes(), path
    print(f'PASS: 10 pages, {count} payload strings, 6 new concepts, {len(snapshots)} source snapshots')


if __name__ == '__main__':
    main()
