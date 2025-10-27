from __future__ import annotations

from collections import defaultdict
from pathlib import Path
import json
import sys
import re

TS_ROOT = Path('typescript/src')
DART_ROOT = Path('lib/src')


def normalize_path(rel_path: Path) -> str:
    parts: list[str] = []
    rel_parts = list(rel_path.parts)
    for idx, part in enumerate(rel_parts):
        current = Path(part).stem if idx == len(rel_parts) - 1 else part
        current = current.replace('-', '_')
        current = re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', current)
        current = re.sub(r'([A-Z]+)([A-Z][a-z])', r'\1_\2', current)
        parts.append(current.lower())
    return '/'.join(parts)


def collect_ts_paths() -> list[Path]:
    return [
        path
        for path in TS_ROOT.rglob('*.ts')
        if not path.name.endswith('.d.ts')
    ]


def to_dart_path(ts_path: Path) -> Path:
    rel_parts = list(ts_path.relative_to(TS_ROOT).parts)
    converted = []
    for idx, part in enumerate(rel_parts):
        name = Path(part).stem if idx == len(rel_parts) - 1 else part
        name = name.replace('-', '_')
        name = re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', name)
        name = re.sub(r'([A-Z]+)([A-Z][a-z])', r'\1_\2', name)
        converted.append(name.lower())
    return DART_ROOT.joinpath(*converted).with_suffix('.dart')


def main() -> None:
    ts_paths = collect_ts_paths()
    missing: list[str] = []
    stubbed: list[str] = []

    for ts_path in ts_paths:
        dart_path = to_dart_path(ts_path)
        rel_key = normalize_path(ts_path.relative_to(TS_ROOT))
        if not dart_path.exists():
            missing.append(rel_key)
            continue

        content = dart_path.read_text(encoding='utf-8', errors='ignore')
        if 'UnimplementedError' in content or not _has_meaningful_code(content):
            stubbed.append(rel_key)

    grouped_stubbed: dict[str, list[str]] = defaultdict(list)
    for path in stubbed:
        top = path.split('/', 1)[0]
        grouped_stubbed[top].append(path)

    if '--markdown' in sys.argv:
        print(_format_markdown(stubbed, grouped_stubbed))
        return

    summary = {
        'ts_total': len(ts_paths),
        'missing': sorted(missing),
        'missing_count': len(missing),
        'stubbed': sorted(stubbed),
        'stubbed_count': len(stubbed),
        'stubbed_grouped': grouped_stubbed,
    }

    print(json.dumps(summary, indent=2, sort_keys=True))


def _has_meaningful_code(content: str) -> bool:
    in_block_comment = False
    for raw_line in content.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if in_block_comment:
            if '*/' in line:
                in_block_comment = False
            continue
        if line.startswith('/*'):
            if not line.endswith('*/'):
                in_block_comment = True
            continue
        if line.startswith('//') or line.startswith('///'):
            continue
        if line.startswith('import '):
            continue
        # Treat any remaining statement as meaningful (exports, classes, etc.).
        return True
    return False


def _format_markdown(stubbed: list[str], grouped: dict[str, list[str]]) -> str:
    lines: list[str] = []
    lines.append(f"Total pendente: {len(stubbed)} arquivos")
    lines.append('')
    for group in sorted(grouped):
        items = sorted(grouped[group])
        lines.append(f"### {group} ({len(items)} arquivos)")
        for item in items:
            lines.append(f"- `lib/src/{item}.dart`")
        lines.append('')
    return '\n'.join(lines).rstrip() + '\n'


if __name__ == '__main__':
    main()
