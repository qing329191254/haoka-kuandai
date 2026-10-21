# -*- coding: utf-8 -*-
"""Generate software-copyright materials from App source + screenshots."""
from __future__ import annotations

from pathlib import Path

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING
from docx.oxml.ns import qn
from docx.shared import Cm, Pt

ROOT = Path(r"D:\demo\haoka-kuandai")
LIB = ROOT / "app" / "lib"
SHOTS = ROOT / "screenshots"
OUT = ROOT / "docs" / "软著"
SOFTWARE = "派客邦号卡宽带代理移动客户端软件"
VERSION = "V1.0"

# 与 21 张截图对应的界面文件，按流程抽取，保证截图与源码对应
FRONT_FILES = [
    "pages/splash_page.dart",
    "pages/login_page.dart",
    "pages/forgot_password_page.dart",
    "pages/agent_apply_page.dart",
    "pages/contract_sign_page.dart",
    "pages/deposit_pay_page.dart",
    "pages/audit_status_page.dart",
    "pages/home_page.dart",
    "pages/catalog_product_list_page.dart",
    "pages/stock_type_list_page.dart",
    "pages/catalog_purchase_page.dart",
    "widgets/merchant_picker.dart",
    "pages/create_order_page.dart",
    "pages/my_orders_page.dart",
    "pages/order_detail_page.dart",
    "pages/profile_page.dart",
    "pages/personal_info_page.dart",
    "pages/customer_service_page.dart",
    "pages/feedback_page.dart",
    "pages/doc_pages.dart",
    "pages/shell_page.dart",
    "main.dart",
]

BACK_FILES = [
    "router.dart",
    "store/auth_store.dart",
    "store/order_store.dart",
    "models/order.dart",
    "models/product.dart",
    "models/merchant.dart",
    "models/customer_service.dart",
    "data/products.dart",
    "data/local_merchants.dart",
    "data/phone_brands.dart",
    "data/china_regions.dart",
]

SHOT_META = [
    ("01启动页.jpg", "启动页", "软件启动后展示品牌标识「派客邦」及号卡宽带一站式服务提示，随后进入登录或首页。", "lib/pages/splash_page.dart"),
    ("02登录页.jpg", "登录页", "代理使用手机号与密码登录系统，可跳转忘记密码或申请入驻，登录即同意用户协议与隐私政策。", "lib/pages/login_page.dart"),
    ("03忘记密码.jpg", "忘记密码", "通过手机号接收短信验证码，校验通过后重置登录密码。", "lib/pages/forgot_password_page.dart"),
    ("04申请入驻.jpg", "申请入驻", "填写联系人、公司名称、经营地址及短信验证码，提交代理入驻申请。", "lib/pages/agent_apply_page.dart"),
    ("05电子合同.jpg", "电子合同", "在线阅读并签署合作协议，完成电子签流程后进入押金缴纳环节。", "lib/pages/contract_sign_page.dart"),
    ("06缴纳押金.jpg", "缴纳押金", "缴纳入驻押金（演示金额 ¥5000），支付完成后等待运营审核。", "lib/pages/deposit_pay_page.dart"),
    ("07入驻状态.jpg", "入驻状态", "展示电子签合同编号、签署人及押金缴纳记录，提示当前处于审核中。", "lib/pages/audit_status_page.dart"),
    ("08首页.jpg", "首页", "代理登录后的业务入口，可进入号卡、合约机、宽带、WIFI 设备及存量业务办理。", "lib/pages/home_page.dart"),
    ("09号卡套餐.jpg", "号卡套餐", "按城市浏览当地在售号卡套餐，选择产品后进入下单页填写收货人信息。", "lib/pages/catalog_product_list_page.dart"),
    ("10我的订单.jpg", "我的订单", "按业务类型筛选并查看已提交的转手订单列表，支持搜索单号、客户与地址。", "lib/pages/my_orders_page.dart"),
    ("11号卡下单.jpg", "号卡下单", "填写收货人姓名、手机号、证件号及收货地址后提交号卡订单。", "lib/pages/catalog_purchase_page.dart"),
    ("12宽带下单.jpg", "宽带下单", "填写办理人信息、安装地址并选择宽带产品，提交后由本地商家承接。", "lib/pages/catalog_purchase_page.dart"),
    ("13选择商家.jpg", "选择商家", "按省市区筛选并指定本地承接商家，宽带类订单可绑定当地门店办理。", "lib/widgets/merchant_picker.dart"),
    ("14订单详情.jpg", "订单详情", "查看订单状态、客户资料、安装地址及办理进度，对应订单详情页逻辑。", "lib/pages/order_detail_page.dart"),
    ("15个人中心.jpg", "个人中心", "展示代理账号信息，提供订单、客服、个人信息、帮助中心及退出登录等功能。", "lib/pages/profile_page.dart"),
    ("16个人信息.jpg", "个人信息", "查看并完善代理联系人、公司名称、经营区域等入驻资料。", "lib/pages/personal_info_page.dart"),
    ("17客服中心.jpg", "客服中心", "联系平台客服咨询入驻审核、订单办理等业务问题。", "lib/pages/customer_service_page.dart"),
    ("18意见反馈.jpg", "意见反馈", "提交使用过程中的问题或建议，便于运营跟进处理。", "lib/pages/feedback_page.dart"),
    ("19帮助中心.jpg", "帮助中心", "查看号卡、宽带等业务办理说明与常见问题。", "lib/pages/doc_pages.dart"),
    ("20宽带续费.jpg", "宽带续费", "办理存量宽带续费业务，选择套餐后提交转手订单。", "lib/pages/stock_type_list_page.dart"),
    ("21合约机下单.jpg", "合约机下单", "填写申请人、联系电话、手机品牌及可接受价位，提交合约机办理申请。", "lib/pages/create_order_page.dart"),
]


def set_run_font(run, name: str, size_pt: float, east_asia: str | None = None, bold=False):
    run.font.name = name
    run.font.size = Pt(size_pt)
    run.bold = bold
    rpr = run._element.get_or_add_rPr()
    rfonts = rpr.get_or_add_rFonts()
    rfonts.set(qn("w:ascii"), name)
    rfonts.set(qn("w:hAnsi"), name)
    rfonts.set(qn("w:eastAsia"), east_asia or name)


def set_doc_default(doc: Document):
    sect = doc.sections[0]
    sect.page_width = Cm(21.0)
    sect.page_height = Cm(29.7)
    sect.left_margin = Cm(2.0)
    sect.right_margin = Cm(2.0)
    sect.top_margin = Cm(2.2)
    sect.bottom_margin = Cm(2.2)
    header = sect.header
    hp = header.paragraphs[0]
    hp.alignment = WD_ALIGN_PARAGRAPH.CENTER
    hr = hp.add_run(f"{SOFTWARE} {VERSION}")
    set_run_font(hr, "Times New Roman", 9, "宋体")
    footer = sect.footer
    fp = footer.paragraphs[0]
    fp.alignment = WD_ALIGN_PARAGRAPH.CENTER
    fr = fp.add_run("— 页脚页码由代办最终排版时统一添加 —")
    set_run_font(fr, "Times New Roman", 8, "宋体")


def add_heading_cn(doc: Document, text: str, size=16):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(12)
    r = p.add_run(text)
    set_run_font(r, "Times New Roman", size, "黑体", bold=True)


def add_para_cn(doc: Document, text: str, size=11, bold=False, first_line=True):
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(6)
    p.paragraph_format.line_spacing = 1.5
    if first_line:
        p.paragraph_format.first_line_indent = Cm(0.74)
    r = p.add_run(text)
    set_run_font(r, "Times New Roman", size, "宋体", bold=bold)
    return p


def strip_dart(src: str) -> list[str]:
    """Keep code and /// documentation comments; drop empty lines and other comments."""
    n = len(src)
    i = 0
    out: list[str] = []
    buf: list[str] = []
    in_str = None  # ', ", or r' / r"
    triple = False
    raw = False

    def flush_line():
        line = "".join(buf).rstrip()
        buf.clear()
        if not line:
            return
        if line.strip().startswith("//") and not line.strip().startswith("///"):
            return
        out.append(line)

    while i < n:
        ch = src[i]
        nxt = src[i + 1] if i + 1 < n else ""

        if in_str:
            buf.append(ch)
            if in_str in ("'", '"') and not raw:
                if ch == "\\" and i + 1 < n:
                    buf.append(src[i + 1])
                    i += 2
                    continue
                if triple:
                    if src[i : i + 3] == in_str * 3:
                        buf.append(src[i + 1])
                        buf.append(src[i + 2])
                        i += 3
                        in_str = None
                        triple = False
                        continue
                elif ch == in_str:
                    in_str = None
                    raw = False
            elif in_str.startswith("r") and ch == in_str[-1]:
                in_str = None
                raw = False
            if ch == "\n":
                # keep string newlines as part of buffer then flush? dart strings rarely span without \
                pass
            i += 1
            continue

        # block comment
        if ch == "/" and nxt == "*":
            i += 2
            while i < n - 1 and not (src[i] == "*" and src[i + 1] == "/"):
                i += 1
            i += 2
            continue

        # line comment
        if ch == "/" and nxt == "/":
            # keep /// documentation
            if i + 2 < n and src[i + 2] == "/":
                while i < n and src[i] != "\n":
                    buf.append(src[i])
                    i += 1
                continue
            while i < n and src[i] != "\n":
                i += 1
            continue

        # strings
        if ch in ("'", '"'):
            if i >= 1 and src[i - 1] == "r":
                raw = True
            if src[i : i + 3] == ch * 3:
                in_str = ch
                triple = True
                buf.append(ch)
                buf.append(ch)
                buf.append(ch)
                i += 3
                continue
            in_str = ch
            buf.append(ch)
            i += 1
            continue

        if ch == "\n":
            flush_line()
            i += 1
            continue

        buf.append(ch)
        i += 1

    flush_line()
    return out


def file_chunk(rel: str) -> list[str]:
    path = LIB / rel
    if not path.exists():
        return []
    cleaned = strip_dart(path.read_text(encoding="utf-8"))
    if not cleaned:
        return []
    return [f"/// 文件：lib/{rel.replace(chr(92), '/')}"] + cleaned


def collect(files: list[str], need: int) -> tuple[list[str], list[str]]:
    chunks: list[tuple[str, list[str]]] = []
    for rel in files:
        c = file_chunk(rel)
        if c:
            chunks.append((rel, c))
    if not chunks:
        return [], []
    max_per = max(48, need // len(chunks))
    lines: list[str] = []
    used_n: dict[str, int] = {}
    leftovers: list[tuple[str, list[str]]] = []
    for rel, chunk in chunks:
        take = min(max_per, len(chunk), need - len(lines))
        lines.extend(chunk[:take])
        used_n[rel] = take
        if len(chunk) > take:
            leftovers.append((rel, chunk[take:]))
        if len(lines) >= need:
            break
    for rel, rest in leftovers:
        if len(lines) >= need:
            break
        take = min(len(rest), need - len(lines))
        lines.extend(rest[:take])
        used_n[rel] = used_n.get(rel, 0) + take
    used = [f"{rel}（{used_n[rel]} 行）" for rel, _ in chunks if used_n.get(rel)]
    return lines[:need], used


def write_code_doc(path: Path, title: str, intro: list[str], lines: list[str], used: list[str]):
    doc = Document()
    set_doc_default(doc)
    add_heading_cn(doc, SOFTWARE, 16)
    add_heading_cn(doc, f"{title}（{VERSION}）", 14)
    for t in intro:
        add_para_cn(doc, t)
    add_para_cn(doc, "本部分收录源文件：" + "、".join(used), first_line=False)
    add_para_cn(doc, f"有效逻辑代码行数：{len(lines)} 行（已去除空行及普通注释，保留方法说明注释 ///）。", first_line=False)

    for line in lines:
        p = doc.add_paragraph()
        pf = p.paragraph_format
        pf.space_before = Pt(0)
        pf.space_after = Pt(0)
        pf.line_spacing = 1.0
        pf.line_spacing_rule = WD_LINE_SPACING.SINGLE
        r = p.add_run(line[:200] if len(line) > 200 else line)
        set_run_font(r, "Consolas", 9, "宋体")
    path.parent.mkdir(parents=True, exist_ok=True)
    doc.save(path)


def write_shot_doc(path: Path):
    doc = Document()
    set_doc_default(doc)
    add_heading_cn(doc, SOFTWARE, 16)
    add_heading_cn(doc, f"软件操作界面截图说明 {VERSION}", 14)
    add_para_cn(
        doc,
        "以下截图按代理使用流程排列：启动 → 登录 / 入驻 → 业务办理 → 订单查询 → 个人中心。"
        "每张截图对应客户端相应页面源码，功能说明与源码逻辑一致。著作权人信息由申请单位填写。",
    )
    add_para_cn(doc, f"共收录界面截图 {len(SHOT_META)} 张。", first_line=False)

    for idx, (fname, title, desc, src) in enumerate(SHOT_META, start=1):
        img = SHOTS / fname
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(12)
        p.paragraph_format.space_after = Pt(6)
        p.paragraph_format.first_line_indent = Cm(0)
        r = p.add_run(f"图{idx}　{title}")
        set_run_font(r, "Times New Roman", 12, "黑体", bold=True)

        if img.exists():
            ip = doc.add_paragraph()
            ip.alignment = WD_ALIGN_PARAGRAPH.CENTER
            ip.paragraph_format.space_after = Pt(6)
            run = ip.add_run()
            run.add_picture(str(img), width=Cm(8.2))
        else:
            add_para_cn(doc, f"（缺少文件：{fname}）", first_line=False)

        dp = doc.add_paragraph()
        dp.paragraph_format.first_line_indent = Cm(0.74)
        dp.paragraph_format.space_after = Pt(10)
        dr = dp.add_run(f"功能说明：{desc}（对应源码：{src}）")
        set_run_font(dr, "Times New Roman", 11, "宋体")

    doc.save(path)


def write_form_doc(path: Path, front_n: int, back_n: int, front_used: list[str], back_used: list[str]):
    doc = Document()
    set_doc_default(doc)
    add_heading_cn(doc, "计算机软件著作权登记申请表（技术信息填写稿）", 15)
    add_para_cn(
        doc,
        "说明：本文件仅填写软件技术相关栏目，著作权人、公司名称、证件号码、联系人等主体信息请客户自行填写。"
        "软件全称可先按下列名称申报，最终以客户确认为准。",
        first_line=False,
    )

    rows = [
        ("软件全称", f"{SOFTWARE} {VERSION}"),
        ("软件简称", "派客邦"),
        ("版本号", "V1.0"),
        ("著作权人", "【客户公司全称，请客户填写】"),
        ("开发完成日期", "【请客户确认，建议填写实际完成日】"),
        ("首次发表日期", "未发表"),
        ("开发方式", "【独立开发 / 委托开发，请客户按合同填写】"),
        ("权利范围", "全部权利"),
        ("软件分类", "应用软件 / 行业应用 / 通信与信息业务管理"),
        ("硬件环境", "智能手机；建议 Android 8.0 及以上或 iOS 12 及以上"),
        ("软件环境", "Android / iOS 操作系统；客户端基于 Flutter 框架运行"),
        ("编程语言", "Dart（Flutter）"),
        ("源程序量", f"约 {front_n + back_n} 行（本次提交界面层 {front_n} 行 + 业务逻辑层 {back_n} 行）"),
        ("开发目的", "为通信号卡、宽带等业务代理提供移动端入驻、下单与订单管理工具。"),
    ]
    for k, v in rows:
        p = doc.add_paragraph()
        p.paragraph_format.space_after = Pt(4)
        p.paragraph_format.first_line_indent = Cm(0)
        rk = p.add_run(f"{k}：")
        set_run_font(rk, "Times New Roman", 11, "黑体", bold=True)
        rv = p.add_run(v)
        set_run_font(rv, "Times New Roman", 11, "宋体")

    add_heading_cn(doc, "主要功能和技术特点", 13)
    add_para_cn(
        doc,
        "一、主要功能：本软件为号卡宽带业务代理移动客户端。代理可通过手机号登录或申请入驻；"
        "入驻流程包括填写资料、签署电子合作协议、缴纳入驻押金及查看审核状态。"
        "审核通过后，代理可办理号卡、合约机、宽带、WIFI 设备及存量业务（如宽带续费）转手订单，"
        "支持选择套餐、填写收货人/办理人信息、按地区指定本地商家，并查询订单列表与订单详情。"
        "同时提供个人中心、客服咨询、意见反馈、帮助中心、用户协议与隐私政策查阅等功能。",
    )
    add_para_cn(
        doc,
        "二、技术特点：采用 Flutter 跨平台技术一次开发覆盖 Android 与 iOS；"
        "使用路由管理页面跳转，使用状态管理维护登录会话与订单数据；"
        "业务界面与业务逻辑分层实现，界面层负责展示与交互，逻辑层负责入驻审核、订单提交与查询。"
        "电子签与支付在本版本中提供完整操作界面与流程控制，便于后续对接真实电子签及支付通道。",
    )
    add_para_cn(
        doc,
        "三、关于「前端 / 后端」源码说明：本软件为移动客户端，不包含独立部署的服务器程序。"
        "按代办「前后端各 1750 行」要求，将客户端源码拆分为："
        "（1）前端（界面层）对应 pages、widgets 等展示与交互代码；"
        "（2）后端（业务逻辑层）对应 store、models、data、router 等登录、入驻、订单与路由逻辑。"
        "截图均为上述客户端界面，与提交源码相对应。请代办按此口径整理，勿改用小程序或 Web 后台代码凑数。",
    )
    add_para_cn(doc, "界面层文件：" + "、".join(front_used), first_line=False)
    add_para_cn(doc, "业务逻辑层文件：" + "、".join(back_used), first_line=False)
    add_para_cn(
        doc,
        "四、运行环境简述：用户在智能手机安装本客户端后即可使用。演示环境使用固定短信验证码完成身份校验，"
        "不改变软件功能结构。",
    )
    doc.save(path)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    front, front_used = collect(FRONT_FILES, 1750)
    back, back_used = collect(BACK_FILES, 1750)
    print("FRONT", len(front), front_used)
    print("BACK", len(back), back_used)
    if len(front) < 1750 or len(back) < 1750:
        raise SystemExit(f"行数不足：front={len(front)} back={len(back)}")

    write_code_doc(
        OUT / "01-源码-前端界面层-1750行.docx",
        "源程序（前端 / 界面层）",
        [
            "本部分为移动客户端界面层源程序，对应登录、入驻、业务办理、订单及个人中心等界面。"
            "已去除空行和普通注释，保留方法说明注释（///）。请代办按版权中心格式做最终分页整理。",
        ],
        front,
        front_used,
    )
    write_code_doc(
        OUT / "02-源码-业务逻辑层-1750行.docx",
        "源程序（后端 / 业务逻辑层）",
        [
            "本部分为移动客户端业务逻辑层源程序，包含路由、登录入驻、订单存储、数据模型及业务数据。"
            "本软件无独立服务器后端，本层承担代办材料中「后端」逻辑代码要求。"
            "已去除空行和普通注释，保留方法说明注释（///）。",
        ],
        back,
        back_used,
    )
    write_shot_doc(OUT / "03-操作界面截图说明.docx")
    write_form_doc(
        OUT / "04-申请表技术信息填写稿.docx",
        len(front),
        len(back),
        front_used,
        back_used,
    )
    print("OK", OUT)


if __name__ == "__main__":
    main()
