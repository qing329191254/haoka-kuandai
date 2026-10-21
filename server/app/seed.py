from __future__ import annotations

from sqlalchemy.orm import Session

from app.config import settings
from app.models import (
    Agent,
    AgentApplication,
    AppUser,
    AppVersionConfig,
    ContentDoc,
    DepositRule,
    Faq,
    Feedback,
    Merchant,
    MerchantApplication,
    Order,
    Product,
    Role,
    ServiceConfig,
    Staff,
    StockBizType,
    Technician,
    WarehouseItem,
)
from app.security import hash_password
from app.services import append_log
from app.util import dump_json, now_str

PWD = None  # filled at runtime so hash is stable per process but unique salt each seed


def _pwd() -> str:
    global PWD
    if PWD is None:
        PWD = hash_password("123456")
    return PWD


ALL_BIZ = [
    "haoka",
    "contract_phone",
    "broadband_naked",
    "broadband_new_card",
    "broadband_no_card",
    "wifi",
    "cpe",
    "stock",
]


def _migrate_brand_name(db: Session) -> None:
    changed = False
    for doc in db.query(ContentDoc).all():
        title = (doc.title or "").replace("星链云", "派客邦")
        sections = (doc.sections or "").replace("星链云", "派客邦")
        if title != doc.title or sections != doc.sections:
            doc.title = title
            doc.sections = sections
            changed = True
    if changed:
        db.commit()


def _default_doc_sections() -> dict[str, list[dict[str, str]]]:
    return {
        "agreement": [
            {
                "heading": "一、服务说明",
                "body": "欢迎使用派客邦。本协议约定您与平台之间就号卡、宽带等业务信息撮合与订单服务的权利义务。请在使用前仔细阅读。",
            },
            {
                "heading": "二、账号与订单",
                "body": "您应保证提交的身份与联系信息真实有效。号卡、宽带业务由合作商家及运营商流程完成，平台提供信息撮合与进度展示。",
            },
            {
                "heading": "三、使用规范",
                "body": "不得利用本应用从事违法违规活动，不得干扰系统正常运行。平台有权对违规账号采取限制措施。",
            },
            {
                "heading": "四、免责声明",
                "body": "因运营商系统、不可抗力或第三方原因导致的开通延误，平台将协助沟通，但不承担由此产生的间接损失。",
            },
        ],
        "privacy": [
            {
                "heading": "一、我们收集的信息",
                "body": "为完成登录与下单，可能收集手机号、姓名、装机地址、订单信息等，仅用于业务办理与服务保障。",
            },
            {
                "heading": "二、信息使用目的",
                "body": "用于身份验证、订单履约、客服沟通、服务改进与安全保障。不会将个人信息出售给无关第三方。",
            },
            {
                "heading": "三、信息共享",
                "body": "为实现开户与装机，必要信息可能与合作商家、运营商工单系统共享，并仅限业务所需范围。",
            },
            {
                "heading": "四、您的权利",
                "body": "您可查询、更正个人信息，也可通过客服申请注销账号。我们将在核实后依法处理您的请求。",
            },
        ],
        "help": [
            {
                "heading": "入驻流程",
                "body": "申请入驻 → 电子签 → 缴押金 → 审核通过后即可提交号卡 / 宽带转手订单。",
            },
            {
                "heading": "如何办理号卡？",
                "body": "登录后进入首页，选择「号卡」，先挑选产品，再填写采购方姓名、手机号、所在地和详细地址后提交。商家接单后会安排师傅上门开户激活。",
            },
            {
                "heading": "宽带为什么要区分是否新开卡？",
                "body": "需新开卡：师傅上门时先开户再装机。无需开卡：商家先完成开户，再安排装机师傅上门。",
            },
            {
                "heading": "如何联系客服？",
                "body": "打开底部「客服」，可与人工客服在线沟通；紧急情况可通过客服热线联系我们。",
            },
            {
                "heading": "个人信息如何修改？",
                "body": "进入「我的」点击头像，可修改昵称、性别、邮箱，并更换头像。登录手机号如需变更，请联系客服协助处理。",
            },
        ],
        "contract": [
            {
                "heading": "一、合作内容",
                "body": "甲方（平台）为乙方（代理）提供号卡 / 宽带业务转手协同能力。乙方在站外渠道获客后，可通过本系统录入订单并指定本地商家履约。",
            },
            {
                "heading": "二、保证金",
                "body": "乙方须缴纳入驻保证金。保证金在合作期内由甲方留存，用于履约保障、客诉赔付等；解约且无未结纠纷时，乙方可申请退还。具体金额以入驻流程展示为准。",
            },
            {
                "heading": "三、商品上架",
                "body": "号卡等商品由甲方运营在后台代为配置上架，乙方无需自行上架。",
            },
            {
                "heading": "四、电子签效力",
                "body": "乙方在本页确认签署，即视为同意本协议全部条款。正式环境将对接电子签章服务。",
            },
            {
                "heading": "五、其他",
                "body": "未尽事宜以双方补充协议及平台规则为准。",
            },
        ],
    }


def _default_faqs() -> list[tuple[str, str, str, str, int]]:
    return [
        ("f1", "入驻", "代理入驻要经过哪些步骤？", "提交入驻申请 → 签署电子合同 → 缴纳合作押金 → 等待运营审核。通过后即可提交号卡 / 宽带转手订单。", 1),
        ("f2", "入驻", "入驻审核大概多久？", "一般 1–2 个工作日。超时可在客服页在线催审。", 2),
        ("f3", "入驻", "入驻被驳回怎么办？", "请根据驳回原因完善资料后重新申请。不清楚原因时可在客服页咨询，运营会协助说明。", 3),
        ("f4", "号卡", "号卡如何办理？", "在 App 选择套餐并填写收货人信息提交即可。商家接单后会安排师傅上门开户激活。", 4),
        ("f5", "号卡", "号卡下单后多久能上门？", "商家接单派单后，师傅一般 24–48 小时内联系预约开户激活。", 5),
        ("f6", "宽带", "宽带需要新开卡和不用开卡有什么区别？", "需新开卡：师傅上门时先开户再装机。无需开卡：商家先开户，再安排装机师傅上门。", 6),
        ("f7", "宽带", "宽带装机大概需要多久？", "开户完成后通常 1–3 个工作日上门，以当地运营商排期为准。", 7),
        ("f8", "订单", "如何查看订单进度？", "打开底部「订单」，可按待接单、进行中、已完成等状态查看办理进度。", 8),
        ("f9", "订单", "可以取消订单吗？", "商家未接单前可联系客服取消；已派单或已开户需与商家协商。", 9),
        ("f10", "订单", "为什么一直待接单？", "可能暂无覆盖商家，请把订单号发给客服协助转派。", 10),
        ("f11", "订单", "如何修改上门地址？", "商家未接单前可通过在线客服协助修改；已派单请与商家或上门师傅协商改约。", 11),
        ("f12", "账号", "如何修改个人信息？", "进入「我的」点击头像可修改昵称、性别、邮箱与头像。手机号变更请联系客服。", 12),
    ]


def _default_quick_replies() -> list[dict[str, str]]:
    return [
        {"prompt": "入驻进度", "reply": "请在入驻状态页查看合同与押金审核结果；也可在线咨询催审。"},
        {"prompt": "催一下审核", "reply": "已记录催审需求，运营会尽快处理。"},
        {"prompt": "订单进度查询", "reply": "请补充订单号，我们协助查询办理状态。"},
        {"prompt": "取消订单", "reply": "请补充订单号与取消原因，我们核对后协助处理。"},
        {"prompt": "修改上门地址", "reply": "请补充订单号与新地址，未派单前可协助修改。"},
        {"prompt": "号卡套餐咨询", "reply": "请补充所在城市和想了解的套餐。"},
        {"prompt": "宽带装机时效", "reply": "开户完成后一般 1–3 个工作日上门，以当地排期为准。"},
    ]


def _demo_stock_types() -> list[dict]:
    return [
        {"id": "st1", "name": "宽带续费", "description": "存量宽带到期续约、缴费", "status": "active", "sort": 1},
        {"id": "st2", "name": "套餐升档", "description": "存量用户套餐升级、叠加包", "status": "active", "sort": 2},
        {"id": "st3", "name": "IPTV / 电视增值", "description": "电视、增值业务加装", "status": "active", "sort": 3},
    ]


def _demo_products() -> list[dict]:
    return [
        {"id": "p1", "name": "电信畅享卡 59元", "biz_type": "haoka", "carrier": "电信", "price_label": "59元/月", "description": "通话 + 流量均衡，适合日常办公", "province": "浙江省", "city": "杭州市", "commission": 80},
        {"id": "p1-nj", "name": "电信畅享卡 59元", "biz_type": "haoka", "carrier": "电信", "price_label": "59元/月", "description": "同款号卡，南京地区上架", "province": "江苏省", "city": "南京市", "commission": 60},
        {"id": "p2", "name": "移动花卡 19元", "biz_type": "haoka", "carrier": "移动", "price_label": "19元/月", "description": "低月租入门号卡", "province": "浙江省", "city": "杭州市", "commission": 35},
        {"id": "p2-gz", "name": "移动花卡 19元", "biz_type": "haoka", "carrier": "移动", "price_label": "19元/月", "description": "广州地区低月租号卡", "province": "广东省", "city": "广州市", "commission": 30},
        {"id": "p3", "name": "联通大王卡 39元", "biz_type": "haoka", "carrier": "联通", "price_label": "39元/月", "description": "大流量上网卡", "province": "浙江省", "city": "杭州市", "commission": 50},
        {"id": "p-cp1", "name": "合约机 128G", "biz_type": "contract_phone", "carrier": "电信", "price_label": "合约 24 期", "description": "购机送话费，合约机业务", "province": "浙江省", "city": "杭州市", "commission": 150},
        {"id": "p-kd-naked", "name": "电信裸宽 300M", "biz_type": "broadband_naked", "carrier": "电信", "price_label": "79元/月", "description": "单宽安装，无需新开卡", "province": "浙江省", "city": "杭州市", "commission": 90},
        {"id": "p-kd1", "name": "电信融合宽带 300M", "biz_type": "broadband_new_card", "carrier": "电信", "price_label": "99元/月", "description": "融合新开卡 + 装机", "province": "浙江省", "city": "杭州市", "commission": 120},
        {"id": "p-kd-nocard", "name": "移动宽带 500M（已有卡）", "biz_type": "broadband_no_card", "carrier": "移动", "price_label": "89元/月", "description": "已有手机卡，仅装宽带", "province": "浙江省", "city": "杭州市", "commission": 100},
        {"id": "p-wifi-4g", "name": "4G 随身 WIFI（买断）", "biz_type": "wifi", "carrier": "移动", "price_label": "299元", "description": "即插即用随身热点", "province": "浙江省", "city": "杭州市", "commission": 45, "wifi_device_type": "4G", "wifi_biz_mode": "买断"},
        {"id": "p-wifi-5g", "name": "5G 随身 WIFI（租赁）", "biz_type": "wifi", "carrier": "电信", "price_label": "39元/月", "description": "按月租赁，可随时退租", "province": "浙江省", "city": "杭州市", "commission": 28, "wifi_device_type": "5G", "wifi_biz_mode": "租赁"},
        {"id": "p-cpe", "name": "5G CPE 室内路由", "biz_type": "cpe", "carrier": "联通", "price_label": "399元", "description": "室内 5G 转 Wi‑Fi 设备", "province": "浙江省", "city": "杭州市", "commission": 70},
        {"id": "p-st1", "name": "宽带续费 12个月", "biz_type": "stock", "stock_type_id": "st1", "carrier": "电信", "price_label": "960元/年", "description": "存量宽带续费", "province": "浙江省", "city": "杭州市", "commission": 40},
        {"id": "p-st2", "name": "套餐升档 至 99 档", "biz_type": "stock", "stock_type_id": "st2", "carrier": "移动", "price_label": "升档差价", "description": "存量用户套餐升档", "province": "浙江省", "city": "杭州市", "commission": 55},
        {"id": "p-st3", "name": "IPTV 电视增值", "biz_type": "stock", "stock_type_id": "st3", "carrier": "电信", "price_label": "20元/月", "description": "电视增值加装", "province": "江苏省", "city": "南京市", "commission": 25},
    ]


def _demo_merchants() -> list[dict]:
    return [
        {
            "id": "m1",
            "name": "西湖号卡店",
            "phone": "0571-88880001",
            "login_phone": "13800001001",
            "province": "浙江省",
            "city": "杭州市",
            "district": "西湖区",
            "address": "文三路100号",
            "biz_types": ALL_BIZ,
            "contact": "陈经理",
            "mp_display_name": "西湖号卡店",
        },
        {
            "id": "m2",
            "name": "滨江宽带专营",
            "phone": "0571-88880002",
            "login_phone": "13800001002",
            "province": "浙江省",
            "city": "杭州市",
            "district": "滨江区",
            "address": "网商路999号",
            "biz_types": ["contract_phone", "broadband_naked", "broadband_new_card", "broadband_no_card", "wifi", "cpe", "stock"],
            "contact": "周经理",
            "mp_display_name": "滨江宽带专营",
        },
        {
            "id": "m3",
            "name": "南京鼓楼号卡",
            "phone": "025-88880003",
            "login_phone": "13800001003",
            "province": "江苏省",
            "city": "南京市",
            "district": "鼓楼区",
            "address": "中山路188号",
            "biz_types": ["haoka", "contract_phone", "wifi", "stock"],
            "contact": "王经理",
            "mp_display_name": "南京鼓楼号卡",
        },
        {
            "id": "m4",
            "name": "广州天河宽带",
            "phone": "020-88880004",
            "login_phone": "13800001004",
            "province": "广东省",
            "city": "广州市",
            "district": "天河区",
            "address": "天河路100号",
            "biz_types": ["haoka", "broadband_naked", "broadband_new_card", "broadband_no_card", "cpe"],
            "contact": "林经理",
            "mp_display_name": "广州天河宽带",
        },
        {
            "id": "m5",
            "name": "苏州工业园号卡",
            "phone": "0512-88880005",
            "login_phone": "13800001005",
            "province": "江苏省",
            "city": "苏州市",
            "district": "工业园区",
            "address": "星湖街328号",
            "biz_types": ALL_BIZ,
            "contact": "沈经理",
            "mp_display_name": "苏州工业园号卡",
        },
    ]


def _ensure_rich_content(db: Session) -> None:
    """已有库补齐演示内容：文档 / FAQ / 热线 / 套餐 / 商家。"""
    from app.util import load_json

    changed = False
    titles = {
        "agreement": "用户协议",
        "privacy": "隐私政策",
        "help": "帮助中心",
        "contract": "派客邦代理合作协议",
    }
    defaults = _default_doc_sections()
    for doc_id, sections in defaults.items():
        doc = db.get(ContentDoc, doc_id)
        if not doc:
            db.add(
                ContentDoc(
                    id=doc_id,
                    title=titles.get(doc_id, doc_id),
                    updated_at=now_str(),
                    sections=dump_json(sections),
                )
            )
            changed = True
            continue
        current = load_json(doc.sections) or []
        known = {str(s.get("heading", "")) for s in current if isinstance(s, dict)}
        merged = list(current)
        for sec in sections:
            if sec["heading"] not in known:
                merged.append(sec)
        if len(merged) != len(current):
            doc.sections = dump_json(merged)
            doc.updated_at = now_str()
            changed = True

    existing_q = {f.question for f in db.query(Faq).all()}
    for fid, cat, q, a, sort in _default_faqs():
        if q in existing_q:
            continue
        if db.get(Faq, fid):
            continue
        db.add(Faq(id=fid, category=cat, question=q, answer=a, enabled=True, sort=sort))
        changed = True

    cfg = db.get(ServiceConfig, 1)
    if not cfg:
        db.add(
            ServiceConfig(
                id=1,
                hotline="400-800-1234",
                work_time="工作日 09:00-18:00",
                quick_replies=dump_json(_default_quick_replies()),
            )
        )
        changed = True
    else:
        if not (cfg.hotline or "").strip():
            cfg.hotline = "400-800-1234"
            changed = True
        if not (cfg.work_time or "").strip():
            cfg.work_time = "工作日 09:00-18:00"
            changed = True
        replies = load_json(cfg.quick_replies) or []
        known = {str(r.get("prompt", "")) for r in replies if isinstance(r, dict)}
        added = False
        for item in _default_quick_replies():
            if item["prompt"] not in known:
                replies.append(item)
                added = True
        if added:
            cfg.quick_replies = dump_json(replies)
            changed = True

    for row in _demo_stock_types():
        if db.get(StockBizType, row["id"]):
            continue
        db.add(StockBizType(**row))
        changed = True

    for row in _demo_products():
        if db.get(Product, row["id"]):
            continue
        db.add(
            Product(
                id=row["id"],
                name=row["name"],
                biz_type=row["biz_type"],
                stock_type_id=row.get("stock_type_id"),
                carrier=row["carrier"],
                price_label=row["price_label"],
                description=row["description"],
                status="active",
                province=row["province"],
                city=row["city"],
                commission=row["commission"],
                wifi_device_type=row.get("wifi_device_type", ""),
                wifi_biz_mode=row.get("wifi_biz_mode", ""),
            )
        )
        changed = True

    for row in _demo_merchants():
        if db.get(Merchant, row["id"]):
            continue
        db.add(
            Merchant(
                id=row["id"],
                name=row["name"],
                phone=row["phone"],
                login_phone=row["login_phone"],
                province=row["province"],
                city=row["city"],
                district=row["district"],
                address=row["address"],
                status="active",
                biz_types=dump_json(row["biz_types"]),
                contact=row["contact"],
                mp_display_name=row["mp_display_name"],
            )
        )
        changed = True

    if db.query(Feedback).count() == 0:
        t = now_str()
        db.add_all(
            [
                Feedback(
                    id="fb-demo1",
                    type="入驻咨询",
                    content="想确认一下入驻审核大概还要多久？公司已交押金并完成电子签。",
                    contact="13800138000",
                    user_name="张代理",
                    user_id="u1",
                    channel="app_feedback",
                    created_at=t,
                    status="handled",
                    reply="您好，资料已齐全，预计今日内完成审核，请留意状态页。",
                    admin_note="演示已回复",
                    handled_at=t,
                    handled_by="客服小李",
                ),
                Feedback(
                    id="fb-demo2",
                    type="订单相关",
                    content="订单号 HK20260820001 一直待接单，请帮忙看下。",
                    contact="13800138000",
                    user_name="张代理",
                    user_id="u1",
                    channel="app_feedback",
                    created_at=t,
                    status="pending",
                    reply="",
                    admin_note="",
                    handled_at="",
                    handled_by="",
                ),
            ]
        )
        changed = True

    ver = db.get(AppVersionConfig, 1)
    if not ver:
        db.add(
            AppVersionConfig(
                id=1,
                latest_version="1.0.0",
                min_supported_version="1.0.0",
                force_update=False,
                title="发现新版本",
                release_notes="修复已知问题，提升稳定性。",
                android_url="",
                ios_url="",
                enabled=True,
            )
        )
        changed = True

    if changed:
        db.commit()


def _ensure_service_role_perms(db: Session) -> None:
    role = db.get(Role, "r-service")
    if not role:
        return
    from app.util import load_json

    needed = [
        "service:view",
        "service:edit",
        "feedback:view",
        "feedback:edit",
        "content:view",
        "orders:edit",
        "users:view",
    ]
    perms = load_json(role.permissions) or []
    if not isinstance(perms, list):
        return
    if "*" in perms:
        return
    changed = False
    for p in needed:
        if p not in perms:
            perms.append(p)
            changed = True
    if changed:
        role.permissions = dump_json(perms)
        role.remark = "在线客服、FAQ 配置与订单协助"
        db.commit()


def _ensure_deposit_rules(db: Session) -> None:
    if db.query(DepositRule).first():
        return
    db.add_all(
        [
            DepositRule(id="dr-nat-county", province="", city="", scale="county", amount=3000, remark="全国区县级默认", status="active"),
            DepositRule(id="dr-nat-city", province="", city="", scale="city", amount=5000, remark="全国地市级默认", status="active"),
            DepositRule(id="dr-nat-province", province="", city="", scale="province", amount=10000, remark="全国省级默认", status="active"),
            DepositRule(
                id="dr-wh-city",
                province="湖北省",
                city="武汉市",
                scale="city",
                amount=8000,
                remark="武汉地市级示例（可改可删）",
                status="active",
            ),
        ]
    )
    db.commit()


def seed_if_empty(db: Session) -> None:
    _ensure_deposit_rules(db)
    if db.query(Staff).first():
        _migrate_brand_name(db)
        _ensure_rich_content(db)
        _ensure_service_role_perms(db)
        return
    t = now_str()
    pwd = _pwd()

    db.add_all(
        [
            Role(id="r-admin", name="管理员", code="admin", builtin=True, permissions=dump_json(["*"]), remark="全部权限"),
            Role(
                id="r-finance",
                name="财务",
                code="finance",
                builtin=True,
                permissions=dump_json(
                    ["dashboard:view", "products:view", "agents:view", "orders:view", "warehouse:view"]
                ),
                remark="查看佣金与订单",
            ),
            Role(
                id="r-service",
                name="客服",
                code="service",
                builtin=True,
                permissions=dump_json(
                    [
                        "dashboard:view",
                        "orders:view",
                        "orders:edit",
                        "warehouse:view",
                        "stock:view",
                        "stock:in",
                        "stock:out",
                        "service:view",
                        "service:edit",
                        "feedback:view",
                        "feedback:edit",
                        "content:view",
                        "users:view",
                    ]
                ),
                remark="在线客服、FAQ 配置与订单协助",
            ),
        ]
    )
    db.add_all(
        [
            Staff(id="s1", username="admin", password_hash=pwd, name="系统管理员", role_id="r-admin", status="active", created_at=t),
            Staff(id="s2", username="finance", password_hash=pwd, name="财务小王", role_id="r-finance", status="active", created_at=t),
            Staff(id="s3", username="service", password_hash=pwd, name="客服小李", role_id="r-service", status="active", created_at=t),
        ]
    )

    db.add(
        Agent(
            id="a1",
            name="杭州星链代理点",
            phone="13800138000",
            contact="张代理",
            province="浙江省",
            city="杭州市",
            district="西湖区",
            address="文三路100号",
            wechat="zl_agent01",
            joined_at="2026-08-01 10:00:00",
            order_count=2,
            status="active",
        )
    )

    users = [
        ("u1", "13800138000", "张代理", "西湖号卡店", "a1", "approved", True, True, "HT44024316", "张代理"),
        ("u2", "13900139000", "李申请", "南京拓客通讯", None, "pending", True, True, "HT13900139", "李申请"),
        ("u3", "13600136000", "周待缴", "杭州待缴通讯", None, "pending", True, False, "HT13600136", "周待缴"),
        ("u4", "13500135000", "吴待签", "杭州待签通讯", None, "pending", False, False, "", ""),
        ("u5", "13700137000", "郑驳回", "杭州驳回通讯", None, "rejected", True, True, "HT13700137", "郑驳回"),
    ]
    for uid, phone, nick, company, agent_id, status, signed, paid, cno, signer in users:
        db.add(
            AppUser(
                id=uid,
                phone=phone,
                password_hash=pwd,
                nickname=nick,
                company_name=company,
                agent_id=agent_id,
                created_at=t,
            )
        )
        db.add(
            AgentApplication(
                id=f"ap-{uid}",
                phone=phone,
                contact=nick,
                name=company,
                province="浙江省",
                city="杭州市",
                district="西湖区",
                address="文三路100号",
                status=status,
                reject_reason="资料不完整，请补充营业执照" if status == "rejected" else "",
                created_at=t,
                reviewed_at=t if status in {"approved", "rejected"} else None,
                agent_id=agent_id,
                deposit_amount=settings.deposit_amount,
                scale="city",
                deposit_paid=paid,
                deposit_paid_at=t if paid else None,
                contract_signed=signed,
                contract_signed_at=t if signed else None,
                contract_no=cno,
                signer_name=signer,
            )
        )

    db.add_all(
        [
            Merchant(**{**m, "biz_types": dump_json(m["biz_types"]), "status": "active"})
            for m in _demo_merchants()
        ]
    )
    db.add(
        MerchantApplication(
            id="ma-pending",
            name="待审核号卡店",
            phone="13800009901",
            contact="待审老板",
            province="浙江省",
            city="杭州市",
            district="拱墅区",
            address="湖墅南路1号",
            status="pending",
            biz_types=dump_json(["haoka"]),
            created_at=t,
        )
    )
    db.add(
        MerchantApplication(
            id="ma-rejected",
            name="驳回号卡店",
            phone="13800009902",
            contact="驳回老板",
            province="浙江省",
            city="杭州市",
            district="上城区",
            status="rejected",
            reject_reason="经营地址与证件不符",
            biz_types=dump_json(["haoka"]),
            created_at=t,
            reviewed_at=t,
        )
    )

    tech_skills = dump_json(["haoka", "contract_phone", "broadband_new_card", "wifi", "cpe", "stock"])
    db.add_all(
        [
            Technician(
                id="t1",
                name="李师傅",
                phone="13600001111",
                province="浙江省",
                city="杭州市",
                district="西湖区",
                status="active",
                merchant_id="m1",
                merchant_name="西湖号卡店",
                skills=tech_skills,
            ),
            Technician(
                id="t2",
                name="赵师傅",
                phone="13600002222",
                province="浙江省",
                city="杭州市",
                district="滨江区",
                status="active",
                merchant_id="m2",
                merchant_name="滨江宽带专营",
                skills=tech_skills,
            ),
        ]
    )

    db.add_all([StockBizType(**row) for row in _demo_stock_types()])

    db.add_all(
        [
            Product(
                id=row["id"],
                name=row["name"],
                biz_type=row["biz_type"],
                stock_type_id=row.get("stock_type_id"),
                carrier=row["carrier"],
                price_label=row["price_label"],
                description=row["description"],
                status="active",
                province=row["province"],
                city=row["city"],
                commission=row["commission"],
                wifi_device_type=row.get("wifi_device_type", ""),
                wifi_biz_mode=row.get("wifi_biz_mode", ""),
            )
            for row in _demo_products()
        ]
    )

    o1 = Order(
        id="o1",
        order_no="HK20260820001",
        biz_type="haoka",
        status="listed",
        customer_name="张三",
        customer_phone="13800001111",
        address="杭州市西湖区文三路100号",
        product_id="p1",
        product_name="电信畅享卡 59元",
        carrier="电信",
        need_new_card=True,
        created_at="2026-08-20 10:00:00",
        updated_at="2026-08-20 10:00:00",
        source="app",
        region="浙江省 杭州市 西湖区",
        province="浙江省",
        city="杭州市",
        district="西湖区",
        commission=80,
        agent_id="a1",
        created_by_user_id="u1",
        logs="[]",
    )
    append_log(o1, "张代理", "提交订单", "app")
    o2 = Order(
        id="o2",
        order_no="HK20260818002",
        biz_type="haoka",
        status="merchant_accepted",
        customer_name="李四",
        customer_phone="13800002222",
        address="杭州市西湖区文二路88号",
        product_name="移动花卡 19元",
        carrier="移动",
        need_new_card=True,
        assigned_merchant_id="m1",
        assigned_merchant_name="西湖号卡店",
        merchant_name="西湖号卡店",
        created_at="2026-08-18 11:00:00",
        updated_at="2026-08-18 12:00:00",
        source="app",
        region="浙江省 杭州市 西湖区",
        province="浙江省",
        city="杭州市",
        district="西湖区",
        commission=35,
        agent_id="a1",
        created_by_user_id="u1",
        logs="[]",
    )
    append_log(o2, "张代理", "提交订单", "app")
    append_log(o2, "西湖号卡店", "接单", "mp")
    o3 = Order(
        id="o3",
        order_no="KD20260815003",
        biz_type="broadband_new_card",
        status="dispatched",
        customer_name="王五",
        customer_phone="13800003333",
        address="杭州市西湖区古翠路12号",
        product_name="电信融合宽带 300M",
        carrier="电信",
        need_new_card=True,
        assigned_merchant_id="m1",
        assigned_merchant_name="西湖号卡店",
        merchant_name="西湖号卡店",
        technician_id="t1",
        technician_name="李师傅",
        needs_dispatch=True,
        created_at="2026-08-15 09:00:00",
        updated_at="2026-08-15 14:00:00",
        source="app",
        region="浙江省 杭州市 西湖区",
        province="浙江省",
        city="杭州市",
        district="西湖区",
        commission=120,
        agent_id="a1",
        created_by_user_id="u1",
        logs="[]",
    )
    append_log(o3, "西湖号卡店", "派单给李师傅", "mp")
    db.add_all([o1, o2, o3])

    db.add(
        WarehouseItem(
            id="w1",
            product_id="p1",
            product_name="电信畅享卡 59元",
            sku="HK-DX-59",
            spec="号卡",
            stock=200,
            safety_stock=20,
            location="A-01",
            updated_at=t,
        )
    )
    db.add_all(
        [
            Faq(id=fid, category=cat, question=q, answer=a, enabled=True, sort=sort)
            for fid, cat, q, a, sort in _default_faqs()
        ]
    )
    db.add_all(
        [
            ContentDoc(
                id=doc_id,
                title={"agreement": "用户协议", "privacy": "隐私政策", "help": "帮助中心", "contract": "派客邦代理合作协议"}[doc_id],
                updated_at=t,
                sections=dump_json(sections),
            )
            for doc_id, sections in _default_doc_sections().items()
        ]
    )
    db.add(
        ServiceConfig(
            id=1,
            hotline="400-800-1234",
            work_time="工作日 09:00-18:00",
            quick_replies=dump_json(_default_quick_replies()),
        )
    )
    db.add(
        AppVersionConfig(
            id=1,
            latest_version="1.0.0",
            min_supported_version="1.0.0",
            force_update=False,
            title="发现新版本",
            release_notes="修复已知问题，提升稳定性。",
            android_url="",
            ios_url="",
            enabled=True,
        )
    )
    db.commit()
