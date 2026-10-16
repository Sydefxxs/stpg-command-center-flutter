"""Add STPG metadata + assets to the pubspec created by `flutter create` / `flutter pub add`."""
import pathlib, re
p = pathlib.Path(__file__).resolve().parent.parent / 'pubspec.yaml'
s = p.read_text()
s = re.sub(r'^description:.*$', 'description: STPG Raptor Command Center — Flutter rebuild for Android and iOS.', s, flags=re.M)
s = re.sub(r'^version:.*$', 'version: 2.0.0+1', s, flags=re.M)
if 'assets/images/' not in s:
    s = s.replace('  uses-material-design: true', '  uses-material-design: true\n  assets:\n    - assets/images/\n    - assets/icon/', 1)
p.write_text(s)
print('pubspec updated')
