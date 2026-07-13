import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { BlessingEngine } from '../engine/BlessingEngine'

export default class EntryAbility extends UIAbility {
  private blessingEngine: BlessingEngine = new BlessingEngine()

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    await this.blessingEngine.loadBlessings(this.context)
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/HomePage', (err) => {
      if (err.code) {
        console.error('Failed to load content:', JSON.stringify(err))
      }
    })
  }

  onBackground(): void {
    // Release audio resources
  }

  onDestroy(): void {
    // Release all resources
  }
}