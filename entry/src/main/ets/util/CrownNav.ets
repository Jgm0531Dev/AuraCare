import { Logger } from './Logger';
import { RELEASE_MODE } from './AppConfig';

/** Trazas de navegación (corona/toque): solo en builds de desarrollo. */
export const NAV_TRACE: boolean = !RELEASE_MODE;

/** Desplazamiento por grado de corona (vp). Positivo = hacia abajo. */
const CROWN_VP_PER_DEGREE: number = 3;

export type PageChangedListener = (index: number) => void;

class PageScroller {
  index: number = 0;
  scroller: Scroller;

  constructor(index: number, scroller: Scroller) {
    this.index = index;
    this.scroller = scroller;
  }
}

/**
 * Coordinación de las páginas del ArcSwiper (sin UI).
 * - Index avisa cada cambio de página; las páginas con lista vuelven su Scroller al inicio.
 * - El ArcSwiper es focusable(false) (ni él ni sus páginas pueden recibir el foco, por tanto tampoco la
 *   corona). La corona la recibe el contenedor de Index y la reenvía aquí: se desplaza la lista de la
 *   página visible, si tiene. La corona NUNCA cambia de página.
 */
class CrownNav {
  private listeners: PageChangedListener[] = [];
  private scrollers: PageScroller[] = [];

  onPageChanged(listener: PageChangedListener): () => void {
    this.listeners.push(listener);
    return (): void => {
      const index: number = this.listeners.indexOf(listener);
      if (index >= 0) {
        this.listeners.splice(index, 1);
      }
    };
  }

  notifyPageChanged(index: number): void {
    this.listeners.forEach((listener: PageChangedListener): void => {
      try {
        listener(index);
      } catch (err) {
        Logger.error('CrownNav', 'listener de página falló', err as Object);
      }
    });
  }

  /** Una página con lista registra su Scroller para que la corona la desplace. */
  registerScroller(index: number, scroller: Scroller): () => void {
    const entry: PageScroller = new PageScroller(index, scroller);
    this.scrollers.push(entry);
    return (): void => {
      const position: number = this.scrollers.indexOf(entry);
      if (position >= 0) {
        this.scrollers.splice(position, 1);
      }
    };
  }

  /** Corona recibida por el contenedor de Index: desplaza la lista de la página visible (si tiene). */
  scrollPage(page: number, degree: number): void {
    const entry: PageScroller | undefined =
      this.scrollers.find((item: PageScroller): boolean => item.index === page);
    if (NAV_TRACE) {
      Logger.info('CrownNav', `[nav] corona page=${page} degree=${degree.toFixed(2)} lista=${entry !== undefined}`);
    }
    if (entry === undefined) {
      return;
    }
    try {
      entry.scroller.scrollBy(0, degree * CROWN_VP_PER_DEGREE);
    } catch (err) {
      // Lista no montada (p. ej., Contactos vacío): nada que desplazar.
    }
  }
}

export const crownNav: CrownNav = new CrownNav();
