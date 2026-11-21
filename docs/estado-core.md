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

## En curso
- Verificación visual del usuario en el previsualizador (anillo, halo, Alerta enviada).

## Siguiente
- Integrar los 4 commits nuevos de EXTRA cuando el usuario lo pida.
- Fase 2: contactos persistentes (@kit.ArkData preferences), RealSensorProvider con fallback a Mock.
- Conectar appStore.settings (sensibilidad, minutos de aviso, modo ejercicio) con la máquina.
