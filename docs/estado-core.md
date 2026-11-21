# Estado CORE (rama main)

Actualizado: 2026-11-20

## Hecho
- Panel demo: botón "Cerrar" (72 base) en el flujo; salida única `close()` para botón, atrás del sistema (`onBackPressed`) y swipe a la derecha, con try/finally sobre `demoPanelVisible`.
- Index: no se apila un segundo panel `demo`; `pop()` en try/finally; log de `onChange` del ArcSwiper; capa de debug sin captura de toques.
- Botones del panel a 72 base; motivo y modo activo resaltados.
- hilog bajo `DEBUG_LAYOUT` (en `false`) en clicks, toggles, apertura/cierre, sonda de toques.
- Integración con `origin/feat/pantallas-extra` (ac39ad1) simulada: sin conflictos y compila.

- Integrada `feat/pantallas-extra` (3bbbb63) en main con merge --no-ff, sin conflictos. Rango, Ficha médica y Ajustes ya estaban registradas en el ArcSwiper.
- Panel demo: "Primer uso" pasa de botón a interruptor (mode 'first-use' / 'live'); "Datos de ejemplo" conectado a `extraDemoState.medicalSample`.

## En curso
- Verificación en previsualizador del panel demo y del bug "indicador desaparece tras añadir contacto" (requiere `DEBUG_LAYOUT = true` local y logs del usuario).

## Siguiente
- Conectar `appStore.settings` (sensibilidad, minutos de aviso, modo ejercicio) con la máquina de alertas (pendiente, a pedido del usuario).
- Prioridad 2: lista de pasos de prueba Fase 1B; confirmar que el reenvío respeta la escala de tiempo.
- Prioridad 3 (Fase 2): contactos persistentes (@kit.ArkData preferences), RealSensorProvider con fallback a Mock.

## Notas para EXTRA
- `DemoPanelPage.hardwareSwitch(label, isOn, onChange)` conserva su firma; tu interruptor "Datos de ejemplo" sigue siendo válido.
