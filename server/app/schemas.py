from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


def to_camel(name: str) -> str:
    parts = name.split("_")
    return parts[0] + "".join(p.title() for p in parts[1:])


class CamelModel(BaseModel):
    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        from_attributes=True,
        extra="ignore",
    )


class TokenOut(CamelModel):
    token: str
    token_type: str = "bearer"


class OkOut(CamelModel):
    ok: bool = True
    message: str = ""


class SmsIn(CamelModel):
    phone: str


class AppLoginIn(CamelModel):
    phone: str
    password: str


class AppResetIn(CamelModel):
    phone: str
    code: str
    password: str


class AppRegisterIn(CamelModel):
    phone: str
    password: str
    code: str
    contact: str
    company_name: str
    province: str = ""
    city: str = ""
    district: str = ""
    address: str = ""
    wechat: str = ""
    backup_phone: str = ""
    id_no: str = ""
    license_name: str = ""
    remark: str = ""
    scale: str = "city"


class AppProfilePatch(CamelModel):
    nickname: str | None = None
    email: str | None = None
    gender: str | None = None
    avatar_id: str | None = None
    company_name: str | None = None


class AppUserOut(CamelModel):
    id: str
    nickname: str
    phone: str
    email: str = ""
    gender: str = "保密"
    avatar_id: str = "a1"
    company_name: str = ""
    audit_status: str
    reject_reason: str = ""
    deposit_amount: float = 5000
    deposit_paid: bool = False
    deposit_paid_at: str = ""
    contract_signed: bool = False
    contract_signed_at: str = ""
    contract_no: str = ""
    signer_name: str = ""
    can_place_order: bool = False
    agent_id: str | None = None


class ContractSignIn(CamelModel):
    signer_name: str


class DepositPayIn(CamelModel):
    channel: str = "alipay"


class MpLoginIn(CamelModel):
    phone: str
    code: str
    role: str


class MpApplyIn(CamelModel):
    name: str
    phone: str
    code: str
    contact: str
    province: str = ""
    city: str = ""
    district: str = ""
    address: str = ""
    wechat: str = ""
    backup_phone: str = ""
    id_no: str = ""
    license_name: str = ""
    remark: str = ""
    biz_types: list[str] = Field(default_factory=list)


class MpSessionOut(CamelModel):
    role: str
    display_name: str
    phone: str
    merchant_id: str | None = None
    audit_status: str | None = None
    reject_reason: str = ""


class AdminLoginIn(CamelModel):
    username: str
    password: str


class AdminMeOut(CamelModel):
    id: str
    username: str
    name: str
    role_id: str
    role_name: str = ""
    permissions: list[str] = Field(default_factory=list)


class OrderCreateIn(CamelModel):
    biz_type: str
    product_id: str = ""
    product_name: str
    carrier: str = ""
    customer_name: str
    customer_phone: str
    customer_id_no: str = ""
    address: str
    province: str = ""
    city: str = ""
    district: str = ""
    assigned_merchant_id: str = ""
    remark: str = ""
    stock_type_id: str = ""
    stock_type_name: str = ""
    order_intent: str = ""
    phone_brand: str = ""
    price_range: str = ""
    wifi_device_type: str = ""
    wifi_biz_mode: str = ""
    commission: float = 0


class FollowUpIn(CamelModel):
    reason: str
    next_at: str = ""
    note: str = ""


class DispatchIn(CamelModel):
    technician_id: str = ""
    technician_name: str = ""


class DeliverOkIn(CamelModel):
    photos: list[str] = Field(default_factory=list)


class DeliverFailIn(CamelModel):
    reason: str


class RemarkIn(CamelModel):
    remark: str = ""
    reason: str = ""


class TechIn(CamelModel):
    name: str
    phone: str
    province: str = ""
    city: str = ""
    district: str = ""
    skills: list[str] = Field(default_factory=list)
    status: str = "active"
    merchant_id: str = ""
    merchant_name: str = ""


class FeedbackIn(CamelModel):
    type: str = "其他"
    content: str
    contact: str = ""


class FeedbackHandleIn(CamelModel):
    reply: str = ""
    note: str = ""
    admin_note: str = ""


class CsMessageIn(CamelModel):
    content: str = ""
    msg_type: str = "text"


class RejectIn(CamelModel):
    reason: str


class ProductIn(CamelModel):
    name: str
    biz_type: str
    stock_type_id: str | None = None
    carrier: str = ""
    price_label: str = ""
    description: str = ""
    status: str = "active"
    province: str = ""
    city: str = ""
    commission: float = 0
    wifi_device_type: str = ""
    wifi_biz_mode: str = ""


class MerchantIn(CamelModel):
    name: str
    phone: str = ""
    login_phone: str
    province: str = ""
    city: str = ""
    district: str = ""
    address: str = ""
    status: str = "active"
    biz_types: list[str] = Field(default_factory=list)
    contact: str = ""
    mp_display_name: str = ""


class AgentIn(CamelModel):
    name: str
    phone: str
    contact: str = ""
    province: str = ""
    city: str = ""
    district: str = ""
    address: str = ""
    wechat: str = ""
    backup_phone: str = ""
    id_no: str = ""
    status: str = "active"
    remark: str = ""


class WarehouseIn(CamelModel):
    product_id: str = ""
    product_name: str
    sku: str = ""
    spec: str = ""
    stock: int = 0
    safety_stock: int = 0
    location: str = ""


class StockMoveIn(CamelModel):
    warehouse_id: str
    qty: int
    order_no: str = ""
    remark: str = ""


class StaffIn(CamelModel):
    username: str
    password: str = "123456"
    name: str
    role_id: str
    status: str = "active"


class StaffUpdateIn(CamelModel):
    username: str
    password: str = ""
    name: str
    role_id: str
    status: str = "active"


class RoleIn(CamelModel):
    name: str
    code: str
    permissions: list[str] = Field(default_factory=list)
    remark: str = ""
