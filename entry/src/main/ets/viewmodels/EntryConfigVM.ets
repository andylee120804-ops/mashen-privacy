// entry/src/main/ets/viewmodels/EntryConfigVM.ets
// 界面定制：可配置入口的 Tab 开关与排序（v1.3.0 个性化显示）。
// 祈福（固定第一个 Tab）与我的（固定最后一个 Tab）不在此配置，不可隐藏。
import { preferences } from '@kit.ArkData'

/** 可配置入口静态定义 */
export interface EntryDef {
  id: string
  icon: string
  title: string
}

/** 入口运行时配置项 */
export interface EntryItem {
  id: string
  enabled: boolean   // 是否作为底部 Tab 显示
  order: number       // 排序权重（越小越靠前，Tab 与「我的入口」共用）
}

/**
 * 入口池（id → 页面组件映射见 MainTabs/EntryShell）。
 * 财神历·神诞已并入运势·黄历页（v1.3.0 反馈），不再作为独立入口。
 * 默认 order：fortune 置顶「我的入口」第 1 条；默认 Tab = 求签 + 木鱼。
 */
export const ENTRY_POOL: EntryDef[] = [
  { id: 'fortune', icon: '🗓️', title: '运势·黄历' },
  { id: 'qiuqian', icon: '🎋', title: '求签' },
  { id: 'muyu', icon: '🪵', title: '木鱼' },
  { id: 'wishwall', icon: '🙏', title: '还愿心愿墙' },
  { id: 'leaderboard', icon: '🏆', title: '祈福排行榜' },
  { id: 'encyclopedia', icon: '📜', title: '财神百科' }
]

/** 中间可配置 Tab 上限（底部导航最多 5 项：祈福 + 3 + 我的） */
const MAX_TABS = 3
const PREF_NAME = 'mashen_entry_prefs'
const KEY_ENTRY_CONFIG = 'entryConfig'
/** AppStorage 版本信号：UI v1 下 @StorageLink 只观察顶层键，@Observed 嵌套属性
 *  变更不会自动通知读取方（MainTabs 的 Tab 列表等），每次持久化变更后 +1，
 *  各消费页以 @StorageLink('entryConfigRev') + @Watch 重取派生数据。 */
const KEY_CONFIG_REV = 'entryConfigRev'

/** 默认配置：qiuqian/muyu 开启，其余走「我的」页（加载时以池为准合并，忽略旧配置中已下线入口） */
const DEFAULT_ITEMS: EntryItem[] = [
  { id: 'fortune', enabled: false, order: 1 },
  { id: 'qiuqian', enabled: true, order: 2 },
  { id: 'muyu', enabled: true, order: 3 },
  { id: 'wishwall', enabled: false, order: 4 },
  { id: 'leaderboard', enabled: false, order: 5 },
  { id: 'encyclopedia', enabled: false, order: 6 }
]

@Observed
export class EntryConfigVM {
  items: EntryItem[] = DEFAULT_ITEMS.map((it: EntryItem): EntryItem => {
    return { id: it.id, enabled: it.enabled, order: it.order }
  })
  private dataPrefs: preferences.Preferences | null = null

  async initialize(context: Context): Promise<void> {
    this.dataPrefs = await preferences.getPreferences(context, PREF_NAME)
    try {
      const savedStr = await this.dataPrefs.get(KEY_ENTRY_CONFIG, '') as string
      if (savedStr === '') {
        return
      }
      const saved: EntryItem[] = JSON.parse(savedStr)
      if (!Array.isArray(saved) || saved.length === 0) {
        return
      }
      // 以池为准合并：新增入口补默认值，已下线入口忽略
      this.items = ENTRY_POOL.map((def: EntryDef): EntryItem => {
        const found = saved.find((it: EntryItem): boolean => it.id === def.id)
        if (found) {
          return { id: found.id, enabled: found.enabled === true, order: found.order }
        }
        const fallback = DEFAULT_ITEMS.find((it: EntryItem): boolean => it.id === def.id)
        if (fallback) {
          return { id: fallback.id, enabled: fallback.enabled, order: fallback.order }
        }
        return { id: def.id, enabled: false, order: 99 }
      })
    } catch (err) {
      console.error('[EntryConfigVM] Failed to load prefs:', JSON.stringify(err))
    }
    this.notifyChanged()
  }

  /** 条目变更信号：写 AppStorage rev，消费页 @Watch 后重建派生 UI（见 KEY_CONFIG_REV 注释） */
  private notifyChanged(): void {
    try {
      const cur: number = AppStorage.get<number>(KEY_CONFIG_REV) ?? 0
      AppStorage.setOrCreate(KEY_CONFIG_REV, cur + 1)
    } catch (err) {
      console.error('[EntryConfigVM] notifyChanged failed:', JSON.stringify(err))
    }
  }

  /** 开关入口的 Tab 显示；开启第 MAX_TABS+1 个时拒绝并返回 false */
  setEnabled(id: string, on: boolean): boolean {
    if (on && this.tabEnabledCount() >= MAX_TABS) {
      return false
    }
    this.items = this.items.map((it: EntryItem): EntryItem => {
      if (it.id === id) {
        return { id: it.id, enabled: on, order: it.order }
      }
      return it
    })
    this.persist()
    this.notifyChanged()
    return true
  }

  /** 长按拖拽排序：把 order 升序列表中的 fromIdx 移到 toIdx（其余依次顺延/前移） */
  move(fromIdx: number, toIdx: number): void {
    if (fromIdx === toIdx) {
      return
    }
    const sorted = this.getSortedItems()
    if (fromIdx < 0 || fromIdx >= sorted.length || toIdx < 0 || toIdx >= sorted.length) {
      return
    }
    const arr = sorted.map((it: EntryItem): EntryItem => {
      return { id: it.id, enabled: it.enabled, order: it.order }
    })
    const moved: EntryItem = arr.splice(fromIdx, 1)[0]
    arr.splice(toIdx, 0, moved)
    this.items = arr.map((it: EntryItem, i: number): EntryItem => {
      return { id: it.id, enabled: it.enabled, order: i + 1 }
    })
    this.persist()
    this.notifyChanged()
  }

  /** 与全量排序列表中的相邻项交换 order；dir=-1 上移，1 下移 */
  swap(id: string, dir: number): void {
    const sorted = this.getSortedItems()
    const idx = sorted.findIndex((it: EntryItem): boolean => it.id === id)
    const j = idx + dir
    if (idx < 0 || j < 0 || j >= sorted.length) {
      return
    }
    const a = sorted[idx]
    const b = sorted[j]
    this.items = this.items.map((it: EntryItem): EntryItem => {
      if (it.id === a.id) {
        return { id: it.id, enabled: it.enabled, order: b.order }
      }
      if (it.id === b.id) {
        return { id: it.id, enabled: it.enabled, order: a.order }
      }
      return it
    })
    this.persist()
  }

  isFirst(id: string): boolean {
    const sorted = this.getSortedItems()
    return sorted.length > 0 && sorted[0].id === id
  }

  isLast(id: string): boolean {
    const sorted = this.getSortedItems()
    return sorted.length > 0 && sorted[sorted.length - 1].id === id
  }

  isTabOn(id: string): boolean {
    const it = this.items.find((item: EntryItem): boolean => item.id === id)
    return it ? it.enabled : false
  }

  tabEnabledCount(): number {
    return this.items.filter((it: EntryItem): boolean => it.enabled).length
  }

  /** 作为 Tab 显示的入口（按 order 升序），供 MainTabs 渲染 */
  getTabEntries(): EntryDef[] {
    const defs: EntryDef[] = []
    const enabled = [...this.items]
      .sort((a: EntryItem, b: EntryItem): number => a.order - b.order)
      .filter((it: EntryItem): boolean => it.enabled)
    for (const it of enabled) {
      const def = ENTRY_POOL.find((d: EntryDef): boolean => d.id === it.id)
      if (def) {
        defs.push(def)
      }
    }
    return defs
  }

  /** 全量配置项（按 order 升序），供「界面定制」与「我的入口」渲染 */
  getSortedItems(): EntryItem[] {
    return [...this.items].sort((a: EntryItem, b: EntryItem): number => a.order - b.order)
  }

  getIcon(id: string): string {
    const def = ENTRY_POOL.find((d: EntryDef): boolean => d.id === id)
    return def ? def.icon : ''
  }

  getTitle(id: string): string {
    const def = ENTRY_POOL.find((d: EntryDef): boolean => d.id === id)
    return def ? def.title : ''
  }

  private async persist(): Promise<void> {
    if (!this.dataPrefs) {
      return
    }
    try {
      await this.dataPrefs.put(KEY_ENTRY_CONFIG, JSON.stringify(this.items))
      await this.dataPrefs.flush()
    } catch (err) {
      console.error('[EntryConfigVM] Failed to persist:', JSON.stringify(err))
    }
  }
}
