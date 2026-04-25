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
      e2bModelId: 'GemScan/gemma-4-e2b-it-GemScan-q4km',
      e4bModelId: 'GemScan/gemma-4-e4b-it-GemScan-q4km',
      distilbertModelId: 'GemScan/sms-triage-distilbert',
      confidenceThreshold: 0.75,
      e4bResidentAboveGB: 8,
    },
    SplashScreen: {
      launchShowDuration: 0,
    },
  },
}

export default config
