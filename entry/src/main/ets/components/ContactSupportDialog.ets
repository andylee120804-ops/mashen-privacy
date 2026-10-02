// entry/src/main/ets/components/ContactSupportDialog.ets
// 联系客服弹窗（审核问题1整改：应用内含付费项目，需在应用内提供客服联系方式）。
// 展示客服邮箱 + 两个动作：「复制邮箱」（pasteboard 本机复制）与「发送邮件」
// （startAbilityByType("mail") 拉起系统邮件应用，预填收件人/主题/正文）。
// 风格沿用 PrivacyDialog（深底 #1a1a0a + 金色描边 + 金色标题 + 米色正文），
// 文字对比度与 PrivacyDialog 同底同色，已过既有审核（见 wcag-contrast 规则）。
import { common } from '@kit.AbilityKit'
import { pasteboard, BusinessError } from '@kit.BasicServicesKit'

/** 客服邮箱：审核公开联系渠道，必须为真实可收件地址 */
export const SUPPORT_EMAIL: string = 'andyli0912@petalmail.com'

@CustomDialog
export struct ContactSupportDialog {
  controller: CustomDialogController

  /** 复制客服邮箱到剪贴板（setDataSync 同步写，失败立即 catch，成功后才 toast） */
  private copyEmail(): void {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, SUPPORT_EMAIL)
      pasteboard.getSystemPasteboard().setDataSync(data)
      this.getUIContext().getPromptAction().showToast({ message: '客服邮箱已复制 📋' })
    } catch (err) {
      console.error('[ContactSupport] copy email failed:', JSON.stringify(err))
      this.getUIContext().getPromptAction().showToast({ message: '复制失败，请重试' })
    }
  }

  /** 拉起系统邮件应用，预填收件人/主题/正文 */
  private sendEmail(): void {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const wantParam: Record<string, Object> = {
        'sceneType': 1,                                    // 1 = 发送邮件意图（文档默认值）
        'email': [encodeURI(SUPPORT_EMAIL)],               // 收件人（数组元素需 URL 编码）
        'subject': encodeURI('麻神保佑 · 用户反馈'),
        'body': encodeURI('您好，\n\n我想反馈一个问题：\n\n（请在此描述您遇到的问题，谢谢）\n\n——麻神保佑用户')
      }
      context.startAbilityByType('mail', wantParam, {
        onError: (code: number, name: string, message: string): void => {
          console.error('[ContactSupport] 拉起邮件应用失败 code=' + code + ' name=' + name + ' msg=' + message)
          this.getUIContext().getPromptAction().showToast({ message: '暂未检测到邮件应用，可点击「复制邮箱」后手动发送' })
        },
        onResult: (result: common.AbilityResult): void => {
          console.info('[ContactSupport] 邮件应用返回: ' + JSON.stringify(result))
        }
      }, (err: BusinessError): void => {
        // 起 mail 类型能力失败（如系统无邮件应用）：@since 11 回调式（兼容更广设备）
        if (err) {
          console.error('[ContactSupport] startAbilityByType callback err: ' + JSON.stringify(err))
          this.getUIContext().getPromptAction().showToast({ message: '暂未检测到邮件应用，可点击「复制邮箱」后手动发送' })
        }
      })
    } catch (err) {
      console.error('[ContactSupport] send email failed:', JSON.stringify(err))
      this.getUIContext().getPromptAction().showToast({ message: '暂未检测到邮件应用，可点击「复制邮箱」后手动发送' })
    }
  }

  build() {
    Column() {
      // ── 顶部红色装饰条 ──
      Row()
        .width('100%')
        .height(4)
        .backgroundColor('#c0392b')

      // ── 标题区 ──
      Text('📮  联系客服')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
        .letterSpacing(2)
        .margin({ top: 22, bottom: 6 })

      Text('遇有问题或疑问，请通过以下方式联系我们')
        .fontSize(12)
        .fontColor('rgba(253, 246, 227, 0.6)')
        .fontStyle(FontStyle.Italic)
        .margin({ bottom: 16 })

      // ── 分隔线 ──
      Row()
        .width('60%')
        .height(1)
        .backgroundColor('rgba(249, 202, 36, 0.25)')
        .margin({ bottom: 18 })

      // ── 客服邮箱（大字醒目展示，可直接阅读/记忆）──
      Text('客服邮箱')
        .fontSize(13)
        .fontColor('rgba(249, 202, 36, 0.8)')
        .margin({ bottom: 6 })
      Text(SUPPORT_EMAIL)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor('#fdf6e3')
        .textAlign(TextAlign.Center)
        .width('100%')
        .copyOption(CopyOptions.LocalDevice)  // 长按也可复制
        .margin({ bottom: 18 })

      // ── 动作按钮（复制 / 发送）──
      Row() {
        Button('📋 复制邮箱')
          .fontSize(14)
          .fontColor('#1a1a0a')
          .backgroundColor('rgba(253, 246, 227, 0.9)')
          .borderRadius(22)
          .height(42)
          .layoutWeight(1)
          .onClick(() => { this.copyEmail() })
        Button('✉️ 发送邮件')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a0a')
          .backgroundColor('#f9ca24')
          .borderRadius(22)
          .height(42)
          .layoutWeight(1)
          .margin({ left: 12 })
          .shadow({ radius: 10, color: 'rgba(249, 202, 36, 0.35)', offsetY: 2 })
          .onClick(() => { this.sendEmail() })
      }
      .width('100%')
      .margin({ bottom: 14 })

      // ── 说明 ──
      Text('工作日 48 小时内回复，感谢您的支持 🙏')
        .fontSize(11)
        .fontColor('rgba(253, 246, 227, 0.5)')
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ bottom: 16 })

      Button('关闭')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('rgba(253, 246, 227, 0.6)')
        .backgroundColor('rgba(255, 255, 255, 0.05)')
        .border({ width: 1, color: 'rgba(253, 246, 227, 0.2)', radius: 22 })
        .height(40)
        .padding({ left: 28, right: 28 })
        .margin({ bottom: 14 })
        .onClick(() => { this.controller.close() })
    }
    .width('82%')
    .backgroundColor('#1a1a0a')
    .borderRadius(16)
    .border({ width: 1.5, color: 'rgba(249, 202, 36, 0.3)' })
    .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.6)', offsetY: 6 })
    .clip(true)
  }
}
