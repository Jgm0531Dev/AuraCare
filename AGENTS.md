# Reglas del proyecto (ArkTS, HarmonyOS NEXT, wearable, SDK 6.1.1(24))
- SDK real: 6.1.1(24), según build-profile.json5. EJEMPLO_ARQUITECTURA.md cita 6.0.1(21) solo como referencia histórica; no alinear a esa versión.
- Leer UI_SPEC.md, RUTA_DE_TRABAJO.md y EJEMPLO_ARQUITECTURA.md (solo datos de SDK y convenciones) antes de editar.
- Antes de editar, decir qué archivos se van a tocar. Cambios pequeños; no reescribir archivos completos.
- Estado con decoradores V2 (@ComponentV2, @Local, @Param, @ObservedV2, @Trace). No mezclar V1 y V2 en la misma jerarquía.
- @Trace solo se admite en miembros de clases decoradas con @ObservedV2 (si no, error 10905343).
- El build() de un @Entry debe tener un contenedor (Column/Stack) como raíz, no un componente custom directo (error 10905210).
- px2vp global está deprecado: usar uiContext.px2vp, inyectando this.getUIContext() desde la raíz en aboutToAppear().
- Navegación principal: ArcSwiper vertical con ArcDotIndicator en ArcDirection.THREE_CLOCK_DIRECTION (@kit.ArkUI), no Swiper. ArcSwiper no está en el ámbito global: importarlo explícitamente desde @kit.ArkUI. Si falla, documentar el motivo y volver a Swiper con indicador propio.
- Listas (Sensores, Contactos, Ficha médica): ArcList/ArcListItem descartado: curva las filas y exige LengthMetrics, mientras UI_SPEC.md pide tarjetas planas de 72cqw con degradados de 24 px. Usar List con degradado en los bordes.
- La UI no importa sensores directamente: solo la interfaz SensorProvider. La máquina de estados de emergencia es TS puro, sin imports de UI.
- APIs del sistema siempre con @kit.*. Nombres de archivo e imports con capitalización exacta (caseSensitiveCheck activo).
- Colores y textos en resources ($r('app.color.*'), $r('app.string.*')); tamaños de fuente, espaciados y radios en DesignTokens.ets, aplicados siempre con Dimens. Sin px fijos ni colores literales en las pantallas.
- Todas las medidas, incluidos los tamaños de fuente, pasan por Dimens (base 466, un único factor = anchoRaízVp/466). Colores y textos van en resources.
- Zona segura: 14% arriba/abajo y 9% a los lados. Texto mínimo de 26 px (base 466); áreas táctiles de 72 px de alto (los chips no son tocables).
- Cada permiso nuevo se declara en module.json5 con su "reason" en español y se solicita en tiempo de ejecución.
- Logs con hilog, dominio y tag propios del proyecto (no 'testTag').
- RealSensorProvider: decidir disponibilidad con sensor.getSensorList()/getSensorListSync() filtrando por SensorId; nunca llamar sensor.on() a ciegas. "Activar" (permiso) es estado distinto de "No disponible". Siempre sensor.off al salir; intervalos en nanosegundos.
- SpO₂: proveedor propio (SpO2Provider), separado de ritmo cardiaco. En demo es simulado y debe marcarse como tal; solo lectura real si existe Health Service Kit. Este SDK 6.1.1(24) no expone esa API: avisar antes de usar otra.
- Liberar sensores y ubicación cuando no se usen. Compilar tras cada bloque.
- 
- ## Flujo de git y coordinación (dos sesiones en paralelo)
Sesiones: CORE (Claude Code, rama main) y EXTRA (OpenCode, rama feat/pantallas-extra).
Estas reglas REEMPLAZAN cualquier instrucción anterior sobre commits, push o merge.

- Cada sesión escribe SOLO en su rama. main lo escribe solo CORE. EXTRA nunca empuja a main.
- Al INICIAR cada tarea: `git fetch origin`.
    - EXTRA: `git merge origin/main` (para partir siempre de lo último de CORE).
    - CORE: revisa a EXTRA con `git log --oneline main..origin/feat/pantallas-extra` y `git diff --stat main...origin/feat/pantallas-extra`. No integra su rama salvo que el usuario lo pida.
- Al TERMINAR cada tarea, en este orden:
    1. Compilar: debe dar BUILD SUCCESSFUL. Si no compila, NO hacer push.
    2. Confirmar DEBUG_LAYOUT = false.
    3. `git status`: verificar que no se incluyen archivos de firma (.p12, .cer, .csr, .p7b), local.properties, ni cambios de signingConfigs en build-profile.json5.
    4. Commit con mensaje claro (un commit por tarea).
    5. `git push origin <tu rama>`.
    6. Actualizar tu archivo de estado (docs/estado-core.md o docs/estado-extra.md) con: hecho, en curso, siguiente, y empujarlo en el mismo push.
- Prohibido: push --force, rebase de ramas ya publicadas, merge de la rama de la otra sesión (lo hace el usuario), y commitear código que no compila.
- Si un fetch/merge da conflicto: detenerse, no resolverlo en archivos compartidos y avisar al usuario qué archivos chocan.
- Solo CORE edita AGENTS.md, UI_SPEC.md y RUTA_DE_TRABAJO.md.

## Propiedad de archivos
CORE: Index.ets, store global y estado, máquina de estados de emergencia, servicios y sensores (SensorProvider, Mock y Real), Monitor, Contactos, flujo de emergencia, panel de demo, module.json5, ScreenScaffold y Dimens, firma y build de release.
EXTRA: solo las páginas Tu rango normal, Ficha médica y Ajustes y los componentes exclusivos de ellas, cada una en su propio archivo.
- EXTRA guarda el estado de Ajustes en su propio archivo (p. ej. state/SettingsStore.ets), sin editar el store global. CORE lo conecta al integrar.
- EXTRA pone sus textos y colores en archivos de resources propios (p. ej. element/string_extra.json y color_extra.json) y verifica que compilan.
- EXTRA no toca Index.ets: deja el comentario "// REGISTRAR: ..." en cada página.
- Cualquier cambio en un archivo ajeno debe ser solo AÑADIR líneas al final, dentro de un bloque con marcador (`// >>> EXTRA: ...` / `// <<< EXTRA`), y se avisa al usuario.