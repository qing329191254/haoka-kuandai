"""客服会话维护：静默自动结束 + 过期消息清理。"""

from __future__ import annotations

import asyncio
import logging

from app.cs_chat import close_idle_conversations, purge_old_messages
from app.cs_hub import cs_hub
from app.db import SessionLocal

logger = logging.getLogger(__name__)

# 每小时扫一次足够：48h 静默 / 90 天保留都不是分钟级需求
MAINTENANCE_INTERVAL_SEC = 3600


def run_cs_maintenance() -> None:
    db = SessionLocal()
    try:
        closed = close_idle_conversations(db)
        purged = purge_old_messages(db)
        db.commit()
        for conv in closed:
            try:
                db.refresh(conv)
            except Exception:
                pass
            cs_hub.publish_conversation(conv)
        if closed or purged:
            logger.info("cs maintenance done: closed=%s purged_messages=%s", len(closed), purged)
    except Exception:
        db.rollback()
        logger.exception("cs maintenance failed")
        raise
    finally:
        db.close()


async def cs_maintenance_loop() -> None:
    # 启动稍等再跑，避免和 seed / 启动流量抢库
    await asyncio.sleep(15)
    while True:
        try:
            await asyncio.to_thread(run_cs_maintenance)
        except Exception:
            logger.exception("cs maintenance loop error")
        await asyncio.sleep(MAINTENANCE_INTERVAL_SEC)
