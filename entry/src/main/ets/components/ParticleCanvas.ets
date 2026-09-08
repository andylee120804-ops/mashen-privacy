export enum ParticleType {
  GOLD = 'gold',
  SMOKE = 'smoke',
  FIREWORK = 'firework'
}

@Component
export struct ParticleCanvas {
  @Prop particleType: ParticleType = ParticleType.GOLD
  @Prop isActive: boolean = false

  build() {
    if (this.isActive) {
      Stack() {
        // 用基础圆形模拟粒子效果，避开 Particle 组件 API 兼容问题
        // 精简至 6 个粒子，降低渲染树节点数
        Circle({ width: 4, height: 4 })
          .fill(this.getColor())
          .opacity(0.8)
          .position({ x: '18%', y: '28%' })
        Circle({ width: 6, height: 6 })
          .fill(this.getColor())
          .opacity(0.6)
          .position({ x: '52%', y: '18%' })
        Circle({ width: 3, height: 3 })
          .fill(this.getColor())
          .opacity(0.9)
          .position({ x: '72%', y: '38%' })
        Circle({ width: 5, height: 5 })
          .fill(this.getColor())
          .opacity(0.5)
          .position({ x: '28%', y: '58%' })
        Circle({ width: 4, height: 4 })
          .fill(this.getColor())
          .opacity(0.7)
          .position({ x: '62%', y: '68%' })
        Circle({ width: 3, height: 3 })
          .fill(this.getColor())
          .opacity(0.8)
          .position({ x: '82%', y: '52%' })
      }
      .width('100%')
      .height('100%')
    }
  }

  private getColor(): string {
    if (this.particleType === ParticleType.GOLD) {
      return '#f9ca24'
    }
    if (this.particleType === ParticleType.SMOKE) {
      return 'rgba(200, 200, 200, 0.3)'
    }
    return '#e74c3c'
  }
}
