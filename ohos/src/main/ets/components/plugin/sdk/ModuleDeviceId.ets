import { StorageManager } from './StorageManager';

const STORAGE_KEY_DEVICE_ID = 'countly_device_id';
const STORAGE_KEY_DEVICE_ID_TYPE = 'countly_device_id_type';

export class ModuleDeviceId {
  private storage: StorageManager;
  private deviceId: string = '';
  private deviceIdType: string = 'SDK_GENERATED';

  constructor(storage: StorageManager) {
    this.storage = storage;
  }

  async init(defaultDeviceId: string): Promise<void> {
    const storedId = await this.storage.getString(STORAGE_KEY_DEVICE_ID, '');
    const storedType = await this.storage.getString(STORAGE_KEY_DEVICE_ID_TYPE, 'SDK_GENERATED');
    if (storedId.length > 0) {
      this.deviceId = storedId;
      this.deviceIdType = storedType;
      return;
    }
    this.deviceId = defaultDeviceId;
    this.deviceIdType = 'SDK_GENERATED';
    await this.persist();
  }

  getID(): string {
    return this.deviceId;
  }

  getIDTypeForBridge(): string {
    if (this.deviceIdType === 'DEVELOPER_SUPPLIED') {
      return 'DS';
    }
    if (this.deviceIdType === 'TEMPORARY_ID') {
      return 'TID';
    }
    return 'SG';
  }

  async setID(newDeviceId: string): Promise<void> {
    this.deviceId = newDeviceId;
    this.deviceIdType = 'DEVELOPER_SUPPLIED';
    await this.persist();
  }

  async changeWithMerge(newDeviceId: string): Promise<void> {
    await this.setID(newDeviceId);
  }

  async changeWithoutMerge(newDeviceId: string): Promise<void> {
    await this.setID(newDeviceId);
  }

  async enableTemporaryIDMode(): Promise<void> {
    this.deviceIdType = 'TEMPORARY_ID';
    await this.persist();
  }

  private async persist(): Promise<void> {
    await this.storage.putString(STORAGE_KEY_DEVICE_ID, this.deviceId);
    await this.storage.putString(STORAGE_KEY_DEVICE_ID_TYPE, this.deviceIdType);
  }
}
