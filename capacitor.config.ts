import type { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'com.gemscan.app',
  appName: 'GemScan',
  webDir: 'out',
  server: {
    url: process.env.CAPACITOR_DEV_SERVER ?? undefined,
    cleartext: true,
  },
  plugins: {
    GemmaPlugin: {
      e2bModelId: 'mlx-community/gemma-4-e2b-it-4bit',
      distilbertModelId: 'GemScan/sms-triage-distilbert',
      confidenceThreshold: 0.75,
    },
    SplashScreen: {
      launchShowDuration: 0,
    },
  },
}

export default config
