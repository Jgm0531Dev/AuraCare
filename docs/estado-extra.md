# Estado EXTRA (feat/pantallas-extra)

## Hecho
- `fetch` + merge de `origin/main` (`b65dd84`) al inicio de la tarea.
- Pulido de las tres pantallas, con `BUILD SUCCESSFUL` tras cada bloque:
  - `d530d07` Rango: sin “En reposo”, textos cortos, barra 70cqw con trazo 13/14 base y extremos redondos, marcador mapeado al tramo 58-92 (o 60-100 en primer uso) y fijado en el extremo si sale de rango.
  - `64bdb23` Ficha médica: cruz médica, descripción corta, `WordBreak.NORMAL`, ancho 76cqw con margen para el indicador de página y tarjetas demo con scroll.
  - `3c978bc` Ajustes: engranaje, subtítulos “Pausa las alertas automáticas” y “Reenvío si nadie responde”, filas que ciclan y padding inferior 6cqw.
- Encabezados unificados en `ExtraPageHeader.ets` con `SymbolGlyph` del SDK (`waveform_path_ecg_heart`, `cross_square_fill`, `gearshape`), mismo tamaño (`DesignTokens.headerIconSize`) y color (`app.color.accion_principal`).
- Textos nuevos en `resources/base/element/string_extra.json` (resources propios de EXTRA). No se tocó `PageHeader.ets`, `Index.ets`, `string.json` ni archivos de CORE.

## En curso
- Verificación táctil/visual en previsualizador o reloj: no disponible desde este entorno; `@Preview` no añadido.
- Gestos `Scroll` ↔ `ArcSwiper`: ambos `nestedScroll` usan `SELF_FIRST`; no validado en runtime. Si al bajar/volver se bloquea el cambio de página, CORE debe ajustar `Index.ets` (EXTRA no lo toca).

## Siguiente
- Revisar nuevas capturas del previsualizador y confirmar que no hay desbordes ni conflicto de gestos.
- Si aparece conflicto de gestos, registrar el caso para CORE y mantener este archivo actualizado con cada push de `feat/pantallas-extra`.
