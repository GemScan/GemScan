/* eslint-disable @typescript-eslint/no-explicit-any */
export const isNativePlatform = (): boolean => {
  return (
    typeof window !== 'undefined' &&
    typeof (window as any).Capacitor !== 'undefined' &&
    (window as any).Capacitor.isNativePlatform()
  )
}
