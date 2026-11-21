# Estado EXTRA (feat/pantallas-extra)

## Hecho
- `fetch` + merge de `origin/main` (`b65dd84`) al inicio del pulido y de `2c9830d` en esta tarea; merge cerrado localmente en `359790e`.
- Pulido de las tres pantallas, con `BUILD SUCCESSFUL` tras cada bloque:
  - `d530d07` Rango: sin “En reposo”, textos cortos, barra 70cqw con trazo 13/14 base y extremos redondos, marcador mapeado al tramo 58-92 (o 60-100 en primer uso) y fijado en el extremo si sale de rango.
  - `64bdb23` Ficha médica: cruz médica, descripción corta, `WordBreak.NORMAL`, ancho 76cqw con margen para el indicador de página y tarjetas demo con scroll.
  - `3c978bc` Ajustes: engranaje, subtítulos “Pausa las alertas automáticas” y “Reenvío si nadie responde”, filas que ciclan y padding inferior 6cqw.
- Ajustes (`790a0aa`): las filas ciclan ahora con `Button` nativo y `@Event` en `ExtraSettingButton.ets`; los interruptores pasan por `ExtraSettingToggle.ets`. Desaparecieron los `@Builder` con parámetros por valor (`badge`, `rowContent`) que podían no refrescar. `onClick` registra el nombre de la fila con hilog antes de ejecutar y envuelve la acción en `try/catch`.
- Rango (`a4a945f`): `sx()` usa la misma escala 70cqw que la barra; al aparecer la barra se registran con hilog (dominio `A10A`, tag `RangePage`) las posiciones `x`/`y` y el progreso de 50, 78, 92 y 120 bpm.
- Ficha médica (`9369cac`): el círculo central vacío usa `SymbolGlyph(sys.symbol.cross_square_fill)` sobre fondo `app.color.card`, en lugar del carácter de teléfono.
- Defaults confirmados en `AppStore.ets`: `settings.exerciseMode = false` y `settings.batterySaver = false`. No se editó `AppStore.ets` ni ningún archivo de CORE.
- Encabezados unificados en `ExtraPageHeader.ets` con `SymbolGlyph` del SDK (`waveform_path_ecg_heart`, `cross_square_fill`, `gearshape`), mismo tamaño (`DesignTokens.headerIconSize`) y color (`app.color.accion_principal`).
- Textos nuevos en `resources/base/element/string_extra.json` (resources propios de EXTRA). No se tocó `PageHeader.ets`, `Index.ets`, `string.json` ni archivos de CORE.
- `DEBUG_LAYOUT=false` antes de cada commit; compilación `BUILD SUCCESSFUL` en cada bloque.

## En curso
- No existe temporizador que apague `exerciseMode` automáticamente a las 2 h: solo aparece en `AppStore.ets`, `EmergencyMachine.ets`, `EmergencyService.ets` y `MonitorPage.ets`, todos propiedad de CORE. EXTRA no los modifica; queda pendiente de CORE.
- Verificación táctil/visual en previsualizador o reloj: no disponible desde este entorno; `@Preview` no añadido. Los logs de `SettingsPage` y `ExtraSettingButton` permiten distinguir “no llegó el clic” de “cambió el valor y no refrescó”.
- Gestos `Scroll` ↔ `ArcSwiper`: ambos `nestedScroll` usan `SELF_FIRST`; no validado en runtime. Si al bajar/volver se bloquea el cambio de página, CORE debe ajustar `Index.ets` (EXTRA no lo toca).

## Siguiente
- En previsualizador: presionar y soltar sin mover el puntero sobre Sensibilidad y Tiempo entre avisos; revisar `previewer.log` para confirmar `onClick sensitivity`/`onClick notice` y los valores antes/después.
- Revisar los logs `RangePage` con 50/78/92/120 bpm y ajustar solo si el marcador queda fuera del tramo visible.
- Si aparece conflicto de gestos, registrar el caso para CORE y mantener este archivo actualizado con cada push de `feat/pantallas-extra`.

## >>> EXTRA: RealSensorProvider (tarea excepcional, solo archivo nuevo + este doc)
- Nuevo `entry/src/main/ets/service/RealSensorProvider.ets`, sin usarse todavía y con `BUILD SUCCESSFUL`. Implementa exactamente `SensorProvider` (`read`, `capabilities`, `setVariant`, `setCapabilities`, `release`) y no importa UI.
- Disponibilidad: `await sensor.getSensorList()` filtrando por `sensor.SensorId.HEART_RATE` y `SensorId.ACCELEROMETER`; nunca se llama a `sensor.on()` sin ese filtro previo.
- Solicitud de permiso en método propio, sin UI: `async requestPermission(context: Context): Promise<boolean>` usa `abilityAccessCtrl.requestPermissionsFromUser` con `ohos.permission.READ_HEALTH_DATA`.
- Estados: sensor ausente o sin datos en 10 s → `SensorStatus.Unavailable`; permiso denegado → `SensorStatus.PermissionRequired` (“Activar”, distinto de “No disponible”); con datos → `SensorStatus.Measuring`. En todos los fallos se emite el valor simulado del variante y solo se escribe hilog (sin errores visibles). `release()` hace `sensor.off()` de ambos sensores dentro de `try/catch`.
- Intervalos en nanosegundos: pulso `1000000000` ns (1 s) y acelerómetro `200000000` ns (200 ms).
- Umbrales de movimiento: ventana deslizante de 5000 ms sobre la desviación de la magnitud de aceleración respecto a 9.81 m/s², con al menos 4 muestras. `Inmóvil` si media < 0.12 y máximo < 0.25 m/s²; `En reposo` si media < 0.55 m/s²; `Caminando` en caso contrario.

### Bloque exacto que CORE debe poner en `module.json5` (requestPermissions)
```json5
"requestPermissions": [
  {
    "name": "ohos.permission.VIBRATE",
    "reason": "$string:permission_vibrate_reason",
    "usedScene": {
      "abilities": [
        "EntryAbility"
      ],
      "when": "inuse"
    }
  },
  {
    "name": "ohos.permission.READ_HEALTH_DATA",
    "reason": "Permite leer la frecuencia cardiaca del sensor del reloj para detectar emergencias.",
    "usedScene": {
      "abilities": [
        "EntryAbility"
      ],
      "when": "inuse"
    }
  }
]
```

### 2 líneas que CORE debe añadir en `SensorService.ets` para elegir el proveedor
```arkts
import { RealSensorProvider } from './RealSensorProvider';
private provider: SensorProvider = new RealSensorProvider();
```
Sustituyen a las dos líneas actuales de `MockSensorProvider`. Si se quiere pedir el permiso activamente, CORE debe llamar una vez a `requestPermission(context)` desde su capa de ability, sin pasar UI al proveedor.
## <<< EXTRA
