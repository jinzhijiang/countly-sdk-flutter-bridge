import { CountlyConfig } from './CountlyConfig';

interface UserLocationPayload {
  countryCode?: string;
  city?: string;
  gpsCoordinates?: string;
  ipAddress?: string;
}

export class ModuleLocation {
  private config: CountlyConfig;

  constructor(config: CountlyConfig) {
    this.config = config;
  }

  setLocation(countryCode: string, city: string, gpsCoordinates: string, ipAddress: string): void {
    this.config.locationCountryCode = countryCode;
    this.config.locationCity = city;
    this.config.locationGpsCoordinates = gpsCoordinates;
    this.config.locationIpAddress = ipAddress;
  }

  setUserLocation(locationRaw: Object): void {
    const payload = locationRaw as UserLocationPayload;
    this.config.locationCountryCode = payload.countryCode != null ? payload.countryCode : '';
    this.config.locationCity = payload.city != null ? payload.city : '';
    this.config.locationGpsCoordinates = payload.gpsCoordinates != null ? payload.gpsCoordinates : '';
    this.config.locationIpAddress = payload.ipAddress != null ? payload.ipAddress : '';
  }

  disableLocation(): void {
    this.config.locationDisabled = true;
    this.config.locationCountryCode = '';
    this.config.locationCity = '';
    this.config.locationGpsCoordinates = '';
    this.config.locationIpAddress = '';
  }
}
