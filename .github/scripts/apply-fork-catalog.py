#!/usr/bin/env python3
"""Apply the fork's catalog entries to upstream's ports.json, in place.

Usage: apply-fork-catalog.py <ports.json> <fork/ports.json>

Edits the text of <ports.json> instead of re-serializing it, so the diff
against upstream only touches the fork's entries. For each entry in
<fork/ports.json>:
  - an upstream entry whose "name" or "-name" equals the fork entry's "name"
    has its body replaced by the fork entry;
  - otherwise the fork entry is inserted just before the final entry (the
    schema/documentation entry).
Exits non-zero on an unexpected layout or if the result fails validation.
Python 3 standard library only. Used by .github/scripts/sync-upstream.sh.
"""
import json
import sys

HEADER = ['{', '  "ports": [', '    {']
FOOTER = ['    }', '  ]', '}']
DELIM = '    },{'
INDENT = '      '


def fail(msg):
    print(f"apply-fork-catalog: error: {msg}", file=sys.stderr)
    sys.exit(1)


def render(entry):
    lines = [f'{INDENT}{json.dumps(k, ensure_ascii=False)}: {json.dumps(v, ensure_ascii=False)}'
             for k, v in entry.items()]
    return ',\n'.join(lines).split('\n')


def block_name(block, index):
    try:
        obj = json.loads('{\n' + '\n'.join(block) + '\n}')
    except json.JSONDecodeError as e:
        fail(f"entry block #{index + 1} is not valid JSON on its own ({e}); unknown layout")
    return obj.get('name', obj.get('-name'))


def main():
    if len(sys.argv) != 3:
        fail("usage: apply-fork-catalog.py <ports.json> <fork/ports.json>")
    catalog_path, fork_path = sys.argv[1], sys.argv[2]

    with open(catalog_path, encoding='utf-8', newline='') as f:
        text = f.read()
    try:
        original = json.loads(text)
    except json.JSONDecodeError as e:
        fail(f"{catalog_path} is not valid JSON: {e}")
    with open(fork_path, encoding='utf-8') as f:
        fork = json.load(f)
    fork_entries = fork.get('ports') if isinstance(fork, dict) else None
    if not isinstance(fork_entries, list) or not all(
            isinstance(e, dict) and isinstance(e.get('name'), str) for e in fork_entries):
        fail(f'{fork_path} must look like {{"ports": [{{"name": ...}}, ...]}}')

    eol = '\r\n' if '\r\n' in text else '\n'
    lines = text.split(eol)
    trailing = lines and lines[-1] == ''
    if trailing:
        lines.pop()
    if lines[:3] != HEADER:
        fail(f"{catalog_path} does not start with the expected '{{ \"ports\": [ {{' layout")
    if lines[-3:] != FOOTER:
        fail(f"{catalog_path} does not end with the expected '}} ] }}' layout")
    body = lines[3:-3]
    if DELIM not in body:
        fail(f"entry delimiter line {DELIM!r} not found in {catalog_path}")

    blocks = [[]]
    for line in body:
        if line == DELIM:
            blocks.append([])
        else:
            blocks[-1].append(line)
    if len(blocks) != len(original.get('ports', [])):
        fail(f"split {len(blocks)} entry blocks but the file has "
             f"{len(original.get('ports', []))} entries; unknown layout")
    names = [block_name(b, i) for i, b in enumerate(blocks)]

    appended = 0
    for entry in fork_entries:
        rendered = render(entry)
        matches = [i for i, n in enumerate(names) if n == entry['name']]
        if len(matches) > 1:
            fail(f"{len(matches)} upstream entries are named {entry['name']!r}; refusing to guess")
        if matches:
            blocks[matches[0]] = rendered
            print(f"replaced: {entry['name']}")
        else:
            blocks.insert(len(blocks) - 1, rendered)
            names.insert(len(names) - 1, entry['name'])
            appended += 1
            print(f"added: {entry['name']}")

    out_lines = HEADER[:]
    for i, b in enumerate(blocks):
        if i:
            out_lines.append(DELIM)
        out_lines.extend(b)
    out_lines.extend(FOOTER)
    out = eol.join(out_lines) + (eol if trailing else '')

    with open(catalog_path, 'w', encoding='utf-8', newline='') as f:
        f.write(out)

    with open(catalog_path, encoding='utf-8') as f:
        try:
            result = json.load(f)
        except json.JSONDecodeError as e:
            fail(f"result is not valid JSON: {e}")
    ports = result.get('ports', [])
    for entry in fork_entries:
        if entry not in ports:
            fail(f"result does not contain fork entry {entry['name']!r} unchanged")
    expected = len(original['ports']) + appended
    if len(ports) != expected:
        fail(f"result has {len(ports)} entries, expected {expected}")


if __name__ == '__main__':
    main()
