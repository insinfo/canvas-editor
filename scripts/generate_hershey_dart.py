import ast
import json
from pathlib import Path

ts_path = Path(
    'c:/MyDartProjects/canvas-editor-port/typescript/src/editor/core/draw/particle/latex/utils/hershey.ts'
)
dart_path = Path(
    'c:/MyDartProjects/canvas-editor-port/lib/src/editor/core/draw/particle/latex/utils/hershey.dart'
)

ts_text = ts_path.read_text(encoding='utf-8')
raw_start = ts_text.index('const raw')
raw_start = ts_text.index('{', raw_start)
raw_end = ts_text.rfind('}')
if raw_end == -1:
  raise RuntimeError('Failed to locate end of raw map')

raw_body = ts_text[raw_start + 1 : raw_end]

mapping: dict[int, str] = {}
for line in raw_body.splitlines():
    stripped = line.strip()
    if not stripped or stripped.startswith('//'):
        continue
    if ':' not in stripped:
        continue
    key_part, value_part = stripped.split(':', 1)
    key = int(key_part.strip())
    value_literal = value_part.strip().rstrip(',')
    value = ast.literal_eval(value_literal)
    mapping[key] = value

header = """// ignore_for_file: lines_longer_than_80_chars

class HersheyEntry {
  const HersheyEntry({
    required this.width,
    required this.xmin,
    required this.xmax,
    required this.ymin,
    required this.ymax,
    required this.polylines,
  });

  final int width;
  final int xmin;
  final int xmax;
  final int ymin;
  final int ymax;
  final List<List<List<int>>> polylines;
}

const int _ordR = 82;

final Map<int, HersheyEntry> _hersheyCache = <int, HersheyEntry>{};

HersheyEntry? HERSHEY(int index) {
  final cached = _hersheyCache[index];
  if (cached != null) {
    return cached;
  }

  final compiled = _compile(index);
  if (compiled != null) {
    _hersheyCache[index] = compiled;
  }

  return compiled;
}

HersheyEntry? _compile(int index) {
  final entry = _raw[index];
  if (entry == null || entry.length <= 5) {
    return null;
  }

  final bounds = entry.substring(3, 5);
  final int xmin = bounds.codeUnitAt(0) - _ordR;
  final int xmax = bounds.codeUnitAt(1) - _ordR;
  final String content = entry.substring(5);

  final List<List<List<int>>> polylines = <List<List<int>>>[];
  polylines.add(<List<int>>[]);
  int? ymin;
  int? ymax;
  int? zmin;
  int? zmax;

  for (var j = 0; j + 1 < content.length; j += 2) {
    final digit = content.substring(j, j + 2);
    if (digit == ' R') {
      polylines.add(<List<int>>[]);
      continue;
    }

    final int x = digit.codeUnitAt(0) - _ordR - xmin;
    final int y = digit.codeUnitAt(1) - _ordR;

    ymin = (ymin == null || y < ymin) ? y : ymin;
    ymax = (ymax == null || y > ymax) ? y : ymax;
    zmin = (zmin == null || x < zmin) ? x : zmin;
    zmax = (zmax == null || x > zmax) ? x : zmax;

    polylines.last.add(<int>[x, y]);
  }

  return HersheyEntry(
    width: xmax - xmin,
    xmin: zmin ?? 0,
    xmax: zmax ?? 0,
    ymin: ymin ?? 0,
    ymax: ymax ?? 0,
    polylines: polylines,
  );
}

const Map<int, String> _raw = <int, String>{
"""

lines = [header]
for key in sorted(mapping):
    lines.append(f"  {key}: {json.dumps(mapping[key])},\n")
lines.append('};\n')

dart_path.write_text(''.join(lines), encoding='utf-8')
