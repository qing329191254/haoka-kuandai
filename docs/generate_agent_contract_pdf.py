"""生成《派客邦代理合作协议》PDF。条款号使用英文序号 1.1，分栏排版避免被拆开。"""

from __future__ import annotations

from pathlib import Path

from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "派客邦代理合作协议.pdf"
OUT_ASCII = ROOT / "docs" / "paikebang-agent-contract.pdf"

pdfmetrics.registerFont(TTFont("SimSun", r"C:\Windows\Fonts\simsun.ttc", subfontIndex=0))
pdfmetrics.registerFont(TTFont("SimHei", r"C:\Windows\Fonts\simhei.ttf"))

PAGE_W = A4[0] - 2.3 * cm * 2


def styles():
    base = getSampleStyleSheet()
    common = dict(fontName="SimSun", fontSize=10.5, leading=18, alignment=TA_LEFT)
    return {
        "title": ParagraphStyle(
            "t",
            parent=base["Normal"],
            fontName="SimHei",
            fontSize=18,
            leading=26,
            alignment=TA_CENTER,
            spaceAfter=14,
        ),
        "meta": ParagraphStyle("m", parent=base["Normal"], **common, spaceAfter=2),
        "h1": ParagraphStyle(
            "h",
            parent=base["Normal"],
            fontName="SimHei",
            fontSize=12,
            leading=20,
            spaceBefore=11,
            spaceAfter=5,
            alignment=TA_LEFT,
        ),
        "body": ParagraphStyle("b", parent=base["Normal"], **common, spaceAfter=3),
        "blank": ParagraphStyle(
            "k",
            parent=base["Normal"],
            fontName="SimSun",
            fontSize=10.5,
            leading=19,
            alignment=TA_LEFT,
            spaceAfter=1,
        ),
        "note": ParagraphStyle(
            "n",
            parent=base["Normal"],
            fontName="SimSun",
            fontSize=9,
            leading=13,
            textColor="#555555",
            spaceBefore=4,
            spaceAfter=6,
        ),
        "sign": ParagraphStyle(
            "s",
            parent=base["Normal"],
            fontName="SimSun",
            fontSize=10,
            leading=16,
            alignment=TA_LEFT,
        ),
    }


def _plain(text: str) -> str:
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace("\n", "<br/>")
    )


def p(text: str, style):
    if "<br" in text or "<b>" in text or "<font" in text:
        return Paragraph(text.replace("\n", "<br/>"), style)
    return Paragraph(_plain(text), style)


def clause(no: str, text: str, s: dict):
    """英文序号 1.1 后跟一个空格再接正文。"""
    html = (
        f'<font name="Helvetica" size="10.5">{no}</font>'
        f"&nbsp;{_plain(text)}"
    )
    return Paragraph(html, s["body"])

def build():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(OUT),
        pagesize=A4,
        leftMargin=2.3 * cm,
        rightMargin=2.3 * cm,
        topMargin=1.8 * cm,
        bottomMargin=1.8 * cm,
        title="派客邦代理合作协议",
        author="湖北省觅智科技有限公司",
    )
    s = styles()
    story = []

    story.append(p("派客邦代理合作协议", s["title"]))
    story.append(
        p(
            "本协议适用于「派客邦」平台代理入驻合作。双方通过合法有效的电子签名方式签署后，与纸质合同具有同等法律效力。",
            s["note"],
        )
    )

    story.append(p("甲方（平台方）：湖北省觅智科技有限公司", s["meta"]))
    story.append(p("类型：有限责任公司（自然人投资或控股）", s["meta"]))
    story.append(p("统一社会信用代码：91420100MAETU0F91B", s["meta"]))
    story.append(p("法定代表人：龙伟", s["meta"]))
    story.append(p("注册资本：人民币贰佰万元整", s["meta"]))
    story.append(p("成立日期：2025年9月3日", s["meta"]))
    story.append(
        p(
            "住所：湖北省武汉市东湖新技术开发区光谷大道70号光谷世贸中心I栋12层1201-1",
            s["meta"],
        )
    )
    story.append(Spacer(1, 8))
    story.append(p("乙方（代理方）：", s["meta"]))
    story.append(p("公司 / 门店名称：______________________________", s["blank"]))
    story.append(p("联系人姓名：________________________________", s["blank"]))
    story.append(p("手机号码：__________________________________", s["blank"]))
    story.append(p("证件号码：__________________________________", s["blank"]))
    story.append(p("合作区域：________省 ________市 ________区（县）", s["blank"]))
    story.append(p("合作规模：□区县级　□地市级　□省级　（以入驻申请记载为准）", s["blank"]))
    story.append(
        p("入驻保证金：人民币（大写）______________元整（¥__________元）", s["blank"])
    )
    story.append(Spacer(1, 8))
    story.append(
        p(
            "甲乙双方本着平等、自愿、诚实信用原则，就乙方通过「派客邦」平台开展号卡、宽带等业务转手合作事宜，达成如下协议：",
            s["body"],
        )
    )
    story.append(Spacer(1, 4))

    story.append(p("第一条　定义与合作内容", s["h1"]))
    story.append(
        clause(
            "1.1",
            "「派客邦」系甲方运营的代理服务平台（含移动应用程序、运营后台及相关信息系统，以下合称「本平台」）。",
            s,
        )
    )
    story.append(
        clause(
            "1.2",
            "乙方作为合作代理，在约定合作区域内通过自有或合法渠道获客后，可使用本平台提交号卡、宽带、合约机、随身WIFI、存量业务等相关转手订单，并由甲方或其指定的本地合作商家、上门服务人员完成履约。",
            s,
        )
    )
    story.append(
        clause(
            "1.3",
            "商品套餐、价格、佣金规则由甲方在后台统一配置；乙方无需自行上架商品，应按本平台展示规则与订单流程操作。",
            s,
        )
    )
    story.append(
        clause(
            "1.4",
            "乙方合作区域与合作规模以入驻申请及本协议首部记载为准。未经甲方书面同意，乙方不得超出约定区域或规模开展合作推广。",
            s,
        )
    )

    story.append(p("第二条　入驻条件与审核", s["h1"]))
    story.append(
        clause(
            "2.1",
            "乙方应如实提交入驻资料（含联系人、主体信息、合作区域、证件影像等）。资料不实、不全或存在风险的，甲方有权驳回或要求补正。",
            s,
        )
    )
    story.append(
        clause(
            "2.2",
            "入驻流程为：提交申请→签署本协议→缴纳保证金→甲方审核。审核通过后方可使用下单等合作功能。",
            s,
        )
    )
    story.append(
        clause(
            "2.3",
            "甲方审核周期一般为1至2个工作日，具体以实际审核结果为准。审核未通过的，甲方将告知原因；乙方可按要求完善后再次申请。",
            s,
        )
    )

    story.append(p("第三条　保证金", s["h1"]))
    story.append(
        clause(
            "3.1",
            "乙方应在签署本协议后，按本平台入驻流程展示并锁定的金额（同时记载于本协议首部）向甲方缴纳入驻保证金。不同城市、不同合作规模对应的保证金标准由甲方制定，并在入驻流程中向乙方展示。",
            s,
        )
    )
    story.append(
        clause(
            "3.2",
            "保证金在合作期内由甲方留存，用于履约保障、客诉赔付、违约责任承担等。保证金不视为预付佣金，不计利息。",
            s,
        )
    )
    story.append(
        clause(
            "3.3",
            "合作终止且乙方无未结清订单、客诉、赔付或其他应付款项时，乙方可申请退还剩余保证金。甲方应在核实无误后的合理期限内办理退还（法律法规另有规定或双方另有约定的除外）。",
            s,
        )
    )
    story.append(
        clause(
            "3.4",
            "因乙方违约、欺诈、投诉处理不当等给甲方、用户或合作方造成损失的，甲方有权从保证金中直接扣除相应款项；不足部分，乙方应继续赔偿。",
            s,
        )
    )

    story.append(p("第四条　双方权利义务", s["h1"]))
    story.append(clause("4.1", "甲方权利义务：", s))
    story.append(
        p(
            "（1）提供本平台系统、订单流转、必要的运营支持与规则说明；"
            "（2）有权制定、调整商品、佣金、保证金、风控及平台规则，并以平台公告、站内通知或其他合理方式告知乙方；"
            "（3）对异常订单、违规推广、资料造假等采取限制下单、暂扣结算、终止合作等措施；"
            "（4）依法保护在合作中知悉的乙方商业秘密，法律法规要求披露或为履约所必需的除外。",
            s["body"],
        )
    )
    story.append(Spacer(1, 4))
    story.append(clause("4.2", "乙方权利义务：", s))
    story.append(
        p(
            "（1）合法合规获客与宣传，不得虚假宣传，不得冒用运营商或甲方名义，不得从事违法违规业务；"
            "（2）保证提交的用户信息、订单信息真实有效，并对因其原因导致的用户投诉、拒识、无法履约等承担责任；"
            "（3）妥善保管账号与密码，不得出借、转让账号；因账号保管不善造成的损失由乙方自行承担；"
            "（4）按平台规则配合商家、上门人员完成开户、装机、激活等流程，不得恶意取消、刷单或干扰履约；"
            "（5）遵守个人信息保护相关法律法规，合法收集、使用、存储用户信息。",
            s["body"],
        )
    )
    story.append(Spacer(1, 4))

    story.append(p("第五条　佣金与结算", s["h1"]))
    story.append(
        clause(
            "5.1",
            "各类业务佣金标准以甲方后台配置及订单达成时适用的规则为准。甲方可根据市场与运营商政策调整佣金，调整后对后续新产生的订单生效。",
            s,
        )
    )
    story.append(
        clause(
            "5.2",
            "结算周期、结算条件（如激活成功、装机完成、无退订等）、发票与税费要求，以甲方届时有效的结算规则或双方书面补充约定为准。",
            s,
        )
    )
    story.append(
        clause(
            "5.3",
            "存在用户退订、投诉成立、资料造假、违规推广等情形的，甲方有权不予结算、追回已结算款项，或从保证金中抵扣。",
            s,
        )
    )

    story.append(p("第六条　保密与数据安全", s["h1"]))
    story.append(
        clause(
            "6.1",
            "双方对合作过程中知悉的商业秘密、用户信息、技术与运营数据负有保密义务，未经对方书面同意不得向第三方披露，法律法规另有规定或为履行本协议所必需的除外。",
            s,
        )
    )
    story.append(
        clause(
            "6.2",
            "本协议终止后，本条约定的保密义务在合理期限内继续有效。因泄密造成损失的，过错方应依法承担相应责任。",
            s,
        )
    )

    story.append(p("第七条　反商业贿赂与合规", s["h1"]))
    story.append(
        clause(
            "7.1",
            "双方不得向对方工作人员或关联方输送不正当利益。乙方不得以任何形式实施电信网络诈骗、骚扰营销、伪基站、非法买卖个人信息等违法活动。",
            s,
        )
    )
    story.append(
        clause(
            "7.2",
            "一经发现存在前款情形，甲方有权立即终止合作、依法处置保证金，并保留向有关机关举报及向乙方追偿的权利。",
            s,
        )
    )

    story.append(p("第八条　协议期限、变更与解除", s["h1"]))
    story.append(
        clause(
            "8.1",
            "本协议自双方完成电子签署之日起生效。合作期限自生效日起一年；期满前任何一方未以书面或本平台认可的方式提出终止的，自动续展一年，续展次数不限，双方另有约定的除外。",
            s,
        )
    )
    story.append(
        clause(
            "8.2",
            "甲方可通过本平台发布业务规则、结算规则等补充文件。该等文件与本协议不一致的，就变更事项以更新后的规则为准；但不得减损乙方就规则更新前已生效订单依法享有的合法权益，双方另有书面约定的除外。",
            s,
        )
    )
    story.append(
        clause(
            "8.3",
            "乙方可申请解除本协议；甲方在乙方结清相关义务并处理完毕在途订单、客诉后办理退出。甲方基于风控、违规或经营调整，可提前通知终止合作。",
            s,
        )
    )
    story.append(
        clause(
            "8.4",
            "有下列情形之一的，甲方有权单方解除本协议：乙方严重违约；乙方提供虚假资料；乙方从事违法违规业务；乙方长期未履约或明显丧失履约能力等。",
            s,
        )
    )

    story.append(p("第九条　违约责任", s["h1"]))
    story.append(clause("9.1", "任何一方违反本协议约定，应赔偿因此给对方造成的直接损失。", s))
    story.append(
        clause(
            "9.2",
            "乙方违约的，甲方有权采取限制功能、暂缓结算、扣除保证金、解除本协议等措施，并要求乙方承担相应责任。",
            s,
        )
    )

    story.append(p("第十条　不可抗力", s["h1"]))
    story.append(
        clause(
            "10.1",
            "因自然灾害、战争、政府行为、法律法规或政策调整、公共卫生事件，以及非因甲方可控的基础电信网络或电力系统中断等不能预见、不能避免并不能克服的客观情况，致使本协议无法履行或无法按约履行的，受影响一方在及时通知对方并提供相应证明后，可根据影响程度部分或全部免除违约责任；但协议项下在不可抗力发生前已经产生的付款、结算与赔偿义务不因此免除。",
            s,
        )
    )

    story.append(p("第十一条　争议解决", s["h1"]))
    story.append(
        clause(
            "11.1",
            "因本协议引起的或与本协议有关的争议，双方应首先友好协商解决；协商不成的，任何一方均可向甲方住所地有管辖权的人民法院提起诉讼，即向湖北省武汉市有管辖权的人民法院提起诉讼。",
            s,
        )
    )

    story.append(p("第十二条　电子签署与效力", s["h1"]))
    story.append(
        clause(
            "12.1",
            "本协议采用电子签名方式签署。乙方经「派客邦」App引导，在甲方委托的电子签名服务机构（如e签宝）提供的签署页面完成实名认证（如需）与签署操作后，即视为乙方已阅读、理解并同意本协议全部条款。",
            s,
        )
    )
    story.append(
        clause(
            "12.2",
            "电子签署完成后形成的电子合同文本、签署过程日志、证书与存证信息等，可作为双方权利义务的有效凭证，与手写签名或盖章的纸质合同具有同等法律效力。",
            s,
        )
    )
    story.append(
        clause(
            "12.3",
            "本协议由正文、入驻申请信息、本平台已向乙方展示并生效的规则，以及双方确认的补充协议共同构成。解释顺序：补充协议优先于正文；正文优先于一般平台规则（规则中有特别说明的除外）。",
            s,
        )
    )

    story.append(p("第十三条　其他", s["h1"]))
    story.append(
        clause(
            "13.1",
            "本协议未尽事宜，由双方另行协商并签订补充协议。补充协议签订前，双方可按照本协议及甲方已向乙方公示且不与本协议强制性约定相冲突的平台规则执行。",
            s,
        )
    )
    story.append(
        clause(
            "13.2",
            "本协议以电子文本形式订立，经双方电子签署后生效。甲乙双方可通过本平台或电子签名服务机构提供的渠道查阅、下载各执一份电子文本，各份电子文本具有同等法律效力。",
            s,
        )
    )

    story.append(Spacer(1, 14))
    story.append(p("（以下为签署页）", s["note"]))
    story.append(Spacer(1, 8))

    sign_data = [
        [
            p(
                "<b>甲方（盖章）</b><br/><br/>"
                "湖北省觅智科技有限公司<br/>"
                "统一社会信用代码：91420100MAETU0F91B<br/>"
                "法定代表人：龙伟<br/><br/>"
                "签署日期：____年____月____日",
                s["sign"],
            ),
            p(
                "<b>乙方（签字/盖章）</b><br/><br/>"
                "主体名称：_______________<br/><br/>"
                "签署人：_________________<br/><br/>"
                "签署日期：____年____月____日",
                s["sign"],
            ),
        ]
    ]
    t = Table(sign_data, colWidths=[8.0 * cm, 8.0 * cm])
    t.setStyle(
        TableStyle(
            [
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 8),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                ("TOPPADDING", (0, 0), (-1, -1), 8),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
                ("BOX", (0, 0), (0, 0), 0.5, "#888888"),
                ("BOX", (1, 0), (1, 0), 0.5, "#888888"),
            ]
        )
    )
    story.append(t)

    doc.build(story)
    OUT_ASCII.write_bytes(OUT.read_bytes())
    print(f"OK {OUT}")
    print(f"OK {OUT_ASCII}")


if __name__ == "__main__":
    build()
