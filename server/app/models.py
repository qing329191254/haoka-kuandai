from __future__ import annotations

from sqlalchemy import Boolean, Float, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class AppUser(Base):
    __tablename__ = "app_users"
    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    phone: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(200))
    nickname: Mapped[str] = mapped_column(String(80), default="")
    email: Mapped[str] = mapped_column(String(120), default="")
    gender: Mapped[str] = mapped_column(String(8), default="保密")
    avatar_id: Mapped[str] = mapped_column(String(255), default="a1")
    company_name: Mapped[str] = mapped_column(String(120), default="")
    status: Mapped[str] = mapped_column(String(16), default="active")
    agent_id: Mapped[str | None] = mapped_column(String(32), nullable=True)
    created_at: Mapped[str] = mapped_column(String(32))


class Agent(Base):
    __tablename__ = "agents"
    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    phone: Mapped[str] = mapped_column(String(20), index=True)
    contact: Mapped[str] = mapped_column(String(80), default="")
    province: Mapped[str] = mapped_column(String(40), default="")
    city: Mapped[str] = mapped_column(String(40), default="")
    district: Mapped[str] = mapped_column(String(40), default="")
    address: Mapped[str] = mapped_column(String(200), default="")
    wechat: Mapped[str] = mapped_column(String(80), default="")
    backup_phone: Mapped[str] = mapped_column(String(20), default="")
    id_no: Mapped[str] = mapped_column(String(32), default="")
    license_name: Mapped[str] = mapped_column(String(500), default="")
    joined_at: Mapped[str] = mapped_column(String(32))
    order_count: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[str] = mapped_column(String(16), default="active")
    remark: Mapped[str] = mapped_column(String(200), default="")


class AgentApplication(Base):
    __tablename__ = "agent_applications"
    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    phone: Mapped[str] = mapped_column(String(20), index=True)
    contact: Mapped[str] = mapped_column(String(80), default="")
    name: Mapped[str] = mapped_column(String(120), default="")
    province: Mapped[str] = mapped_column(String(40), default="")
    city: Mapped[str] = mapped_column(String(40), default="")
    district: Mapped[str] = mapped_column(String(40), default="")
    address: Mapped[str] = mapped_column(String(200), default="")
    wechat: Mapped[str] = mapped_column(String(80), default="")
    backup_phone: Mapped[str] = mapped_column(String(20), default="")
    id_no: Mapped[str] = mapped_column(String(32), default="")
    license_name: Mapped[str] = mapped_column(String(500), default="")
    remark: Mapped[str] = mapped_column(String(200), default="")
    status: Mapped[str] = mapped_column(String(16), default="pending")
    reject_reason: Mapped[str] = mapped_column(String(200), default="")
    created_at: Mapped[str] = mapped_column(String(32))
    reviewed_at: Mapped[str | None] = mapped_column(String(32), nullable=True)
    agent_id: Mapped[str | None] = mapped_column(String(32), nullable=True)
    deposit_amount: Mapped[float] = mapped_column(Float, default=5000)
    deposit_paid: Mapped[bool] = mapped_column(Boolean, default=False)
    deposit_paid_at: Mapped[str | None] = mapped_column(String(32), nullable=True)
    deposit_out_trade_no: Mapped[str] = mapped_column(String(64), default="")
    deposit_trade_no: Mapped[str] = mapped_column(String(64), default="")
    deposit_channel: Mapped[str] = mapped_column(String(16), default="")
    scale: Mapped[str] = mapped_column(String(16), default="city")
    contract_signed: Mapped[bool] = mapped_column(Boolean, default=False)
    contract_signed_at: Mapped[str | None] = mapped_column(String(32), nullable=True)
    contract_no: Mapped[str] = mapped_column(String(40), default="")
    signer_name: Mapped[str] = mapped_column(String(80), default="")


class Merchant(Base):
    __tablename__ = "merchants"
    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    phone: Mapped[str] = mapped_column(String(20), default="")
    login_phone: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    province: Mapped[str] = mapped_column(String(40), default="")
    city: Mapped[str] = mapped_column(String(40), default="")
    district: Mapped[str] = mapped_column(String(40), default="")
    address: Mapped[str] = mapped_column(String(200), default="")
    status: Mapped[str] = mapped_column(String(16), default="active")
    biz_types: Mapped[str] = mapped_column(Text, default="[]")
    contact: Mapped[str] = mapped_column(String(80), default="")
    mp_display_name: Mapped[str] = mapped_column(String(120), default="")


class MerchantApplication(Base):
    __tablename__ = "merchant_applications"
    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    name: Mapped[str] = mapped_column(String(120), default="")
    phone: Mapped[str] = mapped_column(String(20), index=True)
    contact: Mapped[str] = mapped_column(String(80), default="")
    province: Mapped[str] = mapped_column(String(40), default="")
    city: Mapped[str] = mapped_column(String(40), default="")
    district: Mapped[str] = mapped_column(String(40), default="")
    address: Mapped[str] = mapped_column(String(200), default="")
    wechat: Mapped[str] = mapped_column(String(80), default="")
    backup_phone: Mapped[str] = mapped_column(String(20), default="")
    id_no: Mapped[str] = mapped_column(String(32), default="")
    license_name: Mapped[str] = mapped_column(String(500), default="")
    remark: Mapped[str] = mapped_column(String(200), default="")
    biz_types: Mapped[str] = mapped_column(Text, default="[]")
    status: Mapped[str] = mapped_column(String(16), default="pending")
    reject_reason: Mapped[str] = mapped_column(String(200), default="")
    created_at: Mapped[str] = mapped_column(String(32))
    reviewed_at: Mapped[str | None] = mapped_column(String(32), nullable=True)
    merchant_id: Mapped[str | None] = mapped_column(String(32), nullable=True)


class Technician(Base):
    __tablename__ = "technicians"
    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    name: Mapped[str] = mapped_column(String(80))
    phone: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    province: Mapped[str] = mapped_column(String(40), default="")
    city: Mapped[str] = mapped_column(String(40), default="")
    district: Mapped[str] = mapped_column(String(40), default="")
    status: Mapped[str] = mapped_column(String(16), default="active")
    merchant_id: Mapped[str] = mapped_column(String(32), index=True)
    merchant_name: Mapped[str] = mapped_column(String(120), default="")
    skills: Mapped[str] = mapped_column(Text, default="[]")


class Product(Base):
    __tablename__ = "products"
    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    biz_type: Mapped[str] = mapped_column(String(32), index=True)
    stock_type_id: Mapped[str | None] = mapped_column(String(32), nullable=True)
    carrier: Mapped[str] = mapped_column(String(40), default="")
    price_label: Mapped[str] = mapped_column(String(40), default="")
    description: Mapped[str] = mapped_column(String(400), default="")
    status: Mapped[str] = mapped_column(String(16), default="active")
    province: Mapped[str] = mapped_column(String(40), default="")
    city: Mapped[str] = mapped_column(String(40), default="")
    commission: Mapped[float] = mapped_column(Float, default=0)
    wifi_device_type: Mapped[str] = mapped_column(String(16), default="")
    wifi_biz_mode: Mapped[str] = mapped_column(String(16), default="")


class StockBizType(Base):
    __tablename__ = "stock_biz_types"
    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    name: Mapped[str] = mapped_column(String(80))
    description: Mapped[str] = mapped_column(String(200), default="")
    status: Mapped[str] = mapped_column(String(16), default="active")
    sort: Mapped[int] = mapped_column(Integer, default=0)


class Order(Base):
    __tablename__ = "orders"
    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    order_no: Mapped[str] = mapped_column(String(40), unique=True, index=True)
    biz_type: Mapped[str] = mapped_column(String(32), index=True)
    status: Mapped[str] = mapped_column(String(32), index=True)
    customer_name: Mapped[str] = mapped_column(String(80), default="")
    customer_phone: Mapped[str] = mapped_column(String(20), default="")
    customer_id_no: Mapped[str] = mapped_column(String(32), default="")
    address: Mapped[str] = mapped_column(String(300), default="")
    product_id: Mapped[str] = mapped_column(String(32), default="")
    product_name: Mapped[str] = mapped_column(String(120), default="")
    carrier: Mapped[str] = mapped_column(String(40), default="")
    need_new_card: Mapped[bool] = mapped_column(Boolean, default=False)
    assigned_merchant_id: Mapped[str | None] = mapped_column(String(32), nullable=True, index=True)
    assigned_merchant_name: Mapped[str] = mapped_column(String(120), default="")
    merchant_name: Mapped[str] = mapped_column(String(120), default="")
    technician_id: Mapped[str | None] = mapped_column(String(32), nullable=True)
    technician_name: Mapped[str] = mapped_column(String(80), default="")
    created_at: Mapped[str] = mapped_column(String(32))
    updated_at: Mapped[str] = mapped_column(String(32))
    remark: Mapped[str] = mapped_column(String(400), default="")
    source: Mapped[str] = mapped_column(String(16), default="app")
    region: Mapped[str] = mapped_column(String(80), default="")
    province: Mapped[str] = mapped_column(String(40), default="")
    city: Mapped[str] = mapped_column(String(40), default="")
    district: Mapped[str] = mapped_column(String(40), default="")
    commission: Mapped[float] = mapped_column(Float, default=0)
    stock_type_id: Mapped[str] = mapped_column(String(32), default="")
    stock_type_name: Mapped[str] = mapped_column(String(80), default="")
    fail_reason: Mapped[str] = mapped_column(String(400), default="")
    needs_dispatch: Mapped[bool] = mapped_column(Boolean, default=False)
    follow_up_reason: Mapped[str] = mapped_column(String(400), default="")
    next_follow_up_at: Mapped[str] = mapped_column(String(32), default="")
    follow_up_logs: Mapped[str] = mapped_column(Text, default="[]")
    delivery_photos: Mapped[str] = mapped_column(Text, default="[]")
    logs: Mapped[str] = mapped_column(Text, default="[]")
    order_intent: Mapped[str] = mapped_column(String(40), default="")
    phone_brand: Mapped[str] = mapped_column(String(40), default="")
    price_range: Mapped[str] = mapped_column(String(40), default="")
    wifi_device_type: Mapped[str] = mapped_column(String(16), default="")
    wifi_biz_mode: Mapped[str] = mapped_column(String(16), default="")
    agent_id: Mapped[str | None] = mapped_column(String(32), nullable=True, index=True)
    created_by_user_id: Mapped[str | None] = mapped_column(String(32), nullable=True)


class Feedback(Base):
    __tablename__ = "feedbacks"
    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    type: Mapped[str] = mapped_column(String(32), default="其他")
    content: Mapped[str] = mapped_column(Text, default="")
    contact: Mapped[str] = mapped_column(String(80), default="")
    user_name: Mapped[str] = mapped_column(String(80), default="")
    user_id: Mapped[str] = mapped_column(String(32), default="", index=True)
    # app_feedback=意见反馈（在线客服走 cs_conversations / cs_messages）
    channel: Mapped[str] = mapped_column(String(32), default="app_feedback", index=True)
    created_at: Mapped[str] = mapped_column(String(32))
    status: Mapped[str] = mapped_column(String(16), default="pending")
    reply: Mapped[str] = mapped_column(Text, default="")
    admin_note: Mapped[str] = mapped_column(Text, default="")
    handled_at: Mapped[str] = mapped_column(String(32), default="")
    handled_by: Mapped[str] = mapped_column(String(80), default="")


class CsConversation(Base):
    """App 在线客服会话：每用户一条（可 reopen）。"""

    __tablename__ = "cs_conversations"
    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(32), index=True)
    user_name: Mapped[str] = mapped_column(String(80), default="")
    user_phone: Mapped[str] = mapped_column(String(20), default="")
    status: Mapped[str] = mapped_column(String(16), default="open", index=True)  # open | closed
    last_message: Mapped[str] = mapped_column(String(200), default="")
    last_message_at: Mapped[str] = mapped_column(String(32), default="", index=True)
    user_unread: Mapped[int] = mapped_column(Integer, default=0)
    agent_unread: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[str] = mapped_column(String(32))
    updated_at: Mapped[str] = mapped_column(String(32), default="")


class CsMessage(Base):
    __tablename__ = "cs_messages"
    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    conversation_id: Mapped[str] = mapped_column(String(32), index=True)
    # user | agent | system
    sender_type: Mapped[str] = mapped_column(String(16), default="user", index=True)
    agent_id: Mapped[str] = mapped_column(String(32), default="")
    agent_name: Mapped[str] = mapped_column(String(80), default="")
    # text | image
    msg_type: Mapped[str] = mapped_column(String(16), default="text")
    content: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[str] = mapped_column(String(32), index=True)


class Faq(Base):
    __tablename__ = "faqs"
    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    category: Mapped[str] = mapped_column(String(32), default="订单")
    question: Mapped[str] = mapped_column(String(200))
    answer: Mapped[str] = mapped_column(Text, default="")
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    sort: Mapped[int] = mapped_column(Integer, default=0)


class ContentDoc(Base):
    __tablename__ = "content_docs"
    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    title: Mapped[str] = mapped_column(String(80))
    updated_at: Mapped[str] = mapped_column(String(32))
    sections: Mapped[str] = mapped_column(Text, default="[]")


class ServiceConfig(Base):
    __tablename__ = "service_config"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    hotline: Mapped[str] = mapped_column(String(40), default="")
    work_time: Mapped[str] = mapped_column(String(80), default="")
    quick_replies: Mapped[str] = mapped_column(Text, default="[]")


class AppVersionConfig(Base):
    """App 检查更新配置（不对接应用商店 SDK，仅下发版本与下载/商店链接）。"""
    __tablename__ = "app_version_config"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    latest_version: Mapped[str] = mapped_column(String(32), default="1.0.0")
    min_supported_version: Mapped[str] = mapped_column(String(32), default="1.0.0")
    force_update: Mapped[bool] = mapped_column(Boolean, default=False)
    title: Mapped[str] = mapped_column(String(80), default="发现新版本")
    release_notes: Mapped[str] = mapped_column(Text, default="")
    android_url: Mapped[str] = mapped_column(String(500), default="")
    ios_url: Mapped[str] = mapped_column(String(500), default="")
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)


class WarehouseItem(Base):
    __tablename__ = "warehouse"
    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    product_id: Mapped[str] = mapped_column(String(32), default="")
    product_name: Mapped[str] = mapped_column(String(120), default="")
    sku: Mapped[str] = mapped_column(String(40), default="")
    spec: Mapped[str] = mapped_column(String(80), default="")
    stock: Mapped[int] = mapped_column(Integer, default=0)
    safety_stock: Mapped[int] = mapped_column(Integer, default=0)
    location: Mapped[str] = mapped_column(String(80), default="")
    updated_at: Mapped[str] = mapped_column(String(32))


class StockRecord(Base):
    __tablename__ = "stock_records"
    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    type: Mapped[str] = mapped_column(String(8))
    warehouse_id: Mapped[str] = mapped_column(String(32), default="")
    product_id: Mapped[str] = mapped_column(String(32), default="")
    product_name: Mapped[str] = mapped_column(String(120), default="")
    sku: Mapped[str] = mapped_column(String(40), default="")
    qty: Mapped[int] = mapped_column(Integer, default=0)
    order_no: Mapped[str] = mapped_column(String(40), default="")
    operator: Mapped[str] = mapped_column(String(80), default="")
    remark: Mapped[str] = mapped_column(String(200), default="")
    created_at: Mapped[str] = mapped_column(String(32))


class Staff(Base):
    __tablename__ = "staff"
    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    username: Mapped[str] = mapped_column(String(40), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(200))
    name: Mapped[str] = mapped_column(String(80), default="")
    role_id: Mapped[str] = mapped_column(String(32), default="")
    status: Mapped[str] = mapped_column(String(16), default="active")
    created_at: Mapped[str] = mapped_column(String(32))


class DepositRule(Base):
    """押金规则：匹配城市 + 合作规模 → 应缴金额。

    province/city 为空表示更广的兜底（全国 / 全省）。
    """

    __tablename__ = "deposit_rules"
    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    province: Mapped[str] = mapped_column(String(40), default="")
    city: Mapped[str] = mapped_column(String(40), default="")
    scale: Mapped[str] = mapped_column(String(16), default="city")
    amount: Mapped[float] = mapped_column(Float, default=5000)
    remark: Mapped[str] = mapped_column(String(200), default="")
    status: Mapped[str] = mapped_column(String(16), default="active")


class Role(Base):
    __tablename__ = "roles"
    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    name: Mapped[str] = mapped_column(String(40))
    code: Mapped[str] = mapped_column(String(40), unique=True)
    builtin: Mapped[bool] = mapped_column(Boolean, default=False)
    permissions: Mapped[str] = mapped_column(Text, default="[]")
    remark: Mapped[str] = mapped_column(String(200), default="")
