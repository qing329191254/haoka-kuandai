import type {
  AppUser,
  BizType,
  EnableStatus,
  FaqItem,
  FeedbackItem,
  Merchant,
  Order,
  OrderStatus,
  Product,
  Technician,
} from '@/types/order'
import type { Agent, StockRecord, WarehouseItem } from '@/types/stock'

const names = ['周八', '吴九', '郑十', '冯十一', '陈十二', '褚十三', '卫十四', '蒋十五', '沈十六', '韩十七', '杨十八', '朱十九', '秦二十', '许二一', '何二二']
const regions = ['西湖区', '滨江区', '余杭区', '拱墅区', '上城区', '萧山区', '临平区', '钱塘区']
const streets = ['文三路', '网商路', '文一西路', '莫干山路', '延安路', '市心中路', '金沙大道', '风情大道']
const statuses: OrderStatus[] = ['listed', 'merchant_accepted', 'dispatched', 'tech_accepted', 'boss_opened', 'installing', 'done', 'failed', 'cancelled']
const bizTypes: BizType[] = [
  'haoka',
  'contract_phone',
  'broadband_naked',
  'broadband_new_card',
  'broadband_no_card',
  'wifi',
  'cpe',
  'stock',
]
const carriers = ['电信', '联通', '移动', '广电']
const productsByBiz: Record<BizType, string[]> = {
  haoka: ['电信畅享卡 59元', '移动花卡 19元', '广电流量卡 39元', '联通大王卡 29元'],
  contract_phone: ['苹果 合约机（4000–6000 元）', '华为 合约机（2000–4000 元）', '小米 合约机（1000–2000 元）'],
  broadband_naked: ['裸宽 300M', '裸宽 500M'],
  broadband_new_card: ['联通千兆宽带融合套餐', '电信千兆融合', '移动全家享融合'],
  broadband_no_card: ['移动宽带 300M', '联通宽带 200M', '电信宽带 500M'],
  wifi: ['随身 WIFI 月租 39', '家庭 WIFI 包年买断', '5G 随身 WIFI 月租 59'],
  cpe: ['5G CPE 畅享套餐', '5G CPE 企业版'],
  stock: ['宽带续费 · 一年', '套餐升档 · 千兆', 'IPTV 基础包'],
}
const merchants = ['西湖号卡店', '滨江宽带专营', '余杭本地商家', '拱墅号卡驿站', '萧山宽带服务点']
const techs = ['李师傅', '赵师傅', '钱师傅', '孙师傅', '周师傅']

function pad(n: number, w = 2) {
  return String(n).padStart(w, '0')
}

function dayTime(offset: number, hour = 10) {
  const d = 20 - (offset % 18)
  return `2026-08-${pad(Math.max(1, d))} ${pad(hour + (offset % 8))}:${pad((offset * 7) % 60)}:00`
}

export function extraOrders(): Order[] {
  return Array.from({ length: 42 }, (_, i) => {
    const biz = bizTypes[i % bizTypes.length]
    const status = statuses[i % statuses.length]
    const name = names[i % names.length]
    const needNewCard = biz === 'haoka' || biz === 'broadband_new_card'
    const prefix =
      biz === 'haoka'
        ? 'HK'
        : biz === 'wifi'
          ? 'WF'
          : biz === 'cpe'
            ? 'CPE'
            : biz === 'stock'
              ? 'CL'
              : biz === 'contract_phone'
                ? 'HJ'
                : 'KD'
    const merchantName = status === 'listed' || status === 'cancelled' ? undefined : merchants[i % merchants.length]
    const technicianName =
      merchantName &&
      ['dispatched', 'tech_accepted', 'boss_opened', 'installing', 'done', 'failed'].includes(status) &&
      biz !== 'broadband_no_card' &&
      biz !== 'broadband_naked'
        ? techs[i % techs.length]
        : undefined
    return {
      id: `e${100 + i}`,
      orderNo: `${prefix}202608${pad(20 - (i % 18))}${pad(100 + i, 3)}`,
      bizType: biz,
      status,
      customerName: name,
      customerPhone: `1380000${pad(200 + i, 4)}`,
      address: `杭州市${regions[i % regions.length]}${streets[i % streets.length]}${i + 1}号`,
      productName: productsByBiz[biz][i % productsByBiz[biz].length],
      carrier: carriers[i % carriers.length],
      merchantName,
      technicianName,
      needNewCard,
      createdAt: dayTime(i, 9),
      updatedAt: dayTime(i, 11),
      source: 'app' as const,
      region: regions[i % regions.length],
      remark: status === 'cancelled' ? '客户取消' : undefined,
      failReason: status === 'failed' ? '客户临时有事无法办理，已记录待回访' : undefined,
      stockTypeId: biz === 'stock' ? 'st1' : undefined,
      stockTypeName: biz === 'stock' ? '宽带续费' : undefined,
      commission: 40 + (i % 8) * 10,
      orderIntent: biz === 'broadband_naked' || biz === 'broadband_new_card' || biz === 'broadband_no_card' ? (i % 2 === 0 ? '意向单' : '确定套餐') : undefined,
      phoneBrand: biz === 'contract_phone' ? ['苹果', '华为', '小米'][i % 3] : undefined,
      priceRange: biz === 'contract_phone' ? ['2000–4000 元', '4000–6000 元', '1000–2000 元'][i % 3] : undefined,
      wifiDeviceType: biz === 'wifi' ? (i % 2 === 0 ? '4G' : '5G') : undefined,
      wifiBizMode: biz === 'wifi' ? (i % 2 === 0 ? '租赁' : '买断') : undefined,
      deliveryPhotos: status === 'done' && biz !== 'broadband_no_card' && biz !== 'broadband_naked' ? ['/mock/delivery-1.svg'] : undefined,
      logs: [{ time: dayTime(i, 9), actor: name, action: 'App 提交办理', channel: 'app' as const }],
    }
  })
}

export function extraProducts(): Product[] {
  const hangzhou = { province: '浙江省', city: '杭州市' }
  return [
    { id: 'p9', name: '联通大王卡 29元', bizType: 'haoka', carrier: '联通', priceLabel: '29元/月', description: '大流量号卡', status: 'active', ...hangzhou, commission: 42 },
    { id: 'p10', name: '电信星卡 39元', bizType: 'haoka', carrier: '电信', priceLabel: '39元/月', description: '年轻用户号卡', status: 'active', ...hangzhou, commission: 48 },
    { id: 'p11', name: '移动青春卡 29元', bizType: 'haoka', carrier: '移动', priceLabel: '29元/月', description: '校园向号卡', status: 'active', ...hangzhou, commission: 38 },
    { id: 'p12', name: '广电畅享卡 49元', bizType: 'haoka', carrier: '广电', priceLabel: '49元/月', description: '高流量套餐', status: 'disabled', ...hangzhou, commission: 55 },
    { id: 'p18', name: '电信黄金卡 99元', bizType: 'haoka', carrier: '电信', priceLabel: '99元/月', description: '商务号卡', status: 'active', province: '江苏省', city: '南京市', commission: 90 },
    { id: 'p19', name: '联通畅爽卡 79元', bizType: 'haoka', carrier: '联通', priceLabel: '79元/月', description: '语音+流量均衡', status: 'disabled', ...hangzhou, commission: 70 },
    { id: 'p21', name: '移动畅享卡 59元', bizType: 'haoka', carrier: '移动', priceLabel: '59元/月', description: '通话流量均衡', status: 'active', ...hangzhou, commission: 62 },
    { id: 'p22', name: '电信流量王 69元', bizType: 'haoka', carrier: '电信', priceLabel: '69元/月', description: '大流量办公', status: 'active', province: '广东省', city: '深圳市', commission: 75 },
    { id: 'pw2', name: '家庭 WIFI 包年买断', bizType: 'wifi', carrier: '联通', priceLabel: '360元/年', description: '5G 家庭 WIFI 买断包年', status: 'active', ...hangzhou, commission: 80, wifiDeviceType: '5G', wifiBizMode: '买断' },
    { id: 'pw3', name: '5G 随身 WIFI 月租 59', bizType: 'wifi', carrier: '移动', priceLabel: '59元/月', description: '5G 随身 WIFI 租赁', status: 'active', ...hangzhou, commission: 68, wifiDeviceType: '5G', wifiBizMode: '租赁' },
    { id: 'pn1', name: '裸宽 300M', bizType: 'broadband_naked', carrier: '电信', priceLabel: '99元/月', description: '不绑号卡的裸宽', status: 'active', ...hangzhou, commission: 60 },
    { id: 'pb1', name: '电信千兆融合', bizType: 'broadband_new_card', carrier: '电信', priceLabel: '199元/月', description: '融合宽带新开卡上门', status: 'active', ...hangzhou, commission: 110 },
    { id: 'po1', name: '移动宽带 300M', bizType: 'broadband_no_card', carrier: '移动', priceLabel: '89元/月', description: '融合宽带线上办理', status: 'active', ...hangzhou, commission: 55 },
    { id: 'pc2', name: '5G CPE 企业版', bizType: 'cpe', carrier: '华为WIFI', priceLabel: '199元/月', description: '企业 CPE', status: 'active', ...hangzhou, commission: 160 },
  ]
}

export function extraMerchants(): Merchant[] {
  const rows: Array<[string, string, string, string, BizType[]]> = [
    ['拱墅号卡驿站', '0571-88880011', '拱墅区', '刘经理', ['haoka']],
    ['上城通信行', '0571-88880012', '上城区', '郑经理', ['haoka', 'broadband_no_card']],
    ['临平号卡中心', '0571-88880013', '临平区', '冯经理', ['haoka', 'broadband_new_card']],
    ['钱塘宽带工作室', '0571-88880014', '钱塘区', '蒋经理', ['broadband_new_card', 'broadband_no_card']],
    ['西湖文三营业厅', '0571-88880015', '西湖区', '沈经理', ['haoka', 'broadband_new_card', 'broadband_no_card']],
    ['滨江网商服务站', '0571-88880016', '滨江区', '韩经理', ['broadband_no_card']],
    ['余杭仓前门店', '0571-88880017', '余杭区', '杨经理', ['haoka']],
    ['拱墅莫干山店', '0571-88880018', '拱墅区', '朱经理', ['haoka', 'broadband_new_card']],
    ['萧山市心路店', '0571-88880019', '萧山区', '秦经理', ['broadband_new_card']],
    ['上城延安路店', '0571-88880020', '上城区', '许经理', ['haoka', 'broadband_no_card']],
    ['临平停用门店', '0571-88880021', '临平区', '何经理', ['haoka']],
  ]
  return rows.map((r, i) => ({
    id: `m${i + 11}`,
    name: r[0],
    phone: r[1],
    province: '浙江省',
    city: '杭州市',
    district: r[2],
    address: `${r[2].replace(/区$/, '')}示范路${i + 1}号`,
    contact: r[3],
    bizTypes: r[4],
    mpDisplayName: r[0],
    status: (i === 10 ? 'disabled' : 'active') as EnableStatus,
  }))
}

export function extraTechnicians(): Technician[] {
  const rows = [
    ['孙师傅', '13600004444', '拱墅区', 'm11', '拱墅号卡驿站', ['haoka']],
    ['周师傅', '13600005555', '上城区', 'm12', '上城通信行', ['haoka', 'broadband_new_card']],
    ['吴师傅', '13600006666', '临平区', 'm13', '临平号卡中心', ['haoka']],
    ['郑师傅', '13600007777', '钱塘区', 'm14', '钱塘宽带工作室', ['haoka', 'broadband_new_card']],
    ['冯师傅', '13600008888', '西湖区', 'm15', '西湖文三营业厅', ['broadband_new_card']],
    ['陈师傅', '13600009999', '滨江区', 'm16', '滨江网商服务站', ['haoka', 'broadband_new_card']],
    ['褚师傅', '13600010000', '余杭区', 'm17', '余杭仓前门店', ['broadband_new_card']],
    ['卫师傅', '13600011111', '拱墅区', 'm18', '拱墅莫干山店', ['haoka']],
    ['蒋师傅', '13600012222', '萧山区', 'm19', '萧山市心路店', ['haoka']],
    ['沈师傅', '13600013333', '上城区', 'm20', '上城延安路店', ['broadband_new_card']],
    ['韩师傅', '13600014444', '临平区', 'm21', '临平停用门店', ['haoka']],
  ] as const
  return rows.map((r, i) => ({
    id: `t${i + 4}`,
    name: r[0],
    phone: r[1],
    province: '浙江省',
    city: '杭州市',
    district: r[2],
    merchantId: r[3],
    merchantName: r[4],
    skills: [...r[5]] as Technician['skills'],
    status: (i === 10 ? 'disabled' : 'active') as EnableStatus,
  }))
}

export function extraAppUsers(): AppUser[] {
  const genders: AppUser['gender'][] = ['男', '女', '保密']
  return Array.from({ length: 28 }, (_, i) => ({
    id: `u${i + 7}`,
    nickname: names[i % names.length] + (i > 14 ? '代理' : ''),
    phone: `1390000${pad(300 + i, 4)}`,
    email: i % 3 === 0 ? `user${i}@example.com` : '',
    gender: genders[i % 3],
    createdAt: dayTime(i + 3, 8),
    orderCount: (i % 5) + 1,
    status: (i % 9 === 0 ? 'disabled' : 'active') as EnableStatus,
  }))
}

export function extraFaqs(): FaqItem[] {
  const items: Array<[FaqItem['category'], string, string]> = [
    ['号卡', '可以指定上门时间吗？', '商家派单后，师傅会电话预约，可协商具体时段。'],
    ['号卡', '办卡需要带什么证件？', '请准备本人有效身份证原件，现场开户核验。'],
    ['宽带', '装机需要室内布线吗？', '视房屋情况，师傅现场确认；如需改线会提前告知。'],
    ['宽带', '光猫是租赁还是购买？', '以当地运营商规则为准，详情见套餐说明或咨询客服。'],
    ['订单', '如何修改上门地址？', '商家未接单前可联系客服修改；已派单请与商家协商。'],
    ['订单', '为什么一直待接单？', '可能暂无覆盖商家，客服会协助转派或沟通预计时效。'],
    ['账号', '忘记密码怎么办？', '在登录页使用短信验证码找回，或联系客服核验后重置。'],
    ['账号', '可以注销账号吗？', '请通过客服提交注销申请，我们将在核实后处理。'],
    ['号卡', '副卡怎么办理？', '部分融合套餐支持副卡，下单备注需求，商家会确认是否可办。'],
    ['宽带', '安装当天无人在家怎么办？', '请提前与师傅改约，避免空跑导致工单延误。'],
    ['订单', '已开户还能取消吗？', '开户后需与商家、运营商协商，可能产生已发生费用。'],
    ['账号', '昵称有敏感词限制吗？', '请使用真实友好昵称，违规昵称将被重置。'],
  ]
  return items.map((x, i) => ({
    id: `f${i + 7}`,
    category: x[0],
    question: x[1],
    answer: x[2],
    enabled: i !== 11,
    sort: i + 7,
  }))
}

export function extraFeedbacks(): FeedbackItem[] {
  const types: FeedbackItem['type'][] = ['功能建议', '体验问题', '订单相关', '其他']
  return Array.from({ length: 22 }, (_, i) => ({
    id: `fb${i + 4}`,
    type: types[i % 4],
    content: ['希望增加套餐对比', '列表加载有点慢', '订单状态看不懂', '建议增加夜间客服', '筛选条件希望记住'][i % 5] + `（示例 ${i + 1}）`,
    contact: `1380000${pad(400 + i, 4)}`,
    userName: names[i % names.length],
    createdAt: dayTime(i, 15),
    status: i % 3 === 0 ? 'handled' : 'pending',
  }))
}

export function extraAgents(): Agent[] {
  return Array.from({ length: 22 }, (_, i) => ({
    id: `a${i + 6}`,
    name: `${regions[i % regions.length]}${names[i % names.length]}代理`,
    phone: `1370000${pad(500 + i, 4)}`,
    contact: names[i % names.length],
    province: '浙江省',
    city: '杭州市',
    district: regions[i % regions.length],
    address: `${streets[i % streets.length]}${i + 1}号`,
    joinedAt: dayTime(i + 2, 10),
    orderCount: (i % 8) + 1,
    status: (i % 7 === 0 ? 'disabled' : 'active') as EnableStatus,
    remark: i % 7 === 0 ? '暂停合作' : undefined,
  }))
}

export function extraWarehouse(): WarehouseItem[] {
  return [
    { id: 'w4', productId: 'p9', productName: '联通大王卡 29元', sku: 'HK-LT-29', spec: '号卡实体卡', stock: 200, safetyStock: 40, location: '杭州仓 A-04', updatedAt: '2026-08-20 12:00:00' },
    { id: 'w5', productId: 'p10', productName: '电信星卡 39元', sku: 'HK-DX-39', spec: '号卡实体卡', stock: 64, safetyStock: 20, location: '杭州仓 A-05', updatedAt: '2026-08-19 12:00:00' },
    { id: 'w6', productId: 'p11', productName: '移动青春卡 29元', sku: 'HK-YD-29', spec: '号卡实体卡', stock: 15, safetyStock: 20, location: '宁波仓 A-01', updatedAt: '2026-08-18 12:00:00' },
    { id: 'w7', productId: 'p12', productName: '广电畅享卡 49元', sku: 'HK-GD-49', spec: '号卡实体卡', stock: 28, safetyStock: 12, location: '杭州仓 A-06', updatedAt: '2026-08-16 09:00:00' },
    { id: 'w8', productId: 'p18', productName: '电信黄金卡 99元', sku: 'HK-DX-99', spec: '号卡实体卡', stock: 40, safetyStock: 10, location: '杭州仓 A-07', updatedAt: '2026-08-12 08:00:00' },
    { id: 'w9', productId: 'p19', productName: '联通畅爽卡 79元', sku: 'HK-LT-79', spec: '号卡实体卡', stock: 8, safetyStock: 10, location: '宁波仓 A-02', updatedAt: '2026-08-15 09:00:00' },
    { id: 'w10', productId: 'p21', productName: '移动畅享卡 59元', sku: 'HK-YD-59', spec: '号卡实体卡', stock: 90, safetyStock: 20, location: '杭州仓 A-08', updatedAt: '2026-08-20 08:00:00' },
    { id: 'w11', productId: 'p22', productName: '电信流量王 69元', sku: 'HK-DX-69', spec: '号卡实体卡', stock: 55, safetyStock: 15, location: '宁波仓 A-03', updatedAt: '2026-08-13 08:00:00' },
    { id: 'w12', productId: 'p1', productName: '电信畅享卡 59元', sku: 'HK-DX-59-NB', spec: '号卡实体卡', stock: 33, safetyStock: 15, location: '宁波仓 A-04', updatedAt: '2026-08-17 12:00:00' },
    { id: 'w13', productId: 'p2', productName: '移动花卡 19元', sku: 'HK-YD-19-NB', spec: '号卡实体卡', stock: 72, safetyStock: 20, location: '宁波仓 A-05', updatedAt: '2026-08-14 08:00:00' },
  ]
}

export function extraStock(): StockRecord[] {
  const ops = ['客服小李', '客服小周', '客服小陈']
  const items = extraWarehouse()
  return Array.from({ length: 32 }, (_, i) => {
    const w = items[i % items.length]
    const type = i % 3 === 0 ? 'in' : 'out'
    return {
      id: `io${i + 5}`,
      type: type as 'in' | 'out',
      warehouseId: w.id,
      productId: w.productId,
      productName: w.productName,
      sku: w.sku,
      qty: type === 'in' ? 10 + (i % 20) : 1 + (i % 3),
      orderNo: type === 'out' ? `HK202608${pad(20 - (i % 10))}${pad(100 + i, 3)}` : undefined,
      operator: ops[i % 3],
      remark: type === 'in' ? '补货入库' : '订单出库',
      createdAt: dayTime(i, 13),
    }
  })
}
