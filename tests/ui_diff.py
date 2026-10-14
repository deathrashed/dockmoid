"""Compare two folders of ui_runtime screenshots (DOCKMOID_UI_CAPTURE_DIR).

Development aid, not part of tests/run.sh: it needs PySide6 and two earlier
captures. Usage: python3 tests/ui_diff.py BEFORE_DIR AFTER_DIR [--save DIR]
Prints, per image, how many pixels changed, the largest per-channel change and
the box around the changes. --save writes a red-on-black change map per image.
"""
import os, pathlib, sys

os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
from PySide6.QtGui import QGuiApplication, QImage, qRed, qGreen, qBlue, qRgb


def compare(a, b):
    if a.size() != b.size():
        return None
    changed = 0
    biggest = 0
    left = top = 10 ** 9
    right = bottom = -1
    mask = QImage(a.size(), QImage.Format_RGB32)
    mask.fill(0)
    for y in range(a.height()):
        for x in range(a.width()):
            p, q = a.pixel(x, y), b.pixel(x, y)
            if p == q:
                continue
            changed += 1
            biggest = max(biggest, abs(qRed(p) - qRed(q)), abs(qGreen(p) - qGreen(q)), abs(qBlue(p) - qBlue(q)))
            left, right, top, bottom = min(left, x), max(right, x), min(top, y), max(bottom, y)
            mask.setPixel(x, y, qRgb(255, 0, 0))
    box = (left, top, right, bottom) if changed else None
    return changed, biggest, box, mask


def main(argv):
    args = [a for a in argv if not a.startswith('--')]
    save = None
    if '--save' in argv:
        save = pathlib.Path(argv[argv.index('--save') + 1])
        args = [a for a in args if a != str(save)]
        save.mkdir(parents=True, exist_ok=True)
    if len(args) != 2:
        print(__doc__)
        return 2
    before, after = (pathlib.Path(a) for a in args)
    QGuiApplication([])
    names = sorted(p.name for p in before.glob('*.png'))
    if not names:
        print('No screenshots in', before)
        return 2
    total = 0
    for name in names:
        other = after / name
        if not other.exists():
            print(f'{name}: missing in {after}')
            total += 1
            continue
        result = compare(QImage(str(before / name)), QImage(str(other)))
        if result is None:
            print(f'{name}: size differs')
            total += 1
            continue
        changed, biggest, box, mask = result
        total += changed
        if changed:
            print(f'{name}: {changed} px changed, max channel delta {biggest}, box {box}')
            if save:
                mask.save(str(save / name))
        else:
            print(f'{name}: identical')
    print(f'{len(names)} images compared, {total} changed pixels in total')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
