from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path


DB_PATH = Path(tempfile.gettempdir()) / "paikebang_admin_spa_test.db"
if DB_PATH.exists():
    DB_PATH.unlink()
os.environ["DATABASE_URL"] = f"sqlite:///{DB_PATH.as_posix()}"
os.environ["REDIS_URL"] = "redis://127.0.0.1:1/0"

from fastapi.testclient import TestClient  # noqa: E402

from app.main import ADMIN_DIST, app  # noqa: E402


class AdminSpaTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.client = TestClient(app)

    def test_health_reports_admin_flag(self) -> None:
        res = self.client.get("/health?format=json")
        self.assertEqual(res.status_code, 200)
        body = res.json()
        self.assertTrue(body["ok"])
        self.assertEqual(body["admin"], (ADMIN_DIST / "index.html").is_file())
        self.assertIn("statusText", body)

    def test_api_not_stolen_by_spa(self) -> None:
        res = self.client.post("/api/admin/auth/login", json={"username": "admin", "password": "123456"})
        self.assertEqual(res.status_code, 200, res.text)

    def test_docs_still_available(self) -> None:
        res = self.client.get("/docs")
        self.assertEqual(res.status_code, 200)

    def test_spa_routes(self) -> None:
        index = ADMIN_DIST / "index.html"
        login = self.client.get("/login")
        root = self.client.get("/")
        if index.is_file():
            self.assertEqual(login.status_code, 200)
            self.assertIn("<div id=\"app\">", login.text)
            self.assertEqual(root.status_code, 200)
            self.assertIn("<div id=\"app\">", root.text)
            assets = list((ADMIN_DIST / "assets").glob("index-*.js"))
            if assets:
                js = self.client.get(f"/assets/{assets[0].name}")
                self.assertEqual(js.status_code, 200)
        else:
            self.assertEqual(login.status_code, 404)
            self.assertEqual(root.status_code, 404)


if __name__ == "__main__":
    unittest.main()
