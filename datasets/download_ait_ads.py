"""Скачивает AIT Alert Data Set (AIT-ADS) с Zenodo и проверяет md5.

Запуск из корня репозитория:
    python datasets/download_ait_ads.py

Файлы появятся в datasets/raw/ait_ads/ (папка raw/ в .gitignore).
Уже скачанные файлы с правильной суммой повторно не качаются.
"""
import hashlib
import sys
import urllib.request
from pathlib import Path

RECORD = "https://zenodo.org/records/8263181/files"
FILES = {
    "ait_ads.zip": "43db6b1f0996e0024befd617706c50e9",  # 96,2 МБ
    "labels.csv": "60ff33796c77fd2136c4d1a4bc841bd9",   # 3,7 КБ
}
DEST = Path(__file__).resolve().parent / "raw" / "ait_ads"


def md5(path: Path) -> str:
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def progress(blocks: int, block_size: int, total: int) -> None:
    if total > 0:
        done = min(blocks * block_size, total)
        print(f"\r  {done / 1e6:6.1f} / {total / 1e6:.1f} МБ", end="", flush=True)


def main() -> int:
    DEST.mkdir(parents=True, exist_ok=True)
    ok = True
    for name, expected in FILES.items():
        path = DEST / name
        if path.exists() and md5(path) == expected:
            print(f"{name}: уже скачан, md5 совпадает")
            continue
        print(f"{name}: качаю...")
        urllib.request.urlretrieve(f"{RECORD}/{name}?download=1", path, progress)
        print()
        actual = md5(path)
        if actual == expected:
            print(f"{name}: md5 совпадает")
        else:
            print(f"{name}: ОШИБКА md5 — ожидалось {expected}, получено {actual}")
            ok = False
    print(f"\nГотово: {DEST}" if ok else "\nЕсть ошибки, скачайте заново")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
