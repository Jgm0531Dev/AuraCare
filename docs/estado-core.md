# Estado CORE (rama main)

Actualizado: 2026-11-20

## Hecho
- Panel demo: botón "Cerrar" (72 base) en el flujo; salida única `close()` para botón, atrás del sistema (`onBackPressed`) y swipe a la derecha, con try/finally sobre `demoPanelVisible`.
- Index: no se apila un segundo panel `demo`; `pop()` en try/finally; log de `onChange` del ArcSwiper; capa de debug sin captura de toques.
- Botones del panel a 72 base; motivo y modo activo resaltados.
- hilog bajo `DEBUG_LAYOUT` (en `false`) en clicks, toggles, apertura/cierre, sonda de toques.
- Integración con `origin/feat/pantallas-extra` (ac39ad1) simulada: sin conflictos y compila.

## En curso
- Verificación en previsualizador del panel demo y del bug "indicador desaparece tras añadir contacto" (requiere `DEBUG_LAYOUT = true` local y logs del usuario).

## Siguiente
- Prioridad 2: lista de pasos de prueba Fase 1B; confirmar que el reenvío respeta la escala de tiempo.
- Prioridad 3 (Fase 2): contactos persistentes (@kit.ArkData preferences), RealSensorProvider con fallback a Mock.

## Notas para EXTRA
- `DemoPanelPage.hardwareSwitch(label, isOn, onChange)` conserva su firma; tu interruptor "Datos de ejemplo" sigue siendo válido.
