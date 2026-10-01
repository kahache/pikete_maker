# F2 — Batería #23: before/after de #21/#22/#57 (200 fotos, mismo backend)

**Fecha:** 2026-07-10 · **Issue:** #23 · **Muestra:** Fashionpedia val/test-2020,
`mass_battery.py --n 200` (seed 42, las mismas 200 del baseline).

## Setup (importante)

Ejecutado en el **PC (Ubuntu, Python 3.12)**, donde `rembg`/onnxruntime están
instalados → el pipeline usa **u2net**, no GrabCut. El baseline histórico de
**KO 62,5 %** se midió con **GrabCut** (Mac, Py 3.14): **los valores absolutos
NO son comparables entre backends.** Para medir la mejora se corrió
**before/after en la MISMA máquina** (mismo rembg), stasheando `harmony.py` +
`background.py` para el "before" (= `main`). Esto aísla el efecto de
**#21/#22/#57** (todo en el base-picking). **#25/#30 son solo-GrabCut → inertes
aquí.** Reproducible: `scratchpad/run_23_beforeafter.sh`.

## Resultado bruto (flags automáticos)

| flag | BEFORE (main) | AFTER (#21/#22/#57) | delta |
|---|---|---|---|
| NEUTRAL_BASE | 37 (18,5 %) | 98 (49,0 %) | **+30,5 pp** |
| BASE_IS_SKIN | 83 (41,5 %) | 85 (42,5 %) | +1,0 pp |
| FG_BROKEN | 1 | 1 | 0 |
| COLLAPSED_PALETTE | 30 | 30 | 0 |
| OVERFILTERED | 25 | 25 | 0 |
| CRASH | 0 | 0 | 0 |
| **ANY-FLAG (KO proxy)** | 139 (69,5 %) | 163 (81,5 %) | **+12,0 pp** |

A primera vista "empeora". **No es una regresión — es un métrico obsoleto** (el
flag `NEUTRAL_BASE` predata canvas mode / D10 y contaba como KO algo que hoy es
la salida correcta). Corregida la semántica (`KO_FLAGS` sin `NEUTRAL_BASE`,
`summarize()` en `mass_battery.py`):

| categoría | BEFORE (main) | AFTER (#21/#22/#57) | delta |
|---|---|---|---|
| **KO real** (skin/FG/collapsed/overfiltered/crash) | 126 (63,0 %) | 128 (64,0 %) | **+1,0 pp** |
| **canvas-mode** (D10, ok) | 13 (6,5 %) | 35 (17,5 %) | **+11,0 pp** |
| **clean** | 61 (30,5 %) | 37 (18,5 %) | **−12,0 pp** |

**Lectura honesta (rectifica una primera impresión de "mejora de KO"):**

1. **El KO real es plano (~63 %).** #21/#22/#57 **no** reducen el KO en este
   dataset — el fallo dominante es `BASE_IS_SKIN` (~42 %), que es
   piel/atribución y se resuelve con **segmentación (Fase 2.5)**, no con el
   base-picking.
2. **Lo que sí aportan: honestidad.** El "clean" cae 12 pp porque ~24 fotos que
   pasaban como limpias tenían una base cromática **falsa** (near-black/reflejo)
   y ahora se enrutan correctamente a canvas mode. Es exactamente el fallo que
   B8/#57 describían ("infla el éxito aparente"). En la app (Dart) esas fotos
   ahora muestran canvas mode (accents curados) en vez de armonías arbitrarias
   — la corrección de UX que perseguía #21.
3. **Caveat de dataset:** Fashionpedia (pasarela/editorial) infra-representa el
   target de estos fixes (outfits neutros/near-black y reflejos, propios de las
   selfies de espejo del CEO). El efecto modesto aquí (22 fotos) subestima el
   impacto en el caso real del MVP; las selfies (#17) — no incluidas en esta
   batería — lo mostrarían mejor.

**Veredicto:** #21/#22/#57 son correcciones de **corrección/honestidad** (fin de
las bases cromáticas falsas, enrutado correcto a canvas mode), **no reductores
del KO** en Fashionpedia. El KO real sigue dominado por atribución/piel →
Fase 2.5.

---

### Detalle foto-a-foto (respaldo del veredicto)

Solo se movió `NEUTRAL_BASE` (los demás flags, idénticos → los cambios tocan
EXCLUSIVAMENTE la clasificación de la base, que es justo el trabajo de
#22/#57). Análisis foto a foto de las que cambiaron:

- **61 fotos** pasaron de base-cromática → `NEUTRAL_BASE`. **0 en sentido
  contrario** (ninguna base cromática legítima perdida).
- **54/61 = #22**: la base ANTES tenía croma LAB < 13 (mediana V=0,21, croma
  7,7) — near-blacks y neutros oscuros que la saturación HSV etiquetaba como
  "cromáticos". **26 de ellas pasaban como "limpias" (sin flags) ANTES**: el
  modo de fallo exacto que B8 avisó ("infla la tasa de éxito aparente sin ser
  detectado"). Ahora se marcan honestamente como neutro.
- **7/61 = #57**: base ANTES cromática (croma ≥ 13) pero un pop pequeño
  (peso 0,03–0,05) sobre un dominante neutro (0,56–0,95) → demotado a canvas
  mode. Es el target de #57, e incluye el residual aceptado de **D20** (~3,5 %
  de fotos: algún accent genuino también va a canvas mode; inseparable por
  color, se paga en Fase 2.5).

(Los 61 flips explican el −24 en "clean" y el +22 en "canvas-mode"; el resto de
los 61 ya eran KO por otra flag y siguen contando como KO.)

## Acción de seguimiento

- **Semántica de KO de `mass_battery.py` — HECHO (2026-07-10):** `NEUTRAL_BASE`
  ya no cuenta como KO; `KO_FLAGS` + `summarize()`/`format_summary()` reportan
  KO real / canvas-mode / clean por separado, y la galería lo colorea aparte.
  Las cifras corregidas de arriba salen de re-agregar los JSON existentes con
  esta semántica (el pipeline es determinista, seed 42 → re-correr da flags
  idénticas).
- **El KO real (~63 %) está dominado por `BASE_IS_SKIN`** → no se mueve sin
  **segmentación (Fase 2.5)**. Ahí está el próximo gran salto de calidad, no en
  más heurísticas de base.
- Comparación **apples-to-apples con el 62,5 %**: requiere forzar GrabCut
  (before/after), pendiente — pero el número absoluto importa menos que el
  delta ya medido aquí.
- **Sanity visual**: la galería (`outputs/mass-battery/index.html`) separa ya
  KO (rojo) / canvas-mode (naranja) / clean (verde) para confirmar por ojo.

## Artefactos

`outputs/mass-battery/{before,after}.json` (gitignored). Semilla 42, n=200.
