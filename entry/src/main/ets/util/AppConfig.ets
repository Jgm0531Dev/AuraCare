/**
 * Banderas de compilación. RELEASE_MODE = true para AppGallery: oculta el botón DEMO y la
 * pulsación larga que abre el panel, y deja sin datos de ejemplo (contactos y ficha vacíos).
 */
export const RELEASE_MODE: boolean = false;

/** Acceso al panel demo y nota de simulación del 911. */
export const DEMO_VISIBLE: boolean = !RELEASE_MODE;
