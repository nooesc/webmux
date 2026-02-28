import type { CapacitorConfig } from '@capacitor/cli';

const config = {
  appId: 'com.webmux.app',
  appName: 'WebMux',
  webDir: 'dist',
  cleartext: true,
  server: {
    androidScheme: 'http'
  }
} as CapacitorConfig;

export default config;
