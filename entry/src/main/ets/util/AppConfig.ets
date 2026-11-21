/**
 * Único archivo de banderas de compilación.
 * Release (AppGallery): RELEASE_MODE = true. Desarrollo: RELEASE_MODE = false (vuelve todo lo de demo).
 */
export const RELEASE_MODE: boolean = true;

/** Overlays de zona segura y hilog de layout / cadena de disparo. Nunca activo en release. */
const DEBUG_LAYOUT_DEV: boolean = false;
export const DEBUG_LAYOUT: boolean = !RELEASE_MODE && DEBUG_LAYOUT_DEV;

/** Badge DEMO, nota de simulación del 911, velocidad del tiempo y datos de ejemplo. */
export const DEMO_VISIBLE: boolean = !RELEASE_MODE;

/** Pulsación larga de 3 s en el Monitor para revisores, aun con RELEASE_MODE. */
export const REVIEWER_DEMO_GESTURE: boolean = false;

/** El panel demo solo es alcanzable con esto en true. */
export const DEMO_GESTURE_ENABLED: boolean = !RELEASE_MODE || REVIEWER_DEMO_GESTURE;
