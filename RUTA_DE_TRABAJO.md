# Ruta de trabajo: app de emergencia cardiaca (ArkTS, Huawei Watch 5-7)

## Fase 0: Cimientos (P0)
- Auditar el proyecto ArkTS actual contra UI_SPEC.md.
- Tokens de tema (colores, tamaños) y componentes base: botón de regresar, botón de acción, chip, tarjeta, anillo, arco.
- Modelos y store global. Interfaz SensorProvider + MockSensorProvider.
- Navegación: Swiper de páginas + Navigation de subpantallas.

## Fase 1: Monitor + flujo de emergencia (P0, núcleo de la propuesta)
- Monitor con 3 estados (Normal/Elevado/Crítico) y chips.
- Máquina de estados de emergencia en TS puro.
- ¿Estás bien? (30 s), SOS manual (2 s + 5 s), Alerta enviada, cancelar, 911, variantes sin conexión y sin contactos.
- Vibración al disparar la alerta.

## Fase 2: Contactos y envío (P0)
- Contactos con persistencia local.
- Ubicación al disparar la alerta (solo en ese momento).
- Envío de la alerta: simulado primero; real (nube o teléfono) después.

## Fase 3: Sensores reales (P1)
- RealSensorProvider: ritmo cardiaco y acelerómetro, con permisos.
- Detección de hardware para SpO2 y temperatura (estado "No disponible").
- Línea base personal (mediana y desviación robusta por contexto).
- Pantallas Sensores y Oxigenación.

## Fase 4: Resto de pantallas (P2)
- Tu rango normal, Ficha médica, Ajustes con efecto real.

## Fase 5: Eficiencia y cierre
- Muestreo adaptativo, solo con el reloj puesto, modo ahorro.
- Pruebas en simuladores de Watch 5 y Watch 7. Medición de consumo.
- Pulido, README y guion de la demo.

## Regla de corte
Si el tiempo se acaba, se entrega Fase 0 + 1 + 2 funcionando de punta a punta, con Mock como respaldo. Ninguna fase P1/P2 se empieza con una P0 rota.