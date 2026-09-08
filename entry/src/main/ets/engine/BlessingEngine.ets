import { util } from '@kit.ArkTS'

const FALLBACK_BLESSING = '麻神保佑，今日手气旺旺旺！'

export class BlessingEngine {
  private blessings: Record<string, string[]> = {}
  private isLoaded: boolean = false

  async loadBlessings(context: Context): Promise<void> {
    try {
      const rawData = await context.resourceManager.getRawFileContent('blessings.json')
      const decoder = new util.TextDecoder('utf-8')
      const jsonStr = decoder.decodeToString(rawData)
      const parsed: Record<string, string[]> = JSON.parse(jsonStr)
      this.blessings = parsed
      this.isLoaded = true
    } catch (err) {
      console.error('Failed to load blessings:', JSON.stringify(err))
      this.blessings = {}
    }
  }

  getBlessing(deityId: number, userName: string): string {
    if (!this.isLoaded) {
      return `${userName}，${FALLBACK_BLESSING}`
    }

    const deityBlessings = this.blessings[String(deityId)]
    if (!deityBlessings || deityBlessings.length === 0) {
      return `${userName}，${FALLBACK_BLESSING}`
    }

    const index = Math.floor(Math.random() * deityBlessings.length)
    const template = deityBlessings[index]
    return template.replace(/【祈福者】/g, userName)
  }
}