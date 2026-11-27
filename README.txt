AuraCare — v1.0.1
=================

Aplicación para reloj Huawei (HarmonyOS NEXT, ArkTS, SDK 6.1.1(24)) que vigila el pulso y el
movimiento mientras la app está abierta y ofrece un flujo de alerta real en el reloj.

Código: https://github.com/Jgm0531Dev/AuraCare
Versión publicada: 1.0.1 (versionCode 1000001), etiqueta Git v1.0.1.

QUÉ HACE
--------
- Lee el ritmo cardiaco y el movimiento con los sensores reales del reloj.
- Aprende el rango normal de la persona a partir de sus propias lecturas de los últimos 7 días.
- Si detecta pulso alto en reposo o muy bajo durante 10 s, pregunta "¿Estás bien?". También
  intenta detectar caídas (golpe seguido de inmovilidad).
- Si no hay respuesta en 30 s, o con SOS pulsado 2 s, se activa la alerta: alarma, vibración y
  notificación local en el reloj.
- Desde la alerta se abre el marcador del sistema con el número del contacto de emergencia o el
  911; la llamada la confirma la persona.
- Ubicación opcional: se muestra solo en la pantalla del reloj durante la alerta.
- Contactos y ajustes se guardan en el propio reloj. La alerta en curso se recupera si la app se
  cierra.
- La corona del reloj desplaza las listas; el cambio de pantalla se hace con el dedo o el
  indicador de puntos.

QUÉ NO HACE
-----------
- No envía mensajes ni avisos automáticos a los contactos.
- No vigila con la app cerrada ni en segundo plano.
- No envía la ubicación a ningún servidor ni a nadie.
- Oxigenación (SpO2) y temperatura no están disponibles en esta versión.
- No garantiza detectar una caída ni una emergencia. No es un dispositivo médico: ante una
  emergencia, llama al 911.

TECNOLOGÍA
----------
ArkTS y ArkUI (ArcSwiper, Navigation, List), APIs del sistema mediante @kit.* (SensorServiceKit,
AbilityKit, ArkData, PerformanceAnalysisKit, etc.), estado reactivo con @ObservedV2/@Trace y
lógica de dominio en TypeScript puro, fácil de probar: máquina de estados de emergencia, motor
de anomalías, modelo de rango, clasificador de movimiento y recuperación de alerta.

Más detalle en PROJECT.txt (arquitectura y privacidad) y BUILD.txt (compilación y pruebas).
