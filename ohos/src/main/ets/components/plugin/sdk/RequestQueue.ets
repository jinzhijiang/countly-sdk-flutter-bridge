import http from '@ohos.net.http';
import { CountlyConfig } from './CountlyConfig';
import { StorageManager } from './StorageManager';
import { DeviceInfoProvider } from './DeviceInfo';
import { CountlyLogger } from './CountlyLogger';

const STORAGE_KEY_REQUEST_QUEUE = 'countly_request_queue_v1';
const COUNTLY_SDK_VERSION = '26.1.0-ohos';

export class RequestQueue {
  private config: CountlyConfig;
  private storage: StorageManager;
  private deviceInfo: DeviceInfoProvider;
  private queue: Array<string> = [];

  constructor(config: CountlyConfig, storage: StorageManager, deviceInfo: DeviceInfoProvider) {
    this.config = config;
    this.storage = storage;
    this.deviceInfo = deviceInfo;
  }

  async init(): Promise<void> {
    const queueText = await this.storage.getString(STORAGE_KEY_REQUEST_QUEUE, '[]');
    this.queue = this.parseQueue(queueText);
  }

  async sendOrQueue(params: Map<string, string>): Promise<void> {
    const merged = this.buildBaseParams();
    params.forEach((value: string, key: string) => {
      merged.set(key, value);
    });
    const bodyWithoutChecksum = this.encodeParams(merged);
    const body = this.withChecksum(bodyWithoutChecksum);
    CountlyLogger.info('sendOrQueue body=' + body);
    const sent = await this.sendBody(body);
    if (!sent) {
      CountlyLogger.warn('send failed, queued');
      this.queue.push(body);
      await this.persistQueue();
    }
  }

  async flushQueue(): Promise<void> {
    if (this.queue.length === 0) {
      return;
    }
    const pending: Array<string> = [];
    for (let i = 0; i < this.queue.length; i++) {
      const body = this.queue[i];
      const sent = await this.sendBody(body);
      if (!sent) {
        CountlyLogger.warn('flush one request failed');
        pending.push(body);
      }
    }
    this.queue = pending;
    await this.persistQueue();
  }

  async clearQueue(): Promise<void> {
    this.queue = [];
    await this.persistQueue();
  }

  private buildBaseParams(): Map<string, string> {
    const params: Map<string, string> = new Map<string, string>();
    const now = Date.now();
    const timestamp = Math.floor(now / 1000).toString();
    params.set('app_key', this.config.appKey);
    params.set('device_id', this.config.deviceID);
    params.set('timestamp', timestamp);
    params.set('sdk_name', 'ohos_native_harmony');
    params.set('sdk_version', COUNTLY_SDK_VERSION);
    params.set('hour', new Date(now).getHours().toString());
    params.set('dow', new Date(now).getDay().toString());
    params.set('metrics', this.deviceInfo.buildMetricsJson());
    if (this.config.locationCountryCode.length > 0) {
      params.set('country_code', this.config.locationCountryCode);
    }
    if (this.config.locationCity.length > 0) {
      params.set('city', this.config.locationCity);
    }
    if (this.config.locationIpAddress.length > 0) {
      params.set('ip_address', this.config.locationIpAddress);
    }
    if (this.config.locationGpsCoordinates.length > 0) {
      params.set('location', this.config.locationGpsCoordinates);
    }
    return params;
  }

  private encodeParams(params: Map<string, string>): string {
    const parts: Array<string> = [];
    params.forEach((value: string, key: string) => {
      parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(value));
    });
    return parts.join('&');
  }

  private withChecksum(body: string): string {
    const salt = this.config.tamperingProtectionSalt;
    if (salt.length === 0) {
      return body;
    }
    const checksum = this.sha256(body + salt);
    return body + '&checksum256=' + checksum;
  }

  private async sendBody(body: string): Promise<boolean> {
    const request = http.createHttp();
    const url = this.buildRequestUrl();
    try {
      CountlyLogger.info('sending to ' + url);
      const response = await request.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        connectTimeout: 10000,
        readTimeout: 10000,
        extraData: body
      });
      request.destroy();
      CountlyLogger.info('response=' + response.responseCode.toString());
      return response.responseCode >= 200 && response.responseCode < 300;
    } catch (_) {
      request.destroy();
      CountlyLogger.error('network request exception');
      return false;
    }
  }

  private buildRequestUrl(): string {
    if (this.config.serverURL.endsWith('/i')) {
      return this.config.serverURL;
    }
    if (this.config.serverURL.endsWith('/')) {
      return this.config.serverURL + 'i';
    }
    return this.config.serverURL + '/i';
  }

  private parseQueue(queueText: string): Array<string> {
    try {
      const parsed = JSON.parse(queueText) as Object;
      if (Array.isArray(parsed)) {
        const parsedList = parsed as Array<Object>;
        const queue: Array<string> = [];
        for (let i = 0; i < parsedList.length; i++) {
          const value = parsedList[i];
          if (typeof value === 'string') {
            queue.push(value);
          }
        }
        return queue;
      }
    } catch (_) {
    }
    return [];
  }

  private async persistQueue(): Promise<void> {
    await this.storage.putString(STORAGE_KEY_REQUEST_QUEUE, JSON.stringify(this.queue));
  }

  // SHA-256 implementation for Countly checksum256.
  private sha256(ascii: string): string {
    const rightRotate = (value: number, amount: number): number => {
      return (value >>> amount) | (value << (32 - amount));
    };

    const mathPow = Math.pow;
    const maxWord = mathPow(2, 32);
    const lengthProperty = 'length';
    let i: number;
    let j: number;
    let result = '';

    const words: Array<number> = [];
    const asciiBitLength = ascii[lengthProperty] * 8;

    const hash: Array<number> = [];
    const k: Array<number> = [];
    let primeCounter = 0;
    const isComposite: Array<number> = [];
    for (let candidate = 2; primeCounter < 64; candidate++) {
      if (isComposite[candidate] !== 1) {
        for (i = 0; i < 313; i += candidate) {
          isComposite[i] = 1;
        }
        hash[primeCounter] = (mathPow(candidate, 0.5) * maxWord) | 0;
        k[primeCounter++] = (mathPow(candidate, 1 / 3) * maxWord) | 0;
      }
    }

    ascii += '\x80';
    while (ascii[lengthProperty] % 64 - 56 !== 0) {
      ascii += '\x00';
    }
    for (i = 0; i < ascii[lengthProperty]; i++) {
      j = ascii.charCodeAt(i);
      words[i >> 2] |= j << ((3 - i) % 4) * 8;
    }
    words[words[lengthProperty]] = ((asciiBitLength / maxWord) | 0);
    words[words[lengthProperty]] = (asciiBitLength);

    for (j = 0; j < words[lengthProperty];) {
      const w: Array<number> = words.slice(j, j += 16);
      const oldHash: Array<number> = hash.slice(0);
      for (i = 0; i < 64; i++) {
        const w15 = w[i - 15];
        const w2 = w[i - 2];
        const a = hash[0];
        const e = hash[4];
        const temp1 = hash[7]
          + (rightRotate(e, 6) ^ rightRotate(e, 11) ^ rightRotate(e, 25))
          + ((e & hash[5]) ^ ((~e) & hash[6]))
          + k[i]
          + (w[i] = (i < 16) ? w[i] : (
            w[i - 16]
            + (rightRotate(w15, 7) ^ rightRotate(w15, 18) ^ (w15 >>> 3))
            + w[i - 7]
            + (rightRotate(w2, 17) ^ rightRotate(w2, 19) ^ (w2 >>> 10))
          ) | 0);
        const temp2 = (rightRotate(a, 2) ^ rightRotate(a, 13) ^ rightRotate(a, 22))
          + ((a & hash[1]) ^ (a & hash[2]) ^ (hash[1] & hash[2]));

        hash.unshift((temp1 + temp2) | 0);
        hash[4] = (hash[4] + temp1) | 0;
        hash.pop();
      }
      for (i = 0; i < 8; i++) {
        hash[i] = (hash[i] + oldHash[i]) | 0;
      }
    }

    for (i = 0; i < 8; i++) {
      for (j = 3; j + 1; j--) {
        const b = (hash[i] >> (j * 8)) & 255;
        result += ((b < 16) ? 0 : '') + b.toString(16);
      }
    }
    return result;
  }
}
