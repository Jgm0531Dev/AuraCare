# Estado CORE (rama main)

Actualizado: 2026-11-20 22:2x

## Hecho
- Flujo de emergencia de punta a punta: auto-alerta (Crítico + Inmóvil, 3 s), SOS 2 s, Simular alerta, Disparar alerta ahora; ¿Estás bien? / Pidiendo ayuda / Alerta enviada y diálogos como rutas de NavPathStack (`alert`, `dialog`).
- Velocidad x1/x5/x10 sobre ScaledClock (reprograma temporizadores activos).
- Visual: anillo en Canvas (vacía en sentido horario, rojo en últimos 10 s y en SOS), halo radial con pulso de 2 s, dos botones de 72 base dentro del círculo; Alerta enviada con cabecera fija, filas de 72 base y botones en el scroll.
- Panel demo reactivo (DemoChoiceButton), "Contactos de ejemplo" (apagado), "Añadir contacto de prueba".
- Release: contactos vacíos al inicio, `util/AppConfig.ets` → `RELEASE_MODE` (false), nota de simulación solo en 911.
- AGENTS.md: "Lecciones aprendidas".
- Integración simulada con origin/feat/pantallas-extra (39aa3dd): sin conflictos (no integrada).

- Anillo continuo (Progress Ring, restante/total del Clock) con logs 30/20/10/0; motivo congelado (alertBpm).
- Contactos reales: alta en 2 pasos (relación + teclado 3x4), preferences (@kit.ArkData), máx. 5, llamada con call.makeCall (en previsualizador es mock: no dibuja marcador).
- Integrada feat/pantallas-extra (9eeaf3f) en main: pulido de Rango, Ficha, Ajustes; RealSensorProvider añadido pero SIN conectar.

- Pantalla Sensores (5 tarjetas, variantes, chip Simulado). Rango con escala única (Canvas).
- Release v1.0.0: util/AppConfig.ets controla todo (RELEASE_MODE=true, DEBUG_LAYOUT=false, DEMO_VISIBLE=false, REVIEWER_DEMO_GESTURE=false); Logger.info silenciado en release; "SIMULADO" en el Monitor con el Mock; vendor/versionCode/descripciones reales; tags de plantilla fuera. Permisos: solo VIBRATE.
- ALERTS_SIMULATED=true: Alerta enviada muestra "Aviso simulado", aviso naranja fijo (hasta 3 líneas), "Ubicación simulada" y contactos "Simulado". versionCode confirmado en 1.

## En curso
- Verificación visual del usuario en el previsualizador (anillo, halo, Alerta enviada).

## Siguiente
- Revisar y conectar RealSensorProvider (de EXTRA, área CORE): declarar READ_HEALTH_DATA en module.json5, selección automática con fallback a Mock.
- Píldora "Llamando a…" sigue en el Stack raíz: probablemente queda bajo Navigation (misma causa que las alertas); moverla si se necesita.
- Integrar los 4 commits nuevos de EXTRA cuando el usuario lo pida.
- Fase 2: contactos persistentes (@kit.ArkData preferences), RealSensorProvider con fallback a Mock.
- Conectar appStore.settings (sensibilidad, minutos de aviso, modo ejercicio) con la máquina.
