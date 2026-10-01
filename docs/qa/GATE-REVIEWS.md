# Gate Reviews — PiketeMaker

Un apartado por gate. Veredictos con evidencia; sin evidencia no hay veredicto.

---

## G0 — Fase 0 · Prototipo de algoritmo

- **Fecha de revisión:** 2026-07-06
- **Revisor:** qa-engineer (issues #6 y #7)
- **Criterio del gate (PRD §7):** en ≥ 8 de 10 fotos, la paleta extraída "es
  el outfit" a juicio del PO, y la armonía base nunca es un neutro/fondo.

### Veredicto: **PARCIAL — pendiente selfies (2/8 OK con la batería actual)**

- Batería ejecutada: 8 fotos de Fashionpedia val (curación y licencias en
  `samples/g0/MANIFEST.md`). **Faltan las 2 selfies de espejo que aportará
  el CEO** (issue aparte); hasta entonces el gate no se cierra.
- Resultado: **2/8 OK, 6/8 KO** (detalle foto a foto y paneles en
  `docs/qa/photo-eval/2026-07-06_2125_F0_G0-eval.md`).
- Aviso al PM/CEO: con 6 KO, el máximo alcanzable en esta ronda es 4/10 —
  **el gate no puede cumplirse sin correcciones al pipeline y re-ejecución
  completa de la batería**. Esta ronda queda como línea base para validar la
  fusión de clusters en LAB (backend-architect) y los arreglos de los bugs
  de abajo. No se relaja el criterio.

### Evidencia

- Log de las 12 ejecuciones del CLI (8 normales + 4 `--keep-skin`): salida
  íntegra citada en `2026-07-06_2125_F0_G0-eval.md`; paneles en `outputs/g0/` (gitignored,
  reproducibles con `colorlab samples/g0/<foto>.jpg -o outputs/g0/<foto>_paleta.png`).
- Cero crashes; quitafondo degradado a GrabCut (Python 3.14 sin onnxruntime,
  esperado según CLAUDE.md).
- Auditoría cuantitativa del filtro de piel (issue #7) incluida en el eval G0.

### Bugs encontrados (reporto, no arreglo)

| # | Severidad | Bug | Repro mínimo | Esperado vs observado |
|---|---|---|---|---|
| B1 | **Alta (sesgo, issue #7)** | `skin_mask` (YCbCr, `filters.py`) **no detecta piel oscura** por la condición `y > 80`. La piel del usuario entra en la paleta y puede ser la **base de las armonías**. | `colorlab samples/g0/g0-05-medio-cuerpo-piel-oscura.jpg` | Esperado: paleta = blazer lavanda + tee blanco. Observado: `#382C2F` (piel/pelo) 25 % **← BASE armonías**. Con `--keep-skin` aflora `#B27766` (piel iluminada): el filtro solo quitó la piel clara. Riesgo reputacional PRD §9. |
| B2 | **Alta** | `skin_mask` **elimina prendas cálidas** (coral/naranja/rojo) como falsos positivos de piel. | `colorlab samples/g0/g0-01-multicolor.jpg` (vs `--keep-skin`) | Esperado: turquesa + coral + morado. Observado: el coral desaparece (filtro marca 11 % de foto); en g0-03 marca **43 %** (graffiti rosa) y en g0-07 **40 %**. |
| B3 | **Alta** | `pick_harmony_base` cae al color dominante (neutro) cuando todos los clusters son neutros → **base de armonías neutra**, violando el criterio del gate, con armonías de matiz arbitrario. | `colorlab samples/g0/g0-02-total-black.jpg` | Esperado (gate): base nunca neutra. Observado: base `#37363D` en g0-02, `#647178` en g0-04, `#1B1A1D` en g0-06. **Decisión de producto necesaria:** ¿qué proponer con un outfit 100 % neutro? Escalado al PM/CEO, no lo resuelve QA. |
| B4 | **Media-alta** | GrabCut falla con sujeto pequeño/lejano (2 % de primer plano, paleta de 1 color) y con varias personas (incluye la ropa de los demás). | `colorlab samples/g0/g0-04-cuerpo-lejos.jpg` y `g0-06-varias-personas.jpg` | Esperado: paleta del outfit del sujeto. Observado: g0-04 → un único `#647178` 100 %; g0-06 → negro 77 % inflado por otros peatones. Limitación conocida ("GrabCut asume sujeto centrado"), ahora cuantificada. |
| B5 | **Media** | Umbral `NEUTRAL_SAT = 0.18` frágil: un gris con sat 0,19 se convierte en base "cromática". | `colorlab samples/g0/g0-03-fondo-recargado.jpg` | Esperado: base cromática real. Observado: base `#3A3946` (sat ≈ 0,19), neutro de facto. |
| B6 | **Baja** | El **pelo** entra en la paleta como si fuera prenda. | g0-01 (`#2A2A2B` 15 %), g0-03 (`#43271E` 20 %) | Esperado: solo ropa. Observado: pelo como 2º color del "outfit". |
| B7 | **Baja** | `background.py::_remove_bg_grabcut` **no usa** sus constantes `GRABCUT_RNG_SEED` ni `GRABCUT_SEED_FRACTION`: ni siembra el RNG global de OpenCV ni pinta la caja-semilla de primer plano. El recorte no es determinista entre procesos → la misma foto puede dar paletas ligeramente distintas en dos análisis. | Analizar la misma foto dos veces en procesos separados. | Esperado: resultado reproducible (lo que promete el docstring). Observado: depende del estado global del RNG de OpenCV. Encontrado al escribir los tests de #20; estos siembran el RNG a mano para no ser flaky. |

### Addendum 2026-07-07 — batería masiva de 200 fotos (issue #24)

- Batería reproducible sobre 200 fotos aleatorias (semilla 42) de
  Fashionpedia val: **KO automático 62,5 %** (cota inferior; con el bug
  nuevo B8 sumado, 76,0 %). El 2/8 de la batería curada **no era
  pesimista**. Informe completo:
  `docs/qa/photo-eval/2026-07-07_1225_F0_bateria-200.md`; galería visual en
  `outputs/bateria-100/index.html` (local, gitignored por licencias).
- Causa nº 1 (39 % de las fotos): la base de armonías es piel —
  el guardarraíl `MAX_SKIN_FRACTION` se autodesactiva en 101/200 fotos
  (piel visible > 50 % del fg es lo normal en fotos de moda) y reintroduce B1.
- **La tesis F13 (fondo liso ⇒ mejor tasa) queda refutada con el pipeline
  actual:** KO 70,2 % en fondo liso vs 60,1 % en recargado (umbral
  calibrado bg_std = 20). QA recomienda NO re-plantear G0 por segmentos.
- Bug nuevo **B8 (alta):** `is_neutral` usa saturación HSV, inestable en
  casi-negros (`#030203` → s = 0,33 "cromático") → un negro puede ser base
  de armonías sin detectarse (27 fotos "limpias" afectadas). Repro:
  `f2db9363e91422cf8442d6275190891c` (base negra le gana al cárdigan rojo).
- Rendimiento: **p95 = 11,2 s/foto** en el entorno de referencia local —
  incumple el guardarraíl del PRD (p95 < 6 s); 28 % de fotos > 6 s.

### Pendiente para cerrar G0

1. Las 2 selfies de espejo del CEO (issue aparte) → re-ejecutar y completar
   la tabla a 10 fotos.
2. Correcciones de B1–B3 (mínimo) y re-ejecución de la batería completa.
3. Nota: la batería se re-ejecutó con el `palette.py` del working tree, que
   **ya incluye la fusión LAB del backend-architect** (sin commitear), con
   resultados idénticos en las 8 fotos. La fusión LAB por sí sola **no
   levanta ninguno de los 6 KO** (B1–B4 ocurren antes/después del
   clustering); sirve como línea base validada para su cambio, pero el gate
   sigue necesitando correcciones de B1–B3.

---

## Gate G1 — MVP demo (Phase 1) · ✅ PASSED · 2026-07-09

**Criterion:** the CEO installs the APK, completes photo→palette→harmonies
without crashes and without network, and the result "looks good" on the hero
photos.

**Evidence:**
- Signed APK `piketemaker-v0.1.0-r6-SIGNED.apk` (release keystore, fingerprint
  verified) installed and exercised on the CEO's Android across 6 iterative
  builds (r1→r6), fully offline. Real engine (ColorEngineDart, parity with
  colorlab via golden fixtures).
- Device QA by the CEO surfaced 3 real bugs (off-center launcher icon,
  zero-height harmony swatches, BASE placement question) — all resolved or
  adjudicated (the third: correct-by-design per D5), each with a regression
  test. App suite: 58/58 · flutter analyze 0.
- Hero set: 3 photos (selfie01, selfie04, selfie21) out of 31 real unstaged
  selfies, verified "looks good" end-to-end on device. CEO decision: set
  closed at 3 — the recipe (1 saturated garment, plain light background,
  garment large in frame) lives in the F13 tutorial and
  `photo-eval/2026-07-09_1241_F1_hero-set-curation.md`.
- Visual identity ratified screen by screen by the CEO (r5-visual-decisions +
  device confirmation of the dot-centered icon).

**Honest boundaries carried into Phase 2:** real-world unguided pass rate is
low on neutral-heavy photos (3/31 on the convenience sample; 15/28 failures
are neutral outfits → #21 canvas mode is Phase 2's first item); background
attribution waits for segmentation (Phase 2.5). The demo relies on guided
photos by design (D15).

## G2.5 (per-garment segmentation) — first measurement · 2026-07-18 · FAIL
- Definición (PRD): ≥80% de colores por-prenda correctos, overall Y por bucket de piel (test de sesgo §9), latencia <3s.
- Medido (CEO hand-review, dataset D23 69 fotos): **overall 53/69 = 76.8% FAIL**. Buckets: dark 84.6% PASS · light 78.0% · medium 66.7%. Latencia 556ms M33 OK. Informe: docs/qa/photo-eval/2026-07-18_G2.5-primera-medida.md
- Veredicto CEO: primera medida = diagnóstico. SIN sesgo de piel (dark el más alto). El gap = 4 bugs de post-proceso arreglables (base-selection, skin/bg leak, snap #85, split line), no la segmentación. 4 fotos de pasarela extrema excluidas.
- Consecuencia: arreglar los 4 bugs uno a uno en Python canónico (con red de regresión), re-medir; luego Dart parity + calibración #57. Flag de segmentación sigue OFF.

## G2.5 — SIGNED (all legs green) · 2026-07-18
- Base ≥80% representativo: **84.6% (55/65) PASS**, sin sesgo de piel (dark 84.6 / light 84.2 / medium 85.7) — bug B-G25-1 arreglado (Python + Dart parity).
- Latencia M33 (motor cableado, ARM): carga 161ms · inferencia media **544ms** (peor 761ms) · máscaras idénticas · no-person degrade OK → presupuesto D22 <3s HOLDS.
- Veredicto: **Gate G2.5 FIRMADO.** Requisitos para encender kGarmentAnalysisEnabled: split #87 ✅ + G2.5 ✅ + latencia ✅ → los 3 cumplidos.
- Consecuencia: decisión CEO = encender el flag para r10 o esperar a G2. Bugs 2-4 = margen opcional.
