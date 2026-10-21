"""手动补齐演示数据：python -m app.seed_demo"""
from __future__ import annotations

from app.db import SessionLocal
from app.seed import _ensure_rich_content, _ensure_service_role_perms, _migrate_brand_name


def main() -> None:
    db = SessionLocal()
    try:
        _migrate_brand_name(db)
        _ensure_rich_content(db)
        _ensure_service_role_perms(db)
        print("demo data ensured")
    finally:
        db.close()


if __name__ == "__main__":
    main()
