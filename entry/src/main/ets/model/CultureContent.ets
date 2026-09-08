// entry/src/main/ets/model/CultureContent.ets
// 内容增强：每日求签（36 签）、财神文化百科、许愿快捷模板、祈福文化栏目。
// 全部为静态内容数据，纯本地，无云端依赖。审核 3.5 项「功能不足」的应对。

/** 签的吉凶等级 */
export enum SignLevel {
  TOP = '上上签',      // 金
  GOOD = '上吉签',     // 绿
  MID_GOOD = '中吉签', // 蓝
  MID = '中平签',      // 灰
  LOW = '下签'         // 红
}

/** 每日求签条目 */
export interface SignEntry {
  id: number          // 1-36
  level: SignLevel    // 吉凶等级
  title: string       // 四字签名
  poem: string        // 签诗（两句）
  interpretation: string // 解签（牌运/财运/事业）
  advice: string      // 行事建议
}

/** 求签记录条目（揭晓即自动记入，存本机 preferences，保留最近 100 条） */
export interface QiuRecord {
  recId: string       // 记录唯一 id（时间戳+随机）
  ts: number          // 求签时间戳
  sign: SignEntry     // 完整签快照（可回看签诗/解签/建议）
}

/** 财神百科条目 */
export interface DeityEntry {
  id: number            // 与 FIVE_DEITIES.id 一致
  name: string          // 财神名
  title: string         // 神职封号
  icon: string          // 图标
  direction: string     // 方位
  story: string         // 来历传说
  domain: string        // 掌管领域
  worship: string       // 祭拜要点
  tile: string          // 对应花色
}

/** 文化栏目短文 */
export interface CultureArticle {
  id: string
  title: string
  icon: string
  content: string
}

/** 许愿快捷模板（只保留麻将相关短句） */
export const WISH_TEMPLATES: string[] = [
  '想啥来啥',
  '把把自摸',
  '牌运亨通',
  '手气长红',
  '缺啥来啥',
  '连庄不断',
  '大杀四方'
]

/** 每日求签 36 签：按日期轮换，一日一签 */
export const SIGN_TABLE: SignEntry[] = [
  // ── 上上签（4）──
  { id: 1, level: SignLevel.TOP, title: '龙行天下', poem: '金龙出海风云起，万里鹏程任翱翔', interpretation: '手气如虹，牌运冲天。今日诸事顺遂，财星高照，宜大胆出手、乘胜追击。', advice: '该胡就胡，切勿手软；乘胜追击，一鼓作气。' },
  { id: 2, level: SignLevel.TOP, title: '五福临门', poem: '福星高照门庭旺，五路财神入梦来', interpretation: '百事顺心，八方来财。今日不仅牌运亨通，事业生活亦多贵人相助。', advice: '广结善缘，谦逊待人；见好即收，福报自长。' },
  { id: 3, level: SignLevel.TOP, title: '紫气东来', poem: '紫气东来盈满室，祥云瑞霭护君身', interpretation: '气运正盛，所向披靡。今日运势为全年高峰之一，宜把握重要决策。', advice: '静待时机，一举定局；稳中求进，大器晚成。' },
  { id: 4, level: SignLevel.TOP, title: '金榜题名', poem: '寒窗十载终不负，金榜题名天下知', interpretation: '付出终有回报，今日宜考试、签约、谈合作，皆大有可为。', advice: '厚积薄发，一鸣惊人；功成之日，勿忘初心。' },
  // ── 上吉签（6）──
  { id: 5, level: SignLevel.GOOD, title: '顺水行舟', poem: '顺水行舟千帆过，乘风破浪正当时', interpretation: '运势上扬，事半功倍。今日打牌手气平稳偏旺，财运渐进。', advice: '顺势而为，不逆不抢；稳扎稳打，自有进账。' },
  { id: 6, level: SignLevel.GOOD, title: '锦上添花', poem: '锦上添花花更艳，春风得意马蹄轻', interpretation: '已有之利将更上一层，今日适合加大投入、拓展人脉。', advice: '趁势加码，小试牛刀；人情往来，多为加分。' },
  { id: 7, level: SignLevel.GOOD, title: '鸿运当头', poem: '鸿运当头花正发，青云直上不须愁', interpretation: '今日运势上佳，牌局易出好牌，财运有意外之喜。', advice: '抓住早局，速战速决；莫贪连庄，落袋为安。' },
  { id: 8, level: SignLevel.GOOD, title: '鱼跃龙门', poem: '鱼跃龙门腾空起，一朝风云际会时', interpretation: '瓶颈将破，转机将至。今日宜尝试新思路、新打法。', advice: '破旧立新，敢想敢干；贵人相助，更上层楼。' },
  { id: 9, level: SignLevel.GOOD, title: '春暖花开', poem: '春暖花开香满径，蜂飞蝶舞自怡然', interpretation: '运势回暖，心情舒畅。今日人际和谐，牌友相处愉快，财运稳中向好。', advice: '和气生财，广结善缘；随缘而安，静待花开。' },
  { id: 10, level: SignLevel.GOOD, title: '万事亨通', poem: '万事亨通皆顺意，四方通达乐逍遥', interpretation: '诸事皆宜，无往不利。今日办事顺利，牌运财气俱佳。', advice: '宜行大事，宜赴约谈；日行一善，福报绵长。' },
  // ── 中吉签（10）──
  { id: 11, level: SignLevel.MID_GOOD, title: '云开见日', poem: '云开雾散见晴日，柳暗花明又一村', interpretation: '前路渐明，转机在望。今日虽有小波折，结局向好。', advice: '再坚持一刻，转机即现；勿因小挫而乱阵脚。' },
  { id: 12, level: SignLevel.MID_GOOD, title: '枯木逢春', poem: '枯木逢春犹再发，人逢喜事精神爽', interpretation: '旧事可成，故人重逢。今日宜处理遗留问题、修复旧关系。', advice: '回访旧友，重启旧约；用心经营，必有所获。' },
  { id: 13, level: SignLevel.MID_GOOD, title: '步步高升', poem: '步步登高望远景，层层向上见新天', interpretation: '运势稳步上升，今日宜学习、积累、布局长远。', advice: '脚踏实地，步步为营；今日之勤，明日之果。' },
  { id: 14, level: SignLevel.MID_GOOD, title: '月朗星稀', poem: '月朗星稀清辉照，心地坦然福自来', interpretation: '心静则明，明则通。今日宜独处思考、复盘牌局。', advice: '少说多做，静观其变；心平气和，自有答案。' },
  { id: 15, level: SignLevel.MID_GOOD, title: '一帆风顺', poem: '一帆风顺千里行，百事如意万年春', interpretation: '行运平稳，无大波折。今日打牌小有盈余，办事顺遂。', advice: '按部就班，无需激进；细水长流，福泽绵长。' },
  { id: 16, level: SignLevel.MID_GOOD, title: '春风化雨', poem: '春风化雨润无声，润物细物含深情', interpretation: '以柔克刚，润物无声。今日宜以德服人、以静制动。', advice: '温柔处事，耐心待人；不争一时，赢在长远。' },
  { id: 17, level: SignLevel.MID_GOOD, title: '梅开二度', poem: '梅开二度香如故，老树新花别样红', interpretation: '旧事重启，别有天地。今日宜复盘再战，旧局可能翻盘。', advice: '不弃旧局，重燃信心；二度开花，香更胜初。' },
  { id: 18, level: SignLevel.MID_GOOD, title: '喜鹊登枝', poem: '喜鹊登枝报喜讯，好事临门不久时', interpretation: '佳音将至，喜事可期。今日宜关注消息、留意机会。', advice: '耳听八方，眼观六路；机会来时，当机立断。' },
  { id: 19, level: SignLevel.MID_GOOD, title: '金蝉脱壳', poem: '金蝉脱壳身轻健，留得青山任我行', interpretation: '断舍离而后生。今日宜放下包袱、轻装上阵。', advice: '弃车保帅，当断则断；留得青山，何愁柴烧。' },
  { id: 20, level: SignLevel.MID_GOOD, title: '水滴石穿', poem: '水滴石穿非一日，铁杵成针有恒心', interpretation: '坚持即胜利。今日宜持之以恒，勿因进度缓慢而放弃。', advice: '日拱一卒，功不唐捐；恒心所至，金石为开。' },
  // ── 中平签（10）──
  { id: 21, level: SignLevel.MID, title: '平湖秋月', poem: '平湖秋月空明净，波澜不惊自安然', interpretation: '运势平平，宜守不宜攻。今日打牌不输不赢，办事中规中矩。', advice: '以守为攻，不追不逃；平淡是真，安稳是福。' },
  { id: 22, level: SignLevel.MID, title: '守株待兔', poem: '守株待兔终非计，坐等天缘不如耕', interpretation: '被动等待难成事，今日宜主动出击、主动联络。', advice: '主动破局，勿空等待；行动之始，运之转也。' },
  { id: 23, level: SignLevel.MID, title: '邯郸学步', poem: '邯郸学步失其本，回归初心方得安', interpretation: '勿盲目模仿他人打法，今日宜回归自己的节奏。', advice: '做自己，走自己的路；适合的才是最好的。' },
  { id: 24, level: SignLevel.MID, title: '按部就班', poem: '按部就班循序进，不疾不徐自有成', interpretation: '一切照旧，平稳过渡。今日无大运亦无大厄，按计划行事即可。', advice: '维持节奏，勿生枝节；按部就班，水到渠成。' },
  { id: 25, level: SignLevel.MID, title: '雾里看花', poem: '雾里看花终隔纱，拨云见日待明时', interpretation: '当下局势不明，不宜轻举妄动。今日宜观望、调研、收集信息。', advice: '少下结论，多察实情；迷雾散尽，真相自现。' },
  { id: 26, level: SignLevel.MID, title: '塞翁失马', poem: '塞翁失马焉非福，祸福相依莫计较', interpretation: '得失不必挂怀，今日之失或为明日之得。', advice: '看淡输赢，放宽心态；祸福相依，泰然处之。' },
  { id: 27, level: SignLevel.MID, title: '三思后行', poem: '三思而后行无咎，谋定而动少悔恨', interpretation: '今日宜谨慎决策，打牌宜慢不宜急，办事宜细不宜粗。', advice: '谋定而后动，动则有章；宁慢勿错，宁稳勿躁。' },
  { id: 28, level: SignLevel.MID, title: '安居乐业', poem: '安居乐业心常泰，淡泊明志福自长', interpretation: '平淡是真，安稳为福。今日不宜折腾，守成即胜。', advice: '守好本分，护好家人；平淡日子，也是福气。' },
  { id: 29, level: SignLevel.MID, title: '螳螂捕蝉', poem: '螳螂捕蝉雀在后，收敛锋芒免是非', interpretation: '谨防算计与口舌，今日宜低调行事、少露锋芒。', advice: '财不露白，话不伤人；退一步海阔天空。' },
  { id: 30, level: SignLevel.MID, title: '隔岸观火', poem: '隔岸观火莫轻入，置身事外自安闲', interpretation: '他人纠纷勿卷入，今日宜置身事外、独善其身。', advice: '不站队，不掺和；明哲保身，静观其变。' },
  // ── 下签（6）──
  { id: 31, level: SignLevel.LOW, title: '逆水行舟', poem: '逆水行舟用力撑，一篙松劲退千寻', interpretation: '今日运势低迷，打牌易失手，宜小注试探、谨慎行事。', advice: '量力而行，少投少赌；稳住心态，明日再战。' },
  { id: 32, level: SignLevel.LOW, title: '风急浪高', poem: '风急浪高舟难渡，暂泊港湾待天晴', interpretation: '时运不济，不宜冒进。今日宜休整、避风头、养精蓄锐。', advice: '停一停，歇一歇；避过风头，再启征程。' },
  { id: 33, level: SignLevel.LOW, title: '明珠暗投', poem: '明珠暗投无人识，且待明主觅真珍', interpretation: '怀才不遇是暂时的，今日不宜强求认同，做好自己即可。', advice: '沉住气，蓄实力；真金不怕火炼，早晚发光。' },
  { id: 34, level: SignLevel.LOW, title: '节外生枝', poem: '节外生枝事多变，谨言慎行避是非', interpretation: '今日易生意外变故，打牌宜防点炮，办事宜留余地。', advice: '话到嘴边留三分，事到临头留一手。' },
  { id: 35, level: SignLevel.LOW, title: '镜花水月', poem: '镜花水月空欢喜，脚踏实地见真章', interpretation: '表象虚浮，不宜轻信。今日投资、承诺宜再三核实。', advice: '不信画饼，不贪便宜；脚踏实地，方有真成。' },
  { id: 36, level: SignLevel.LOW, title: '雨后初霁', poem: '雨后初霁彩虹现，否极泰来不久时', interpretation: '最难的时刻将过，黎明就在眼前。今日虽有小挫，转机已近。', advice: '咬牙坚持，再走一程；风雨过后，必有彩虹。' }
]

/** 财神百科（与 FIVE_DEITIES 对齐） */
export const DEITY_ENCYCLOPEDIA: DeityEntry[] = [
  {
    id: 1, name: '赵公明', title: '正财神 · 玄坛真君', icon: '🀄',
    direction: '中路',
    story: '赵公明为五路财神之首，又称「黑虎玄坛赵元帅」。相传他奉玉帝之命镇守中路，骑黑虎、执铁鞭，专司人间财帛。天下求财者皆先拜他，是公认的「天下第一财神」。',
    domain: '总领天下财源，护佑正财偏财、生意买卖、招财进宝',
    worship: '宜用三牲果品、香烛元宝；初一十五上香最佳；心诚则灵，忌心术不正',
    tile: '🀄 中发白'
  },
  {
    id: 2, name: '萧升', title: '招宝天尊', icon: '🀇',
    direction: '东路',
    story: '萧升原是峨眉山罗汉，手持「落宝金钱」，能收天下宝物。被封为东路财神，掌「招宝」之职，凡求财物入账、宝贝到手者多拜之。',
    domain: '招揽宝物、引财入局，利财宝收藏与意外之财',
    worship: '敬奉宝珠与铜钱，求财时心中默念所求明细，忌贪得无厌',
    tile: '🀇 条子'
  },
  {
    id: 3, name: '曹宝', title: '纳珍天尊', icon: '🀈',
    direction: '西路',
    story: '曹宝与萧升同拜于峨眉山，道号「纳珍」，掌「纳珍」之职，收聚世间奇珍异宝，护佑积聚财富、守财不散。',
    domain: '聚财守财、积少成多，利储蓄理财与家业兴旺',
    worship: '宜献珍宝金银类供品，供奉于家中西北方位，忌铺张浪费',
    tile: '🀈 筒子'
  },
  {
    id: 4, name: '陈九公', title: '招财使者', icon: '🀉',
    direction: '南路',
    story: '陈九公是赵公明座下大将，被封为南路财神「招财使者」，专管招财纳福，把四方财气招入家门，是生意人最爱拜的使者。',
    domain: '招揽生意、引客进门，利开张营业与销售推广',
    worship: '开张、搬家、签约前拜之最灵；供品宜用带「红」之物，忌小气吝啬',
    tile: '🀉 万子'
  },
  {
    id: 5, name: '姚少司', title: '利市仙官', icon: '🀅',
    direction: '北路',
    story: '姚少司同为赵公明麾下，被封为北路财神「利市仙官」，专司「利市」——买卖兴旺、货如轮转，是市井商贩最亲近的财神。',
    domain: '利市亨通、买卖兴隆，保交易顺利、顾客盈门',
    worship: '逢市集、交易日供奉；心念「利市」二字入定，忌失信于人',
    tile: '🀅 发财'
  }
]

/** 祈福文化栏目 */
export const CULTURE_ARTICLES: CultureArticle[] = [
  {
    id: 'incense_ritual', title: '上香礼仪', icon: '🪔',
    content: '上香前先净手，表示诚敬。三炷香代表「戒、定、慧」或「天、地、人」三才。插香时香须直立，香与香之间保持一指宽，谓之「香不过寸」。拜神时宜心无杂念，默念姓名与所求，忌喧哗嬉笑。'
  },
  {
    id: 'fortune_time', title: '求财时机', icon: '📅',
    content: '传统上，正月初五「迎财神」是一年求财最重要的日子，谓之「破五」——破除旧日晦气，迎接财神进门。日常求财则宜选逢五、逢十的吉日，或每日卯时（5-7 点）财气初升之时上香。'
  },
  {
    id: 'mahjong_culture', title: '麻将祈福习俗', icon: '🀄',
    content: '旧时打牌前有「拜牌神」之说：将牌在桌上顺时针转三圈，谓之「转运气」；摸牌前默念「自摸」，谓之「念力加持」。本应用取五路财神庇佑牌运之意，祈福后开局，愿您牌运亨通、见牌就胡。'
  },
  {
    id: 'kowtow_meaning', title: '磕头祈福的讲究', icon: '🙏',
    content: '磕头又称「叩首」，一叩首表敬意，三叩首表诚心，九叩首表至诚。俗谚「磕得响，福到堂」，磕头时心中默念所愿，额头触地时屏息凝神，起身后双手合十谢神。虔诚叩拜，自有回响。'
  }
]
