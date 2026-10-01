# F1 — Estrategia de tests: qué tenemos, qué falta y qué haría YA

- **Fecha:** 2026-07-08 · **QA:** qa-engineer
- **Encargo del CEO:** "¿qué más tipos de test podríamos hacer?" — inventario,
  catálogo de opciones con esfuerzo/fase, y TOP 3 para crear issues.
- **Principio rector:** el objetivo de Fase 1 es un demo instalable (D15).
  Sobre-testear un demo es tirar tiempo; el criterio de cada recomendación es
  "¿protege el demo o la fuente de verdad del algoritmo?".

## 1. Inventario — lo que ya hay (verificado hoy)

| Suite | Qué cubre | Estado verificado |
|---|---|---|
| **cv_core pytest — 47 tests** | Unitarios del núcleo (image_io, palette/K-means+fusión LAB, harmony D5/D6, filtros de piel #20, background) + regresión con foto real | `pytest --collect-only`: 47 recogidos; `-m "not slow"`: 37 (los 10 `slow` corren GrabCut/K-means sobre fotos reales, ~2 min) |
| **App Flutter — 43 tests** | Unitarios Dart del motor (palette, harmony, color_engine), **paridad con fixtures dorados** de Python (#32: 8 fixtures de paleta + casos de armonías, mismas tolerancias que pytest), widget tests del flujo crítico D12 (selector fake → analyzing → result) | 5 ficheros en `app/test/`; 36 `test(`/`testWidgets(` estáticos que a runtime son 43 (los de paridad iteran fixtures). Los fixtures se regeneran con `cv_core/tools/gen_fixtures_dart.py` |
| **Batería-200** | KO automático del pipeline completo sobre Fashionpedia val, reproducible (semilla 42, `cv_core/tools/bateria_masiva.py`) | `docs/qa/photo-eval/2026-07-07_1225_F0_bateria-200.md` (KO 62,5 %) |
| **Batería curada G0 + selfies reales** | 8 fotos adversariales + 4 selfies de espejo reales (camino demo Y pipeline completo) | `docs/qa/photo-eval/2026-07-06_2125_F0_G0-eval.md` y `2026-07-08_2347_F1_selfies-eval.md` |

**Lo que NO hay** (los gaps que ordenan el catálogo):

1. Nada corre **en un dispositivo real**: la paridad Python↔Dart se prueba en
   el host; nadie ha verificado foto→resultado dentro del APK en ARM.
2. Nadie ha **medido el tiempo del motor Dart en un Android** (G1 exige
   análisis < 10 s en móvil; hoy es una incógnita).
3. Nada corre **automáticamente**: las dos suites se lanzan a mano, y el CEO
   alterna Mac y PC — el escenario perfecto para romper la paridad sin
   enterarse.
4. Cero tests de **robustez de entrada** (HEIC, EXIF rotado, imagen 1×1,
   fichero corrupto) en ninguno de los dos motores.
5. Cero verificación de **UI visual** (pantallas vs mockups D12) y de
   **accesibilidad** (los tokens D7 declaran AA por diseño, nadie lo verifica
   en el theme real).

## 2. Catálogo de tipos de test

Formato: **qué es** (1 línea para no-QA) · qué cubriría aquí · herramienta ·
fase · esfuerzo (S/M/L) · veredicto.

### 2.1 Recomendados ya (Fase 1, protegen el demo)

- **Smoke suite rápida** — subconjunto de tests que corre en <1 min y dice
  "lo básico no está roto" antes de cada cambio. Aquí: `pytest -m "not slow"`
  (37 tests) + `flutter test` ya lo son de facto; falta empaquetarlo (script
  único `tools/smoke.sh` o make target) y que sea el paso 0 de CI.
  *Herramienta:* pytest marks (ya existen) + shell. *Fase:* 1. *Esfuerzo:* S.
- **Tests de integración Flutter en dispositivo real** — el test arranca la
  app COMPLETA en un Android físico y ejecuta el flujo foto→paleta→armonías
  de verdad (motor Dart en ARM). Es el equivalente Flutter de lo que el CEO
  llama "Playwright" (Playwright es solo web; aplicaría a una futura landing
  de growth, no a la app). Cubre el gap nº1: hoy la única prueba del APK es
  que el CEO lo abra. *Herramienta:* paquete oficial `integration_test` +
  `flutter test integration_test -d <device>`. *Fase:* 1. *Esfuerzo:* M.
- **Benchmark de rendimiento con presupuesto (versión mínima)** — medir
  cuánto tarda el análisis y FALLAR si excede el presupuesto del gate.
  Versión mínima: un `Stopwatch` dentro del integration test anterior con
  assert < 10 s (G1) sobre las fotos hero; deja la cifra de G1 medida en cada
  ejecución. La versión completa (percentiles, varios dispositivos, presupuesto
  G2.5 < 3 s, `flutter drive --profile`) es de Fase 2. *Herramienta:*
  `integration_test` + Stopwatch; más adelante `pytest-benchmark` solo si
  queremos vigilar regresiones del núcleo Python. *Fase:* 1 (mínima) / 2
  (completa). *Esfuerzo:* S sobre el integration test.
- **Property-based testing del motor de color** — el framework genera miles
  de entradas aleatorias y verifica INVARIANTES ("los pesos siempre suman 1")
  en vez de casos concretos. Invariantes candidatas: pesos suman 1 y ninguno
  < min_weight; nº colores ≤ k; determinismo con misma semilla; la base nunca
  es neutra si existe un cluster cromático (D6, comprometida); armonías
  respetan suelos de sat/val; `is_neutral` estable ante ±1 en RGB — esta
  última habría pillado el B5/B8 de #22 antes que la batería. *Herramienta:*
  `hypothesis` (Python, sobre la referencia canónica); replicar las que
  fallen como tests normales en Dart. *Fase:* 1-2. *Esfuerzo:* S-M.
- **Robustez de entrada (fuzz ligero de imágenes)** — tabla de ficheros raros
  (HEIC, AVIF, EXIF rotado 90°, 1×1 px, truncado/corrupto, 20 Mpx) y el
  contrato "o resultado o error controlado, nunca crash". El demo abre la
  galería del CEO: un HEIC de iPhone compartido por WhatsApp es un caso REAL
  de la semana del demo. En ambos motores (PIL y el decode de Dart).
  *Herramienta:* pytest parametrizado + `flutter test` con assets binarios.
  *Fase:* 1. *Esfuerzo:* S.
- **CI (multiplicador, no tipo de test)** — GitHub Actions corriendo smoke
  Python + `flutter test` (con paridad de fixtures) en cada push. Cubre el
  gap nº3 y el flujo multi-máquina Mac/Ubuntu. Los 10 `slow` y el device
  quedan fuera de CI (manuales/nightly). *Fase:* 1. *Esfuerzo:* S.

### 2.2 Recomendados, pero para Fase 2-3 (todavía no)

- **Golden/screenshot tests de UI** — renderizan cada pantalla y comparan el
  PNG píxel a píxel contra una referencia aprobada; cualquier cambio visual
  rompe el test. Cubriría pantallas D12 vs dirección visual D7/D8/D9 y
  regresiones de theme/tokens. **Todavía no:** la UI va a cambiar con el
  feedback de inversores del demo; goldens sobre UI viva = actualizar PNGs a
  diario. Activar cuando la UI se congele. *Herramienta:*
  `matchesGoldenFile` (nativo de flutter_test) o `alchemist`. *Fase:* 2.
  *Esfuerzo:* M.
- **Accesibilidad (contraste AA de la UI)** — verificar automáticamente que
  el texto de la UI cumple WCAG AA (4,5:1). Los tokens D7 ya se eligieron
  para AA (p. ej. mint.ink #0B7C6C justificado en `tokens.json`); el test
  verificaría que el theme REAL lo respeta y que nadie lo rompe al tocar
  estilos. El logo está exento por WCAG (logotipos, 1.4.3) y los swatches de
  la paleta del usuario son contenido, no UI. Es barato y objetivo, pero no
  bloquea el demo: lo pondría justo detrás del TOP 3, en el mismo PR que los
  widget tests cuando se toque UI. *Herramienta:*
  `meetsGuideline(textContrastGuideline)` en los widget tests existentes +
  pasada manual con Accessibility Scanner. *Fase:* 1-2. *Esfuerzo:* S.
- **Regresión visual de paneles / snapshot de paletas** — congelar la salida
  (paleta+pesos+base por foto) de la batería curada y comparar con tolerancia
  en cada cambio del algoritmo. OJO: comparar PNGs de matplotlib es frágil
  (fuentes, versiones); comparar DATOS es robusto y ya es el patrón de los 10
  tests `slow`. Extenderlo = volcar snapshot JSON por foto de la batería
  curada y assertear contra él. Encaja con la re-ejecución #23 tras #29+#22+#21.
  *Herramienta:* pytest + JSON dorado (mismo patrón que los fixtures Dart).
  *Fase:* 2 (con #23). *Esfuerzo:* S.
- **E2E con Patrol o Maestro** — automatización de la app completa en el
  dispositivo INCLUYENDO lo nativo que `integration_test` no toca bien:
  permisos de cámara/galería, diálogos del sistema, notificaciones.
  **Todavía no:** para un demo que maneja el CEO en mano, `integration_test`
  cubre el 90 % con la mitad de coste; Patrol/Maestro pagan cuando haya
  usuarios reales y matriz de dispositivos. *Herramienta:* Patrol (Dart) o
  Maestro (flows YAML). *Fase:* 2-3 (pre-Play Store). *Esfuerzo:* M-L.
- **Monkey testing** — bombardear la UI con miles de toques/gestos aleatorios
  buscando crashes. Casi gratis en Android (`adb shell monkey -p <paquete>
  10000`) y un crash delante de un inversor es letal → vale la pena UNA pasada
  manual antes de cada demo importante; como suite recurrente no (ruido, poca
  señal en una app de 5 pantallas). *Herramienta:* `adb shell monkey`.
  *Fase:* 1 como one-shot manual / no como CI. *Esfuerzo:* S.
- **Pre-launch report de Play Console** — Google instala tu APK/AAB en su
  granja de dispositivos reales y devuelve informe de crashes, ANRs,
  rendimiento, seguridad y accesibilidad. Gratis, pero exige cuenta de Play
  (25 USD) y subir a un track (interno vale). **No aplica al demo por
  sideload**; es el paso natural al abrir closed testing. *Fase:* 3.
  *Esfuerzo:* S (una vez hay cuenta y firma).

### 2.3 Descartados por ahora (y por qué)

- **Playwright:** solo navegadores/web. Anotado para la futura landing de
  growth; cero aplicación a la app Flutter.
- **Benchmark harness completo en Python (`pytest-benchmark`):** medir el
  núcleo en Python no responde a G1 (la cifra que importa es Dart-en-ARM);
  solo lo montaría si el núcleo Python vuelve a ser producto (backend).
- **Tests de carga/estrés de servidor:** no hay servidor (D15, on-device).
- **Mutation testing, contract testing formal, chaos:** herramientas de
  equipos grandes con CI maduro; aquí el "contract test" ya existe con los
  fixtures dorados de paridad y es suficiente.

## 3. TOP 3 para YA (en orden)

1. **Integration test en Android físico con presupuesto de tiempo**
   (`integration_test`: flujo foto hero → paleta → armonías + `Stopwatch`
   assert < 10 s). *Por qué #1:* el APK demo ES el entregable del pivote D15 y
   hoy nada lo verifica de punta a punta; de regalo deja G1 medido con número
   en cada ejecución (gap nº1 y nº2 de un golpe). El assert de resultado puede
   reutilizar los valores esperados de los fixtures dorados sobre las fotos
   hero de #33 (las 2 selfies aprobadas hoy + las que se curen).
2. **Smoke suite + CI en GitHub Actions** (`pytest -m "not slow"` + `flutter
   test` en cada push; los `slow` y el device, manuales). *Por qué #2:* es el
   seguro más barato del proyecto (esfuerzo S) y el que protege la paridad
   Python↔Dart en el flujo multi-máquina Mac/Ubuntu del CEO: hoy se puede
   romper el motor Dart un martes y descubrirlo el viernes en una demo.
3. **Property-based del motor (hypothesis) + robustez de entrada** en un
   mismo paquete de trabajo: invariantes D6/pesos/`is_neutral` sobre la
   referencia canónica Python + tabla de imágenes raras (HEIC, EXIF, corrupta)
   en ambos motores. *Por qué #3:* ataca la clase de bugs que ya nos ha
   costado caro (#22 era una invariante de frontera; H1 de las selfies salió
   de una foto real "rara"), con esfuerzo S-M y sin tocar dispositivo.

Nota de secuencia: el 2 puede hacerse esta misma semana sin hardware; el 1
necesita el Android del CEO conectado por USB una tarde; el 3 es trabajo de
fondo perfecto para huecos entre feedback del demo.
