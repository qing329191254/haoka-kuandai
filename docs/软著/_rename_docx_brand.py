from __future__ import annotations

from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


ROOT = Path(__file__).resolve().parent
OLD = "星链云".encode("utf-8")
NEW = "派客邦".encode("utf-8")


def replace_in_docx(path: Path) -> int:
    temp = path.with_suffix(".renaming.docx")
    replacements = 0
    with ZipFile(path, "r") as source, ZipFile(temp, "w", compression=ZIP_DEFLATED) as target:
        for info in source.infolist():
            data = source.read(info.filename)
            if info.filename.endswith(".xml"):
                count = data.count(OLD)
                if count:
                    data = data.replace(OLD, NEW)
                    replacements += count
            copied = ZipInfo(info.filename, date_time=info.date_time)
            copied.compress_type = info.compress_type
            copied.comment = info.comment
            copied.extra = info.extra
            copied.internal_attr = info.internal_attr
            copied.external_attr = info.external_attr
            copied.create_system = info.create_system
            target.writestr(copied, data)
    temp.replace(path)
    return replacements


if __name__ == "__main__":
    total = 0
    for document in sorted(ROOT.glob("*.docx")):
        count = replace_in_docx(document)
        total += count
        print(f"{document.name}: {count}")
    if total == 0:
        raise SystemExit("No brand text found in DOCX files")
