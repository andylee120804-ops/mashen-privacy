export enum ParticleType {
  GOLD = 'gold',
  SMOKE = 'smoke',
  FIREWORK = 'firework'
}

@Component
export struct ParticleCanvas {
  @Prop particleType: ParticleType = ParticleType.GOLD
  @Prop isActive: boolean = false
  @State private particleCount: number = 0

  aboutToAppear(): void {
    switch (this.particleType) {
      case ParticleType.GOLD:
        this.particleCount = 30
        break
      case ParticleType.SMOKE:
        this.particleCount = 20
        break
      case ParticleType.FIREWORK:
        this.particleCount = 50
        break
    }
  }

  build() {
    if (this.isActive) {
      Particle({
        particles: Array.from({ length: this.particleCount }, (_, i: number) => ({
          emitter: this.getEmitterConfig(i)
        }))
      })
        .width('100%')
        .height('100%')
    }
  }

  private getEmitterConfig(_index: number): ParticleEmitter {
    const baseConfig: ParticleEmitter = {
      particle: {
        type: ParticleType.POINT,
        config: {
          radius: { range: [1, 3], value: undefined },
          color: this.getColor()
        },
        count: { range: [1, 3], value: undefined }
      },
      emitRate: { range: [5, 15], value: undefined },
      position: { x: '50%', y: '50%' },
      lifeTime: { range: [500, 1500], value: undefined }
    }
    return baseConfig
  }

  private getColor(): string {
    switch (this.particleType) {
      case ParticleType.GOLD:
        return '#f9ca24'
      case ParticleType.SMOKE:
        return 'rgba(200, 200, 200, 0.3)'
      case ParticleType.FIREWORK:
        return '#e74c3c'
    }
  }
}