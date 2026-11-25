#!/usr/bin/env python3
"""Regenerates windows/src/OpenNeko.Core/Skills/skill-translations.json from the
macOS copy table (Sources/OpenNekoKit/Skills/NekoSkillLocalization.swift) so the
two apps localize bundled skills identically. Run after editing the Swift table."""
import json, re, pathlib

root = pathlib.Path(__file__).resolve().parents[2]
src = (root / "Sources/OpenNekoKit/Skills/NekoSkillLocalization.swift").read_text(encoding="utf-8")
table = src[src.index("translations: [String: [String: Text]] = ["):]

def swift_string(s, i):
    """Parse a Swift string literal at s[i]; return (value, next_index)."""
    if s.startswith('"""', i):
        end = s.index('"""', i + 3)
        raw = s[i + 3:end]
        lines = raw.split("\n")[1:]  # drop the line with the opening delimiter
        indent = len(lines[-1])      # closing delimiter indentation
        body = "\n".join(l[indent:] for l in lines[:-1])
        return unescape(body), end + 3
    j = i + 1
    out = []
    while s[j] != '"':
        if s[j] == "\\":
            out.append(s[j:j + 2]); j += 2
        else:
            out.append(s[j]); j += 1
    return unescape("".join(out)), j + 1

def unescape(v):
    return v.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")

result = {}
lang_re = re.compile(r'^\s{8}"(ko|en|ja|zh)": \[', re.M)
text_re = re.compile(r'"([a-z0-9-]+)": Text\(\s*name: ')
positions = [(m.start(), m.group(1)) for m in lang_re.finditer(table)]
positions.append((len(table), None))
for (start, code), (end, _) in zip(positions, positions[1:]):
    chunk = table[start:end]
    entries = {}
    for t in text_re.finditer(chunk):
        sid = t.group(1)
        k = t.end()
        name, k = swift_string(chunk, k)
        k = chunk.index("description: ", k) + len("description: ")
        desc, k = swift_string(chunk, k)
        k = chunk.index("body: ", k) + len("body: ")
        body, k = swift_string(chunk, k)
        entries[sid] = {"name": name, "description": desc, "body": body}
    result[code] = entries

out = root / "windows/src/OpenNeko.Core/Skills/skill-translations.json"
out.write_text(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
print({k: len(v) for k, v in result.items()})
