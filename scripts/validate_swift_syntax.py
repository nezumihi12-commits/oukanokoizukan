"""Optional Windows syntax/YAML check; not a substitute for Xcode type checking.
Install: python -m pip install tree-sitter tree-sitter-swift pyyaml
Run: python scripts/validate_swift_syntax.py
"""
from pathlib import Path
import yaml
from tree_sitter import Language, Parser
import tree_sitter_swift

root = Path(__file__).resolve().parents[1]
parser = Parser(Language(tree_sitter_swift.language()))
errors = []
def check(node, file):
    if node.type == 'ERROR' or node.is_missing:
        errors.append((str(file.relative_to(root)), node.start_point, node.type))
    for child in node.children:
        check(child, file)
files = list(root.rglob('*.swift'))
for file in files:
    check(parser.parse(file.read_bytes()).root_node, file)
assert not errors, errors
project = yaml.safe_load((root / 'project.yml').read_text(encoding='utf-8'))
workflow = yaml.safe_load((root / '.github/workflows/ios.yml').read_text(encoding='utf-8'))
assert workflow['jobs']['ios']['runs-on'] == 'macos-15'
for target in project['targets'].values():
    for source in target['sources']:
        assert (root / (source if isinstance(source, str) else source['path'])).exists()
print(f'PASS: {len(files)} Swift syntax trees and YAML source references')
