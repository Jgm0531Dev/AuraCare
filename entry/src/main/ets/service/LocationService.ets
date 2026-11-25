import { geoLocationManager } from '@kit.LocationKit';
import { abilityAccessCtrl, Context, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../util/Logger';

const TAG: string = 'LocationService';
const PERMISSIONS: Permissions[] = ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION'];
const LOCATE_TIMEOUT_MS: number = 15000;

/** Resultado de la ubicación para mostrar en el reloj. Nunca se envía a nadie. */
export enum LocationStatus {
  Off = 'off',
  NoPermission = 'no-permission',
  SystemDisabled = 'system-disabled',
  Locating = 'locating',
  Found = 'found',
  Timeout = 'timeout',
  Failed = 'failed'
}

export interface LocationResult {
  status: LocationStatus;
  latitude: number;
  longitude: number;
  /** Dirección legible si el geocodificador respondió (suele requerir red); '' si no. */
  address: string;
}

/**
 * Ubicación opcional (Ajustes). Permiso solo al activarla; lectura única al confirmarse una alerta.
 * Maneja: permiso denegado, ubicación del sistema apagada, tiempo agotado.
 */
class LocationService {
  private context: Context | undefined = undefined;

  init(context: Context): void {
    this.context = context;
  }

  hasPermission(): boolean {
    try {
      const manager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const tokenId: number = this.context?.applicationInfo.accessTokenId ?? 0;
      return manager.checkAccessTokenSync(tokenId, PERMISSIONS[0]) ===
        abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (err) {
      Logger.error(TAG, 'checkAccessTokenSync falló', err as Object);
      return false;
    }
  }

  /** Diálogo del sistema; true si al menos la ubicación aproximada quedó concedida. */
  async requestPermission(): Promise<boolean> {
    const context: Context | undefined = this.context;
    if (context === undefined) {
      return false;
    }
    try {
      const manager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const result = await manager.requestPermissionsFromUser(context, PERMISSIONS);
      return result.authResults.length > 0 && result.authResults[0] === 0;
    } catch (err) {
      Logger.error(TAG, 'requestPermissionsFromUser falló', err as Object);
      return false;
    }
  }

  async locate(): Promise<LocationResult> {
    const empty: LocationResult = { status: LocationStatus.Failed, latitude: 0, longitude: 0, address: '' };
    if (!this.hasPermission()) {
      empty.status = LocationStatus.NoPermission;
      return empty;
    }
    try {
      if (!geoLocationManager.isLocationEnabled()) {
        empty.status = LocationStatus.SystemDisabled;
        return empty;
      }
    } catch (err) {
      Logger.error(TAG, 'isLocationEnabled falló', err as Object);
    }
    let location: geoLocationManager.Location;
    try {
      const request: geoLocationManager.SingleLocationRequest = {
        locatingPriority: geoLocationManager.LocatingPriority.PRIORITY_LOCATING_SPEED,
        locatingTimeoutMs: LOCATE_TIMEOUT_MS
      };
      location = await geoLocationManager.getCurrentLocation(request);
    } catch (err) {
      Logger.error(TAG, 'getCurrentLocation falló', err as Object);
      // 3301200: tiempo agotado / sin resultado; 3301100: interruptor del sistema apagado.
      const code: number = (err as BusinessError).code ?? 0;
      empty.status = code === 3301100 ? LocationStatus.SystemDisabled :
        (code === 3301200 ? LocationStatus.Timeout : LocationStatus.Failed);
      return empty;
    }
    const result: LocationResult = {
      status: LocationStatus.Found,
      latitude: location.latitude,
      longitude: location.longitude,
      address: ''
    };
    result.address = await this.reverseGeocode(location.latitude, location.longitude);
    return result;
  }

  private async reverseGeocode(latitude: number, longitude: number): Promise<string> {
    try {
      if (!geoLocationManager.isGeocoderAvailable()) {
        return '';
      }
      const addresses: geoLocationManager.GeoAddress[] = await geoLocationManager.getAddressesFromLocation({
        latitude: latitude, longitude: longitude, maxItems: 1
      });
      if (addresses.length === 0) {
        return '';
      }
      return addresses[0].placeName ?? '';
    } catch (err) {
      // Sin red el geocodificador suele fallar: se muestran solo las coordenadas.
      Logger.warn(TAG, 'getAddressesFromLocation sin resultado; solo coordenadas');
      return '';
    }
  }
}

export const locationService: LocationService = new LocationService();
