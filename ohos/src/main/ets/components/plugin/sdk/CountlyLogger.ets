export class CountlyLogger {
  private static enabled: boolean = false;

  static setEnabled(enabled: boolean): void {
    CountlyLogger.enabled = enabled;
  }

  static isEnabled(): boolean {
    return CountlyLogger.enabled;
  }

  static info(message: string): void {
    if (!CountlyLogger.enabled) {
      return;
    }
    console.info('[CountlyOHOS] ' + message);
  }

  static warn(message: string): void {
    if (!CountlyLogger.enabled) {
      return;
    }
    console.warn('[CountlyOHOS] ' + message);
  }

  static error(message: string): void {
    if (!CountlyLogger.enabled) {
      return;
    }
    console.error('[CountlyOHOS] ' + message);
  }
}
