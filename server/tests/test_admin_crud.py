from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path


DB_PATH = Path(tempfile.gettempdir()) / "paikebang_admin_crud_test.db"
if DB_PATH.exists():
    DB_PATH.unlink()
os.environ["DATABASE_URL"] = f"sqlite:///{DB_PATH.as_posix()}"
os.environ["REDIS_URL"] = "redis://127.0.0.1:1/0"
# 单测强制走本地 uploads，避免误连真实 OSS
os.environ["OSS_ACCESS_KEY_ID"] = ""
os.environ["OSS_ACCESS_KEY_SECRET"] = ""
os.environ["OSS_BUCKET"] = ""

from fastapi.testclient import TestClient  # noqa: E402

from app.db import engine  # noqa: E402
from app.main import app  # noqa: E402
from app.routers_uploads import UPLOAD_DIR  # noqa: E402


class AdminCrudTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.client = TestClient(app)
        login = cls.client.post("/api/admin/auth/login", json={"username": "admin", "password": "123456"})
        assert login.status_code == 200, login.text
        cls.headers = {"Authorization": f"Bearer {login.json()['token']}"}

    @classmethod
    def tearDownClass(cls) -> None:
        cls.client.close()
        engine.dispose()
        if DB_PATH.exists():
            DB_PATH.unlink()

    def test_role_and_staff_crud(self) -> None:
        role = self.client.post(
            "/api/admin/roles",
            headers=self.headers,
            json={"name": "测试运营", "code": "test_ops", "permissions": ["orders:view"], "remark": "test"},
        )
        self.assertEqual(role.status_code, 200, role.text)
        role_id = role.json()["id"]

        updated_role = self.client.put(
            f"/api/admin/roles/{role_id}",
            headers=self.headers,
            json={"name": "测试客服", "code": "test_ops", "permissions": ["service:view"], "remark": "updated"},
        )
        self.assertEqual(updated_role.status_code, 200, updated_role.text)
        self.assertEqual(updated_role.json()["name"], "测试客服")

        staff = self.client.post(
            "/api/admin/staff",
            headers=self.headers,
            json={"username": "crud_test", "password": "123456", "name": "测试账号", "roleId": role_id},
        )
        self.assertEqual(staff.status_code, 200, staff.text)
        staff_id = staff.json()["id"]

        updated_staff = self.client.put(
            f"/api/admin/staff/{staff_id}",
            headers=self.headers,
            json={"username": "crud_test", "password": "", "name": "已编辑账号", "roleId": role_id, "status": "active"},
        )
        self.assertEqual(updated_staff.status_code, 200, updated_staff.text)
        self.assertEqual(updated_staff.json()["name"], "已编辑账号")

        in_use = self.client.delete(f"/api/admin/roles/{role_id}", headers=self.headers)
        self.assertEqual(in_use.status_code, 400)
        self.assertEqual(self.client.delete(f"/api/admin/staff/{staff_id}", headers=self.headers).status_code, 200)
        self.assertEqual(self.client.delete(f"/api/admin/roles/{role_id}", headers=self.headers).status_code, 200)

    def test_warehouse_update_and_stock_type_delete(self) -> None:
        warehouse = self.client.post(
            "/api/admin/warehouse",
            headers=self.headers,
            json={
                "productId": "p1",
                "productName": "测试号卡",
                "sku": "CRUD-SKU",
                "spec": "实体卡",
                "stock": 5,
                "safetyStock": 2,
                "location": "测试仓",
            },
        )
        self.assertEqual(warehouse.status_code, 200, warehouse.text)
        wid = warehouse.json()["id"]
        stocked = self.client.post(
            "/api/admin/stock/in",
            headers=self.headers,
            json={"warehouseId": wid, "qty": 5, "remark": "测试入库"},
        )
        self.assertEqual(stocked.status_code, 200, stocked.text)
        negative = self.client.post(
            "/api/admin/stock/out",
            headers=self.headers,
            json={"warehouseId": wid, "qty": -1, "remark": "非法负数"},
        )
        self.assertEqual(negative.status_code, 400)
        updated = self.client.put(
            f"/api/admin/warehouse/{wid}",
            headers=self.headers,
            json={
                "productId": "p1",
                "productName": "测试号卡（新）",
                "sku": "CRUD-SKU",
                "spec": "实体卡",
                "stock": 999,
                "safetyStock": 3,
                "location": "新测试仓",
            },
        )
        self.assertEqual(updated.status_code, 200, updated.text)
        self.assertEqual(updated.json()["stock"], 5)
        self.assertEqual(updated.json()["location"], "新测试仓")

        stock_type = self.client.post(
            "/api/admin/stock-types",
            headers=self.headers,
            json={"name": "测试存量业务", "description": "test", "sort": 99},
        )
        self.assertEqual(stock_type.status_code, 200, stock_type.text)
        self.assertEqual(
            self.client.delete(f"/api/admin/stock-types/{stock_type.json()['id']}", headers=self.headers).status_code,
            200,
        )

    def test_order_values_and_mp_scope_are_server_enforced(self) -> None:
        app_login = self.client.post(
            "/api/app/auth/login", json={"phone": "13800138000", "password": "123456"}
        )
        self.assertEqual(app_login.status_code, 200, app_login.text)
        app_headers = {"Authorization": f"Bearer {app_login.json()['token']}"}
        created = self.client.post(
            "/api/app/orders",
            headers=app_headers,
            json={
                "bizType": "haoka",
                "productId": "p1",
                "productName": "被篡改的套餐名",
                "carrier": "被篡改的运营商",
                "customerName": "测试客户",
                "customerPhone": "13812345678",
                "address": "文三路 100 号",
                "province": "浙江省",
                "city": "杭州市",
                "district": "西湖区",
                "assignedMerchantId": "m1",
                "commission": 99999,
            },
        )
        self.assertEqual(created.status_code, 200, created.text)
        order = created.json()
        self.assertEqual(order["productName"], "电信畅享卡 59元")
        self.assertEqual(order["carrier"], "电信")
        self.assertEqual(order["commission"], 80)

        m1_login = self.client.post(
            "/api/mp/auth/login", json={"phone": "13800001001", "code": "123456", "role": "merchant"}
        )
        m2_login = self.client.post(
            "/api/mp/auth/login", json={"phone": "13800001002", "code": "123456", "role": "merchant"}
        )
        self.assertEqual(m1_login.status_code, 200, m1_login.text)
        self.assertEqual(m2_login.status_code, 200, m2_login.text)
        m1_headers = {"Authorization": f"Bearer {m1_login.json()['token']}"}
        m2_headers = {"Authorization": f"Bearer {m2_login.json()['token']}"}
        self.assertEqual(self.client.get(f"/api/mp/orders/{order['id']}", headers=m2_headers).status_code, 403)

        self.assertEqual(self.client.post(f"/api/mp/orders/{order['id']}/accept", headers=m1_headers).status_code, 200)
        self.assertEqual(
            self.client.post(f"/api/mp/orders/{order['id']}/needs-dispatch", headers=m1_headers).status_code,
            200,
        )
        cross_store_dispatch = self.client.post(
            f"/api/mp/orders/{order['id']}/dispatch",
            headers=m1_headers,
            json={"technicianId": "t2", "technicianName": "赵师傅"},
        )
        self.assertEqual(cross_store_dispatch.status_code, 400)

    def test_authenticated_image_upload_is_persistent(self) -> None:
        login = self.client.post(
            "/api/mp/auth/login", json={"phone": "13600001111", "code": "123456", "role": "technician"}
        )
        self.assertEqual(login.status_code, 200, login.text)
        headers = {"Authorization": f"Bearer {login.json()['token']}"}
        uploaded = self.client.post(
            "/api/uploads/images",
            headers=headers,
            files={"file": ("delivery.png", b"\x89PNG\r\n\x1a\nmock-image", "image/png")},
        )
        self.assertEqual(uploaded.status_code, 200, uploaded.text)
        body = uploaded.json()
        filename = body["name"]
        self.assertEqual(body.get("storage"), "local")
        self.assertTrue(body["url"].endswith(f"/api/uploads/file/{filename}"))
        target = UPLOAD_DIR / filename
        try:
            self.assertTrue(target.exists())
            self.assertEqual(self.client.get(f"/api/uploads/file/{filename}").status_code, 200)
            self.assertEqual(self.client.get(f"/uploads/{filename}").status_code, 200)
        finally:
            if target.exists():
                target.unlink()

    def test_apply_image_upload_accepts_octet_stream(self) -> None:
        uploaded = self.client.post(
            "/api/uploads/apply-images",
            files={"file": ("license.jpg", b"\x89PNG\r\n\x1a\nmock-image", "application/octet-stream")},
        )
        self.assertEqual(uploaded.status_code, 200, uploaded.text)
        filename = uploaded.json()["name"]
        self.assertTrue(filename.endswith(".png"))
        target = UPLOAD_DIR / filename
        try:
            self.assertTrue(target.exists())
            fetched = self.client.get(f"/api/uploads/file/{filename}")
            self.assertEqual(fetched.status_code, 200, fetched.text)
        finally:
            if target.exists():
                target.unlink()

    def test_wifi_cannot_complete_remote(self) -> None:
        login = self.client.post(
            "/api/mp/auth/login", json={"phone": "13800001001", "code": "123456", "role": "merchant"}
        )
        self.assertEqual(login.status_code, 200, login.text)
        headers = {"Authorization": f"Bearer {login.json()['token']}"}
        listed = self.client.get("/api/admin/orders", headers=self.headers)
        self.assertEqual(listed.status_code, 200, listed.text)
        wifi = next((o for o in listed.json()["items"] if o.get("bizType") == "wifi"), None)
        if wifi is None:
            self.skipTest("seed 中无 WIFI 订单")
        oid = wifi["id"]
        if wifi["status"] == "listed":
            accepted = self.client.post(f"/api/mp/orders/{oid}/accept", headers=headers)
            self.assertEqual(accepted.status_code, 200, accepted.text)
        remote = self.client.post(f"/api/mp/orders/{oid}/complete-remote", headers=headers)
        self.assertEqual(remote.status_code, 400, remote.text)


if __name__ == "__main__":
    unittest.main()
