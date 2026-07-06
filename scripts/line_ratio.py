import os
import re

root_ts = r"c:\\MyDartProjects\\canvas-editor-port\\typescript\\src"
root_dart = r"c:\\MyDartProjects\\canvas-editor-port\\lib\\src"

def to_snake(name: str) -> str:
    name = name.replace('-', '_')
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()

pairs = []
missing = []
for dirpath, _, filenames in os.walk(root_ts):
    for filename in filenames:
        if not filename.endswith('.ts'):
            continue
        rel = os.path.relpath(os.path.join(dirpath, filename), root_ts)
        parts = rel.split(os.sep)
        snake_dirs = [to_snake(part) for part in parts[:-1]]
        snake_name = to_snake(parts[-1][:-3]) + '.dart'
        dart_path = os.path.join(root_dart, *snake_dirs, snake_name)
        if os.path.exists(dart_path):
            with open(os.path.join(dirpath, filename), 'r', encoding='utf-8') as f_ts:
                ts_lines = sum(1 for _ in f_ts)
            with open(dart_path, 'r', encoding='utf-8') as f_dart:
                dart_lines = sum(1 for _ in f_dart)
            ratio = dart_lines / ts_lines if ts_lines else 1.0
            pairs.append((ratio, ts_lines, dart_lines, rel, dart_path[len(root_dart)+1:]))
        else:
            missing.append(rel)

pairs.sort(key=lambda x: x[0])
total_ratio = sum(ratio for ratio, *_ in pairs)
avg_ratio = total_ratio / len(pairs) if pairs else 0.0

print("Lowest ratios (first 20):")
for ratio, ts_lines, dart_lines, ts_rel, dart_rel in pairs[:20]:
    print(f"{ratio:.2f}\tTS:{ts_lines}\tDart:{dart_lines}\t{ts_rel}\t{dart_rel}")

print("\nHighest ratios (last 20):")
for ratio, ts_lines, dart_lines, ts_rel, dart_rel in pairs[-20:]:
    print(f"{ratio:.2f}\tTS:{ts_lines}\tDart:{dart_lines}\t{ts_rel}\t{dart_rel}")

print(f"\nMatched files: {len(pairs)}")
print(f"Average ratio: {avg_ratio:.2f}")
print(f"Missing Dart counterparts: {len(missing)}")
if missing:
    print("Sample missing (up to 20):")
    for rel in missing[:20]:
        print(f" - {rel}")
