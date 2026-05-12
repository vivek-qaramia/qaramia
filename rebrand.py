import os

ROOT = r'E:\claude\qaramia-v2\web_app'

REPLACEMENTS = [
    # Hover variant of primary
    ('hover:bg-[#b8e600]',          'hover:bg-[#e55a2b]'),
    # Lime on buttons used text-black — peach works with text-white
    ('bg-[#CAFF00] text-black',     'bg-[#FF7043] text-white'),
    # Opacity variants
    ('#CAFF00]/',                   '#FF7043]/'),
    # Remaining bare lime refs
    ('#CAFF00',                     '#FF7043'),
    # Accent: hot pink → butter yellow
    ('#FF2D78]/',                   '#FFD166]/'),
    ('#FF2D78',                     '#FFD166'),
]

EXTS = {'.tsx', '.ts', '.css', '.html'}

changed = []
for dirpath, _, filenames in os.walk(ROOT):
    if '.next' in dirpath:
        continue
    for fname in filenames:
        if not any(fname.endswith(e) for e in EXTS):
            continue
        path = os.path.join(dirpath, fname)
        with open(path, 'r', encoding='utf-8') as f:
            src = f.read()
        dst = src
        for old, new in REPLACEMENTS:
            dst = dst.replace(old, new)
        if dst != src:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(dst)
            changed.append(path.replace(ROOT + os.sep, ''))

print(f'Updated {len(changed)} files:')
for p in changed: print(' ', p)
