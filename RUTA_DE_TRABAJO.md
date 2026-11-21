# Ruta de trabajo: app de emergencia cardiaca (ArkTS, Huawei Watch 5-7)

## Fase 0: Cimientos (P0)
- Auditar el proyecto ArkTS actual contra UI_SPEC.md.
- Tokens de tema (colores, tamaños) y componentes base: botón de regresar, botón de acción, chip, tarjeta, anillo, arco.
- Modelos y store global. Interfaz SensorProvider + MockSensorProvider.
- Navegación: Swiper de páginas + Navigation de subpantallas.

## Fase 1: Monitor + flujo de emergencia (P0, núcleo de la propuesta)
- Monitor con 3 estados (Normal/Elevado/Crítico) y chips.
- Máquina de estados de emergencia en TS puro.
- ¿Estás bien? (30 s), SOS manual (2 s + 5 s), Alerta enviada, cancelar, 911, variantes sin conexión y sin contactos.
- Vibración al disparar la alerta.

## Fase 2: Contactos y envío (P0)
- Contactos con persistencia local.
- Ubicación al disparar la alerta (solo en ese momento).
- Envío de la alerta: simulado primero; real (nube o teléfono) después.

## Fase 3: Sensores reales (P1)
- RealSensorProvider: ritmo cardiaco y acelerómetro, con permisos.
- Detección de hardware para SpO2 y temperatura (estado "No disponible").
- Línea base personal (mediana y desviación robusta por contexto).
- Pantallas Sensores y Oxigenación.

## Fase 4: Resto de pantallas (P2)
- Tu rango normal, Ficha médica, Ajustes con efecto real.

## Fase 5: Eficiencia y cierre
- Muestreo adaptativo, solo con el reloj puesto, modo ahorro.
- Pruebas en simuladores de Watch 5 y Watch 7. Medición de consumo.
- Pulido, README y guion de la demo.

## Regla de corte
Si el tiempo se acaba, se entrega Fase 0 + 1 + 2 funcionando de punta a punta, con Mock como respaldo. Ninguna fase P1/P2 se empieza con una P0 rota.

## Comandos
Compilación desde terminal (PowerShell, sin DevEco abierto). Copiar tal cual desde la raíz del proyecto:

```powershell
$env:NODE_HOME='C:\Program Files\Huawei\DevEco Studio\tools\node'; $env:PATH="C:\Program Files\Huawei\DevEco Studio\jbr\bin;$env:NODE_HOME;$env:PATH"; $env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'; & 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```

Notas: `NODE_HOME` y `DEVECO_SDK_HOME` son obligatorios en esta máquina; el JRE de `DevEco Studio\jbr\bin` debe ir en `PATH` para empaquetar el HAP (si falta, `PackageHap` falla con `spawn java ENOENT`). El proyecto no tiene configuración de firma, así que hvigor avisa y genera el HAP sin firmar; eso no es un error de compilación.

## Campos del store usados por las pantallas P2 (rama feat/pantallas-extra)
No se ha conectado ninguna lógica de alertas desde la UI: estas pantallas solo escriben/leen campos del store. La otra sesión debe leerlos desde `appStore`:

- `appStore.settings.sensitivity`: cadena `'Baja' | 'Media' | 'Alta'` (Ajustes la cicla Baja → Media → Alta). Usar con `SENSITIVITY_THRESHOLDS` de `state/EmergencyMachine.ets` (Baja 130, Media 110, Alta 100 BPM) en la regla de auto-alerta: disparar cuando `bpm >= umbral`, con `exerciseMode === false`, `mode === 'live'` y el resto de condiciones ya existentes.
- `appStore.settings.noticeMinutes`: `1 | 3 | 5 | 10` (Ajustes lo cicla 1 → 3 → 5 → 10). Debe alimentar el intervalo de reenvío de "Alerta enviada": `noticeSeconds = noticeMinutes * 60`, reiniciando `nextNoticeSeconds` cuando cambie el valor.
- `appStore.settings.exerciseMode`: booleano. Activa la insignia "Ejercicio" en Monitor y pausa los avisos automáticos; no debe alterar el flujo manual de SOS.
- `appStore.settings.batterySaver`: booleano; hoy solo se refleja en Ajustes. La otra sesión decidirá su efecto en muestreo.
- `appStore.settings.fallDetection` + `appStore.capabilities.fallDetection`: el interruptor de Ajustes solo se puede cambiar si el hardware está disponible (`SensorStatus.Available`); si no, se muestra "No disponible en tu reloj" y queda deshabilitado. No se ha añadido ninguna detección de caídas.
- `extraDemoState.medicalSample` (bloque nuevo al final de `state/AppStore.ets`): booleano de demo, `false` por defecto. Solo lo activa el interruptor "Datos de ejemplo" del panel de demo para mostrar la ficha médica de muestra. Con `false` la ficha muestra el estado vacío real; no hay persistencia.

"Probar vibración" usa el `VibrationService` y el patrón `VibrationPattern.Triple` ya existentes. El permiso `ohos.permission.VIBRATE` ya estaba declarado en `module.json5` con su reason en español y se solicita en tiempo de ejecución, así que no hubo que tocar el manifiesto.