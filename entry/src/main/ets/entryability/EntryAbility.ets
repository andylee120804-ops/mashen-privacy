import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // App initialization
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