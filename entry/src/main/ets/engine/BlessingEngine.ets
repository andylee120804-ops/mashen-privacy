// entry/src/main/ets/engine/BlessingEngine.ets
import { resourceManager } from '@kit.LocalizationKit'
import { util } from '@kit.ArkTS'

export class BlessingEngine {
  private blessings: Record<string, string[]> = {}

  /**
   * 加载祝福语库（应在应用启动时调用一次）
   */
  async loadBlessings(context: Context): Promise<void> {
    try {
      const rawData = await context.resourceManager.getRawFileContent('blessings.json')
      const decoder = new util.TextDecoder('utf-8')
      const jsonStr = decoder.decodeWithStream(rawData)
      this.blessings = JSON.parse(jsonStr)
    } catch (err) {
      console.error('Failed to load blessings:', JSON.stringify(err))
      this.blessings = {}
    }
  }

  /**
   * 根据财神ID生成祝福语
   */
  getBlessing(deityId: number, userName: string): string {
    const deityBlessings = this.blessings[String(deityId)]
    if (!deityBlessings || deityBlessings.length === 0) {
      return `${userName}，麻神保佑，今日手气旺旺旺！`
    }

    const index = Math.floor(Math.random() * deityBlessings.length)
    const template = deityBlessings[index]
    return template.replace(/【祈福者】/g, userName)
  }
}