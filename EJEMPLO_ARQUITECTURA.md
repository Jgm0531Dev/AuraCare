# EJEMPLO_ARQUITECTURA.md

Referencia de **estructura y convenciones** del proyecto ArkTS de ejemplo (`hnext-watch-exercise-poi-capture`).

> ⚠️ **Contexto importante**: este repositorio es la plantilla mínima que genera DevEco Studio para un módulo `wearable` (un "Hello World" con ciclo de vida de ability y extension de backup). **No contiene** pantallas reales, modelos, servicios, navegación ni persistencia. Por eso, varios apartados dicen explícitamente «no existe todavía» y se limitan a describir el lugar convencional donde iría esa pieza. No se han copiado pantallas ni lógica completa: los fragmentos son ilustrativos y tienen **10 líneas como máximo**.

---

## 1. Árbol de carpetas

Se omiten `oh_modules`, `build`, `.hvigor`, `.idea`, `.git` y `.preview`.

```
hnext-watch-exercise-poi-capture/
├── AppScope/                         Configuración y recursos globales de la app (comunes a todos los módulos).
│   └── resources/                    Recursos globales; se referencian con $r('app.*') desde cualquier módulo.
│       └── base/                     Calificador "base" (por defecto, sin condición de idioma/modo/noche).
│           ├── element/              Recursos de texto globales: app.json5 -> $string:app_name.
│           └── media/                Iconos globales: layered_image.json + background.png + foreground.png.
├── hvigor/                           Configuración del sistema de build Hvigor (modelVersion, execution, logging).
├── watch/                            Único módulo HAP de la app; tipo "entry", el que se instala en el reloj.
│   └── src/                          Conjuntos de fuentes (source sets): main, test, ohosTest y mock.
│       ├── main/                     Código y recursos de producción del módulo.
│       │   ├── ets/                  Todo el código ArkTS del módulo.
│       │   │   ├── pages/            Pantallas registradas en main_pages.json (aquí solo Index.ets).
│       │   │   ├── watchability/     Clase UIAbility principal: ciclo de vida y carga de la primera página.
│       │   │   └── watchbackupability/ ExtensionAbility de backup/restore del módulo.
│       │   └── resources/            Recursos con ámbito de módulo; se referencian con $r('app.*') dentro del módulo.
│       │       ├── base/             Calificador por defecto del módulo.
│       │       │   ├── element/      strings, colors y floats del módulo.
│       │       │   ├── media/        Imágenes del módulo (startIcon.png, icono adaptativo, fondo).
│       │       │   └── profile/      Perfiles: main_pages.json (rutas) y backup_config.json (backup).
│       │       └── dark/             Calificador "dark" (sobrescribe recursos cuando el tema es oscuro).
│       │           └── element/      color.json con el color de la ventana de inicio en modo oscuro.
│       ├── mock/                     Configuración de mocks para pruebas locales (mock-config.json5 vacío).
│       ├── ohosTest/                 Source set de pruebas instrumentadas que se ejecutan en el dispositivo.
│       │   └── ets/
│       │       └── test/             Suite de la ability (Ability.test.ets) y agregador (List.test.ets).
│       └── test/                     Source set de pruebas unitarias locales (sin dispositivo).
```

Archivos sueltos relevantes en la raíz (no son carpetas, pero definen convenciones):
`build-profile.json5` (productos/SDK), `oh-package.json5` (dependencias), `oh-package-lock.json5` (lock v3, autogenerado), `code-linter.json5` (reglas de lint), `hvigorfile.ts` (tareas `appTasks`), `watch/hvigorfile.ts` (tareas `hapTasks`), `watch/obfuscation-rules.txt`, `watch/build-profile.json5`, `watch/oh-package.json5` y `AppScope/app.json5`.

---

## 2. Versión del SDK, herramientas y dependencias

| Elemento | Archivo | Valor |
|---|---|---|
| `targetSdkVersion` | `build-profile.json5` | `6.0.1(21)` |
| `compatibleSdkVersion` | `build-profile.json5` | `6.0.1(21)` |
| `runtimeOS` | `build-profile.json5` | `HarmonyOS` |
| `modelVersion` | `oh-package.json5` y `hvigor/hvigor-config.json5` | `6.0.1` |
| `apiType` | `watch/build-profile.json5` | `stageMode` |
| `lockfileVersion` | `oh-package-lock.json5` | `3` |
| Modos de build | `build-profile.json5` | `debug`, `release` |
| Producto | `build-profile.json5` | `default` -> módulo `watch`, target `default` |

**Dependencias**

- **De producción**: ninguna. Tanto `oh-package.json5` (raíz) como `watch/oh-package.json5` tienen `dependencies` vacío.
- **De desarrollo** (raíz `oh-package.json5`): `@ohos/hypium: 1.0.24` y `@ohos/hamock: 1.0.0`. El lockfile los resuelve desde `https://ohpm.openharmony.cn/ohpm/...`.
- **Hvigor**: los `hvigorfile.ts` importan `@ohos/hvigor-ohos-plugin` (`appTasks` en la raíz, `hapTasks` en el módulo). No hay versión fijada en `hvigor-config.json5` (`dependencies: {}`): la aporta la instalación de DevEco Studio.

**Opciones de build que conviene conocer**

- `strictMode.caseSensitiveCheck: true` y `useNormalizedOHMUrl: true` → exige nombres exactos de archivos/rutas e imports OHM normalizados.
- `resOptions.copyCodeResource.enable: false` en el módulo → no copia recursos de código al resultado.
- `arkOptions.obfuscation.ruleOptions.enable: false` en `release` → **la ofuscación está desactivada** aunque `obfuscation-rules.txt` contenga reglas (`-enable-property-obfuscation`, `-enable-toplevel-obfuscation`, `-enable-filename-obfuscation`, `-enable-export-obfuscation`).
- `code-linter.json5` aplica `plugin:@performance/recommended` y `plugin:@typescript-eslint/recommended` a `**/*.ets`, excluye tests/mock/build/oh_modules y marca como `error`/`warn` una lista de algoritmos criptográficos inseguros (`@security/no-unsafe-*`).

---

## 3. `module.json5`: dispositivos, abilities y permisos

Archivo: `watch/src/main/module.json5`.

- **`deviceTypes`**: `["wearable"]`. El módulo `ohosTest` también declara `["wearable"]` (`watch/src/ohosTest/module.json5`, tipo `feature`, nombre `watch_test`).
- **`type`**: `entry`; **`mainElement`**: `WatchAbility`; **`pages`**: `$profile:main_pages`; `deliveryWithInstall: true`, `installationFree: false`.

**Abilities declaradas**

| Nombre | Tipo | `srcEntry` | `exported` | Detalles |
|---|---|---|---|---|
| `WatchAbility` | `ability` (UIAbility) | `./ets/watchability/WatchAbility.ets` | `true` | Icono `$media:layered_image`, etiqueta `$string:WatchAbility_label`, descripción `$string:WatchAbility_desc`, `startWindowIcon: $media:startIcon`, `startWindowBackground: $color:start_window_background`. `skills`: entidad `entity.system.home` + acción `ohos.want.action.home` (es el launcher del reloj). |
| `WatchBackupAbility` | `extensionAbilities` (`type: "backup"`) | `./ets/watchbackupability/WatchBackupAbility.ets` | `false` | `metadata`: `{ name: "ohos.extension.backup", resource: "$profile:backup_config" }`; el perfil contiene `allowToBackupRestore: true`. |

**Permisos: no hay ninguno declarado.** No existe la clave `requestPermissions` en ningún `module.json5`, por lo que **no hay ningún `reason` que listar**. Si la app real necesita, por ejemplo, ubicación para capturar POI, ahí es donde se añadiría cada permiso con su `reason` (texto que el usuario ve en el diálogo). No aparece tampoco ninguna llamada a `requestPermissionsFromUser` en el código.

---

## 4. Gestión de estado

**Modelo usado: V1, y en su forma más mínima.**

Decoradores presentes en todo el repositorio:

| Decorador | Dónde | Uso |
|---|---|---|
| `@Entry` | `Index.ets` | Marca la página raíz cargada por la ability. |
| `@Component` | `Index.ets` | Define el componente `struct Index`. |
| `@State` | `Index.ets` | `message: string = 'Hello World'`, estado local del componente; se reasigna en `onClick`. |

**No aparece** ningún decorador V2 (`@ComponentV2`, `@Local`, `@Param`, `@ObservedV2`, `@Once`, `@Monitor`), ni decoradores V1 de composición (`@Link`, `@Provide`, `@Consume`, `@ObjectLink`, `@Observed`, `@Builder`, `@Reusable`, `@Watch`).

**Estado global entre pantallas: no existe.** No se usa `AppStorage`, `LocalStorage`, `PersistentStorage`, `@StorageLink`/`@StorageProp`, ni singleton/service compartido. Hay una sola página (`pages/Index`), así que no hay nada que compartir todavía. El único "estado" observable fuera de la UI es la configuración de color de la aplicación, que se fija en el arranque de la ability:

```ts
try {
  this.context.getApplicationContext()
    .setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
} catch (err) { /* hilog.error(...) */ }
```

> Convención a tomar de aquí: las operaciones de configuración del entorno se hacen en `onCreate` de la **UIAbility**, con `try/catch` y log en caso de fallo; la UI solo gestiona su propio `@State`.

---

## 5. Navegación

**No se usa ninguno de los componentes citados**: no hay `Navigation`, `Router` (`@ohos.router`), `Swiper` ni `Tabs` en el proyecto.

Lo único que hay es la **carga inicial** de la página desde el ciclo de vida de la ability, más el registro de la ruta:

```ts
windowStage.loadContent('pages/Index', (err) => {
  if (err.code) { /* log y return */ }
  hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
});
```

```json
{ "src": ["pages/Index"] }
```

- **Paso de parámetros entre pantallas**: no aplica (una sola página). No hay `router.pushUrl`, `pushPath` ni `NavPathStack`.
- La ruta se escribe como **`pages/Index`** en `loadContent` y como **`pages/Index`** en `main_pages.json` (sin extensión `.ets`). Cualquier página nueva tendría que añadirse a ese array.
- Si se introduce navegación más adelante, el patrón recomendable en SDK 6 sería `Navigation` + `NavPathStack` con `pushPath({ name, param })`, manteniendo la declaración de rutas en un único lugar; pero **esto no está implementado en el ejemplo**.

---

## 6. Lista de imports de kits y paquetes

| Import | Origen | Para qué se usa | Archivos |
|---|---|---|---|
| `AbilityConstant, ConfigurationConstant, UIAbility, Want` | `@kit.AbilityKit` | Clase base de la ability, parámetros de lanzamiento (`LaunchParam`, `Want`), constantes de configuración (`setColorMode`). | `WatchAbility.ets` |
| `hilog` | `@kit.PerformanceAnalysisKit` | Logging con dominio, tag, formato `%{public}s` y `JSON.stringify(err)`. | `WatchAbility.ets`, `WatchBackupAbility.ets`, `Ability.test.ets` |
| `window` | `@kit.ArkUI` | Tipado de `window.WindowStage` y carga de contenido con `loadContent`. | `WatchAbility.ets` |
| `BackupExtensionAbility, BundleVersion` | `@kit.CoreFileKit` | Extension de backup/restore: `onBackup()` / `onRestore(bundleVersion)`. | `WatchBackupAbility.ets` |
| `describe, beforeAll, beforeEach, afterEach, afterAll, it, expect` | `@ohos/hypium` (paquete de test, **no** un kit) | Definición de suites, hooks y aserciones. | `LocalUnit.test.ets`, `Ability.test.ets` |
| `abilityTest` / `localUnitTest` (import relativos) | `./Ability.test`, `./LocalUnit.test` | Agregadores `List.test.ets` que invocan las suites. | `List.test.ets` (x2) |

No hay imports de `@ohos.*` de sistema aparte de `@ohos/hypium`; el estilo del ejemplo es usar siempre **`@kit.*`** para las APIs del SDK (es la convención de HarmonyOS NEXT / API 12+).

---

## 7. Persistencia local, recursos y organización (modelos/servicios/componentes)

### Persistencia local

- **No hay persistencia de datos en código**: ni `@ohos.data.preferences`, ni `relationalStore`, ni `AppStorage`/`PersistentStorage`, ni ficheros.
- Sí existe la **infraestructura de backup** del sistema: `WatchBackupAbility` (`onBackup`/`onRestore` con `await Promise.resolve()` de relleno) y `backup_config.json` con `allowToBackupRestore: true`. Es un punto de extensión, no una implementación de guardado.
- Convención que se puede rescatar: los métodos de backup/restore son `async`, devuelven `Promise<void>` y registran el resultado con `hilog`.

### Recursos

| Tipo | Archivo | Contenido | Referencia |
|---|---|---|---|
| String global | `AppScope/resources/base/element/string.json` | `app_name = "poi_capture"` | `$string:app_name` en `app.json5` |
| Strings del módulo | `watch/.../base/element/string.json` | `module_desc`, `WatchAbility_desc`, `WatchAbility_label` | `$string:...` en `module.json5` |
| Color | `.../base/element/color.json` | `start_window_background = #FFFFFF` | `$color:start_window_background` |
| Color (dark) | `.../dark/element/color.json` | `start_window_background = #000000` | Mismo nombre, calificador `dark` |
| Float | `.../base/element/float.json` | `page_text_font_size = 50fp` | `$r('app.float.page_text_font_size')` |
| Media | `.../base/media/` | `background.png`, `foreground.png`, `startIcon.png`, `layered_image.json` | `$media:layered_image`, `$media:startIcon` |
| Profile | `.../base/profile/` | `main_pages.json`, `backup_config.json` | `$profile:main_pages`, `$profile:backup_config` |

Patrones visibles:

- **Todo texto y valor visual que sale del code va a `resources`**, nunca literal (salvo el `'Hello World'`/`'Welcome'` del ejemplo, que es precisamente lo que no conviene copiar).
- Se usan las dos formas de referencia: `$r('app.float.page_text_font_size')` en ArkTS y `$float:` / `$color:` / `$string:` / `$media:` / `$profile:` en JSON de configuración.
- **`layered_image.json`** define un icono adaptativo con `background` + `foreground`; lo usa tanto `app.json5` como la ability. Es el formato estándar de icono de HarmonyOS.
- El sufijo de device/mode (`dark/element/color.json`) permite sobrescribir un mismo nombre de recurso sin tocar el código: el color de la ventana de inicio pasa a negro en tema oscuro.

### Modelos, servicios y componentes reutilizables

**No existen esas carpetas ni esos archivos** en la plantilla. La organización actual es plana: `ets/pages`, `ets/watchability`, `ets/watchbackupability`.

Cuando el proyecto crezca, la convención natural sería añadir carpetas hermanas bajo `watch/src/main/ets/` — por ejemplo `model/` (tipos/interfaces), `service/` (acceso a datos, ubicación, red) y `components/` (widgets reutilizables con `@Component`/`@Builder`) — manteniendo **una responsabilidad por carpeta** y agrupando cada pantalla en `pages/`. Esto es una recomendación de estructura, **no algo presente en el ejemplo**.

---

## 8. Lo específico de reloj (wearable)

| Aspecto | Cómo está resuelto en el ejemplo |
|---|---|
| Tipo de dispositivo | `deviceTypes: ["wearable"]` en `module.json5` y en el módulo de test. Es lo que restringe el HAP al reloj. |
| Ability de launcher | `WatchAbility` con skill `entity.system.home` / `ohos.want.action.home`: es la pantalla de inicio del wearable. |
| Backup/restore | `WatchBackupAbility` de tipo `backup` con `allowToBackupRestore: true`. Es típico en wearables (el reloj se empareja/restaura y necesita recuperar datos). |
| Icono | `layered_image.json` (icono adaptativo) usado como icono de app y de ability. |
| Arranque de UI | `windowStage.loadContent('pages/Index', ...)` desde `onWindowStageCreate`. |
| Tamaño de pantalla | **No hay adaptación explícita**: no se importa `@kit.ArkUI` para `display`, no hay `breakpoints`, `GridRow`, `foldable` ni `onAreaChange`. La única pista es el contenedor raíz con `.width('100%')`/`.height('100%')` y un `RelativeContainer` con `alignRules` centradas, que escala sin coordenadas fijas. |
| Tipografía en pantalla pequeña | El tamaño se define como recurso **`50fp`** (`fp` = píxel de fuente, escalable según la accesibilidad del usuario), no en `px`/`vp` literales. |
| Interacción de corona / gestos de reloj | **No implementada**: no hay `rotary` events, `RemoteWindow`, ni componentes específicos de reloj. |

En resumen: el proyecto resuelve lo de reloj **solo en la declaración del módulo y en el ciclo de vida**; la UI es genérica y no hace nada especial para pantalla reducida más allá de porcentajes y `fp`.

---

## 9. Convenciones de nombres y estilo

- **Clases, structs y tipos**: `PascalCase` — `Index`, `WatchAbility`, `WatchBackupAbility`, `BundleVersion`, `WindowStage`.
- **Archivos ArkTS**: `PascalCase.ets` para componentes/abilities (`Index.ets`, `WatchAbility.ets`); `*.test.ets` para pruebas; `List.test.ets` como agregador de suite.
- **Variables y funciones**: `lowerCamelCase` — `message`, `onBackup`, `onRestore`, `bundleVersion`, `abilityTest`, `localUnitTest`, `testsuite`.
- **Constantes**: `SCREAMING_SNAKE_CASE` — `const DOMAIN = 0x0000;` (definida a nivel de archivo, antes de la clase, y compartida por todos los `hilog` de ese archivo).
- **Recursos**: `lower_snake_case` — `page_text_font_size`, `start_window_background`, `module_desc`. Excepción del generador: los strings ligados a la ability usan el nombre de la clase como prefijo (`WatchAbility_desc`, `WatchAbility_label`).
- **Carpetas**: `lowerCamelCase` o `snake_case` descriptivo — `watchability`, `watchbackupability`, `pages`, `ohosTest`, `mock`.
- **Formato**: 2 espacios de indentación, comillas simples en TS, punto y coma al final de las sentencias, llaves de apertura en la misma línea.
- **Imports**: nombrados entre llaves, agrupados arriba del todo; primero los `@kit.*`, después los relativos. `export default class ...` para abilities y `export default function ...` para suites de test.
- **Comentarios y logs**: en inglés (plantilla del generador). Tag de log fijo `'testTag'` y formato `'%{public}s'` con `JSON.stringify(err)` para errores.
- **Manejo de errores**: `try/catch` en `setColorMode`; comprobación de `err.code` en el callback de `loadContent`; `return` temprano en caso de fallo.
- **Async**: `async` + `await Promise.resolve()` en los hooks de backup que aún no tienen lógica (marcador de plantilla).

---

## 10. Patrones reutilizables

Son los únicos patrones reales que aparecen; se pueden tomar como referencia:

1. **Ciclo de vida de UIAbility con log en cada transición** (`onCreate`, `onDestroy`, `onWindowStageCreate`, `onWindowStageDestroy`, `onForeground`, `onBackground`) y carga de la página raíz en `onWindowStageCreate`. Fragmento ilustrativo:

   ```ts
   onWindowStageCreate(windowStage: window.WindowStage): void {
     hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
     windowStage.loadContent('pages/Index', (err) => {
       if (err.code) { hilog.error(DOMAIN, 'testTag', '%{public}s', JSON.stringify(err)); return; }
     });
   }
   ```

2. **Logging centralizado por archivo** con `const DOMAIN = 0x0000;` + `hilog.info/error(DOMAIN, 'testTag', '%{public}s', ...)`.

3. **Configuración global en `onCreate` con `try/catch`** (color mode, y por extensión cualquier ajuste de aplicación).

4. **Extension de backup desacoplada**: clase propia en su carpeta, `onBackup`/`onRestore`, activada por metadata en `module.json5` + perfil `backup_config.json`.

   ```ts
   export default class WatchBackupAbility extends BackupExtensionAbility {
     async onBackup() {
       hilog.info(DOMAIN, 'testTag', 'onBackup ok');
       await Promise.resolve();
     }
   }
   ```

5. **Estado local mínimo en la página**: `@Entry` + `@Component` + `@State` y modificación en un handler.

   ```ts
   @Entry
   @Component
   struct Index {
     @State message: string = 'Hello World';
     // build() { Text(this.message).onClick(() => { this.message = 'Welcome'; }) }
   }
   ```

6. **Recursos en lugar de literales visuales**: `.fontSize($r('app.float.page_text_font_size'))` y colores/tamaños con calificadores `base`/`dark`.

7. **Estructura de tests en dos niveles**: `List.test.ets` como único agregador que llama a las suites, y hooks `beforeAll/beforeEach/afterEach/afterAll` dentro de `describe`.

8. **Separación por responsabilidad en carpetas** (`pages` / `watchability` / `watchbackupability`) y un único `mainElement` declarado en el manifiesto.

---

## 11. Lo que NO conviene copiar

1. **Los textos de relleno**: `'Hello World'` / `'Welcome'`, `"Please describe the basic information."`, `"module description"`, `"description"`, `"label"`, `vendor: "example"`. Hay que sustituirlos por recursos con significado real.
2. **`DOMAIN = 0x0000` y el tag `'testTag'`** en todo el código: en producción conviene un dominio propio asignado y tags por módulo/función para poder filtrar logs.
3. **El `@State` con texto de ejemplo y el `onClick` que cambia el mensaje**: es la demo del generador, no un patrón de negocio. Tampoco el `RelativeContainer` centrado usado como "pantalla".
4. **La ausencia de permisos y de su `reason`**: copiar el `module.json5` tal cual dejaría la app sin ubicación u otros permisos que un capturador de POI necesita; y si se añaden, deben llevar un `reason` claro en español.
5. **La ausencia de navegación y de estado global**: no hay que asumir que este ejemplo enseña a pasar parámetros; hay que diseñar `Navigation`/`NavPathStack` y la fuente de verdad del estado (V1 `AppStorage`/`Provide` o V2 `@ObservedV2` + `@Local`) según el caso.
6. **`onBackup`/`onRestore` con `await Promise.resolve()`**: son marcadores vacíos; copiarlos daría una "extension de backup" que no guarda ni restaura nada. Y `allowToBackupRestore: true` debe revisarse según la política de datos de la app.
7. **La ofuscación desactivada** (`enable: false`) pese a tener `obfuscation-rules.txt` con reglas: las reglas no se están aplicando. Tampoco conviene heredar reglas de ofuscación sin definir `-keep-*` para las clases expuestas.
8. **`setColorMode(COLOR_MODE_NOT_SET)`** fijado en `onCreate`: hereda el modo del sistema. Si el diseño exige modo claro/oscuro forzado, hay que cambiarlo deliberadamente (y el ejemplo ya tiene `dark/element/color.json` preparado).
9. **El `50fp` fijo**: es un valor de plantilla pensado para una pantalla grande de demo; en una pantalla de reloj puede desbordar. Hay que dimensionar con recursos y probar en el dispositivo objetivo.
10. **Los `devDependencies` y archivos de test de plantilla** (`hypium`, `hamock`, aserciones `assertContain('abc','b')`): no validan nada de la app; sirven solo de esqueleto.
11. **`copyCodeResource.enable: false`** y `strictMode` heredados sin revisar: `caseSensitiveCheck: true` puede romper imports si se copian archivos con distinta capitalización en Windows.

---

### Resumen en una frase

Es una plantilla `wearable` (SDK `6.0.1(21)`, stageMode, un módulo `entry`, UIAbility + extension de backup, sin permisos, sin navegación y con un único `@State`): útil para copiar **la forma** de declarar abilities, recursos, logs y pruebas, pero **no el contenido** de la pantalla ni la arquitectura de datos, que hay que construir desde cero.
