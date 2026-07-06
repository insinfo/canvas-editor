import os
import re

root_ts = r"c:\\MyDartProjects\\canvas-editor-port\\typescript\\src"
root_dart = r"c:\\MyDartProjects\\canvas-editor-port\\lib\\src"

missing = []

def to_snake(name: str) -> str:
    name = name.replace('-', '_')
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()

for dirpath, _, filenames in os.walk(root_ts):
    for filename in filenames:
        if not filename.endswith('.ts'):
            continue
        rel = os.path.relpath(os.path.join(dirpath, filename), root_ts)
        parts = rel.split(os.sep)
        snake_parts = [to_snake(part) for part in parts]
        snake_parts[-1] = snake_parts[-1][:-3]  # remove extension
        dart_path = os.path.join(root_dart, *snake_parts) + '.dart'
        if not os.path.exists(dart_path):
            missing.append(rel)

missing.sort()
for rel in missing:
    print(rel)
print('TOTAL', len(missing))
