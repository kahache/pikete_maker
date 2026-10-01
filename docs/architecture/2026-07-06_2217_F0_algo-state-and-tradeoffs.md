# Estado del algoritmo y tradeoffs de segmentación — decisión de fase

| | |
|---|---|
| **Autor** | backend-architect |
| **Para** | PM / CEO (decisión go/no-go Fase 0 → Fase 1) |
| **Fecha** | 2026-07-06 |
| **Entorno de los experimentos** | `.venv` local, **Python 3.12.3** (no 3.14), con `rembg` 2.0.76 + `onnxruntime` 1.27 instalados a propósito para este informe. GrabCut sembrado (`cv2.setRNGSeed(0)`). |
| **Documentos hermanos** | `docs/qa/photo-eval/2026-07-06_2125_F0_G0-eval.md`, `docs/qa/GATE-REVIEWS.md`, `docs/PRD.md` |

> **TL;DR.** Recomiendo **avanzar a Fase 1 YA**. El cuello de botella de G0
> (2/8) **no es la calidad del clustering ni de las armonías** — que funcionan —
> sino la calidad de la *entrada*. La hipótesis del CEO (tutorial → fondo liso
> de color plano) es técnicamente **correcta y potente**: convierte la
> segmentación en un *chroma-key* trivial (IoU 1.000, <0,1 s, numpy puro,
> on-device nativo) que mata el bug B4 —el mayor generador de KO— sin ML y con
> coste marginal cero (D2). Probé `rembg` de verdad sobre las 8 fotos g0:
> **da máscaras claramente mejores pero NO sube el gate** (2/8 → 2/8), porque
> los KO restantes los dominan bugs *independientes de la segmentación*
> (B3 neutros, B1/B2 piel). Conclusión: dejar de pulir segmentación en la
> entrada no controlada y trasladar el control al onboarding. Trabajo de
> algoritmo mínimo antes/junto a Fase 1: implementar **modo lienzo (D10)** y un
> **path chroma-key**; el resto se difiere a Fase 2.5 por diseño.

---

## 1. Estado real del algoritmo hoy (verificado, no repetido del eval)

Re-ejecuté el pipeline sobre las 8 fotos g0 con el working tree actual (fusión
LAB + filtro de piel adaptativo #20) para tener números frescos. Síntesis:

**Lo que funciona bien y NO es el problema:**

- **K-means + fusión LAB (F2/F3).** Cuando la entrada es limpia, la paleta
  "es el outfit". El demo sintético (§3) recupera 3 colores con pesos
  correctos; la foto Vuitton y los casos OK (g0-07, g0-08) lo confirman.
- **Armonías y elección de base cromática (F4/D5).** `pick_harmony_base`
  elige el color más protagonista (saturación × peso) y evita neutros salvo
  fallback. Con tests de regresión. No hay que tocarlo.
- **Robustez operativa.** Cero crashes en decenas de ejecuciones; la cascada
  de quitafondo degrada con elegancia. La suite pasa **47/47** incluso tras
  instalar `rembg` (el cambio de rama activa de la cascada no rompe nada).

**Lo que falla, y en qué tipo de foto (los 6 KO de G0):**

| Causa raíz | Bug | Tipo de foto | ¿Es problema de segmentación? |
|---|---|---|---|
| Sujeto pequeño/lejano o varias personas | **B4** | cuerpo entero lejos (g0-04), calle con peatones (g0-06) | **Sí**, pero ver §2: ni rembg lo arregla del todo |
| Outfit 100 % neutro → base neutra | **B3 / B5** | total black (g0-02), casi-neutros (g0-03, g0-04) | **No** — independiente del fondo |
| Piel del sujeto en la paleta / prenda cálida borrada | **B1 / B2** | piel oscura (g0-05), coral≈piel (g0-01) | **No** — la piel está en el sujeto, no en el fondo |
| Pelo tratado como prenda | **B6** | g0-01, g0-03 | Parcial (segmentación de partes, F2.5) |
| GrabCut no determinista | **B7** | cualquiera | Sí (trivial de arreglar, ver §5) |

**Lectura clave:** de los 4 grupos de causa, **solo B4 y B7 son de
segmentación**. B3 y B1/B2 sobrevivirían a *cualquier* quitafondo. Es decir:
**seguir invirtiendo en calidad de segmentación tiene retorno decreciente
sobre el gate**. Esto es lo que confirma el experimento de la §2.

---

## 2. Tradeoffs de segmentación — con experimento real de rembg

### 2.1 Experimento: rembg (U²-Net) vs GrabCut sobre las 8 fotos g0

Instalé `rembg`+`onnxruntime` en 3.12 y corrí el pipeline completo con cada
quitafondo (misma paleta, mismas armonías; solo cambia la máscara). Resultado:

| Foto | Veredicto G0 (GrabCut) | rembg: fg% y base | Efecto de rembg sobre el veredicto |
|---|---|---|---|
| g0-01 multicolor | **KO** (coral borrado) | 50 %, base `#43A9BE` cromática | **KO→OK.** El **coral reaparece** (`#DB5340` 26 %): los 3 colores del outfit presentes. |
| g0-02 total-black | **KO** (base neutra, B3) | 23 %, base `#343339` **neutra** | Sin cambio. B3 es independiente del fondo. |
| g0-03 fondo-recargado | **KO** (graffiti come la paleta) | 39 %, base `#2C2832` (sat≈0,20 límite) | Mejora parcial: la **camisa clara reaparece** (`#A8AABB` 28 %); graffiti fuera. Base casi-neutra → **KO/borderline**. |
| g0-04 cuerpo-lejos | **KO** (2 % fg, 1 color) | 2 %, base `#3B4249` (sat≈0,19 límite) | **KO.** El sujeto es minúsculo: aun con máscara perfecta faltan píxeles. |
| g0-05 piel-oscura | **KO** (base neutra) | 58 %, base `#B1B3C6` **neutra** | Mejora (piel baja 22→14 %, no lidera) pero base = blazer lavanda neutro → **KO**. |
| g0-06 varias-personas | **KO** (ropa de otros) | 21 %, base `#5E4038` cromática (7 %) | **KO.** Aísla mejor al sujeto pero los **vaqueros siguen ausentes** y la base es un marrón del 7 % (¿pelo/bolso?). |
| g0-07 rayas | **OK** (base = rojo) | 52 %, base `#AF7459` (tono piel) | **OK→KO. Regresión** (ver 2.2). |
| g0-08 print piel-oscura | **OK** (base = mostaza) | 51 %, base `#A89C31` mostaza | Sin cambio. **OK**. |

**Neto: 2/8 → 2/8.** rembg sube g0-01 y baja g0-07. **No levanta ninguno de
los KO dominados por B4** (g0-04 sujeto minúsculo, g0-06 multi-persona). Las
máscaras de rembg son *cualitativamente mejores* (borra graffiti, peatones,
recorta fino), pero **la mejora de máscara no se traduce en gate** porque los
KO residuales son de B3/B1/B2, ajenos a la segmentación.

### 2.2 Hallazgo de acoplamiento (importante para cualquier cambio de quitafondo)

La regresión de g0-07 no es aleatoria: la máscara *más ajustada* de rembg hace
que la piel ocupe una **fracción mayor del primer plano**, lo que dispara el
guardarraíl `MAX_SKIN_FRACTION` (0,5) y **desactiva el filtro de piel entero**.
En g0-01 eso ayuda (el coral, que rozaba el tono de piel, sobrevive); en g0-07
perjudica (la piel de brazos/escote domina y se vuelve base). **Consecuencia:
el filtro de piel está calibrado contra las máscaras holgadas de GrabCut;
cambiar a un quitafondo más fino exige recalibrar `MAX_SKIN_FRACTION`.** Deuda
a anotar para quien toque el quitafondo (chroma-key incluido).

### 2.3 Tabla de tradeoffs

| Criterio | **GrabCut** (actual) | **rembg / U²-Net** | **Segmentación de ropa ML** (F2.5) | **Chroma-key** (fondo liso, §3) |
|---|---|---|---|---|
| Bugs que mata | ninguno de forma fiable; B7 pendiente | atenúa B4 (fondo), **no lo cierra**; regresa B1/B2 por acoplamiento | **B4, B6** y da pie a paleta por-prenda; **B2 duro** (prenda≈piel) | **B4 completo** + contaminación de fondo; B7 (determinista) |
| B3 (neutros) / B1-B2 (piel) | no | no | B1/B2 sí (separa piel de prenda); B3 no | **no** (piel y neutros siguen igual) |
| Latencia (medida, este equipo) | **2–5 s** | **6–7 s** (~2-3×) | por medir (gate G2.5 < 3 s móvil) | **<0,1 s** |
| Tamaño en disco | 0 (dentro de OpenCV) | **~225 MB** (onnxruntime 57 MB + u2net.onnx 168 MB) | modelo objetivo < 10-20 MB TFLite | **0** (numpy) |
| On-device (D2) | difícil (OpenCV pesado en móvil) | **no razonable** (225 MB + ORT) | **sí, es el plan** (TFLite/MediaPipe) | **sí, nativo** (aritmética por píxel) |
| Coste marginal | ~0 (local) | ~0 local; **≠0 si va a servidor GPU** (mata unit economics, PRD §8) | ~0 (on-device) | **~0** |
| Licencia | Apache-2 (OpenCV) | MIT (rembg) / modelo U²-Net Apache-2 | según modelo (revisar en F2.5) | n/a |
| Determinismo | **no** (B7, RNG global) | sí | sí | sí |
| Encaje | fallback razonable | **opcional servidor**, no plan on-device | diferenciador (F2.5) | **primary path del MVP con onboarding** |

**Recomendación de segmentación:** mantener la cascada. Añadir **chroma-key
como path primario** cuando el onboarding garantiza fondo liso (§3); dejar
**GrabCut como fallback** para fotos "salvajes"; ofrecer **rembg como extra
opcional de servidor** (`hq-bg`, ya instalable en 3.12) para calidad en el
backend local, **pero nunca como dependencia del port on-device** — su peso
(225 MB) y su latencia contradicen D2. El plan on-device de segmentación fina
sigue siendo MediaPipe/TFLite en Fase 2/2.5.

---

## 3. Evaluación técnica de la hipótesis del CEO (tutorial → fondo liso plano)

**Tesis del CEO:** un onboarding que pida fotografiarse sobre un fondo liso de
un color plano guía al usuario *y* le facilita el trabajo al algoritmo.
**Veredicto: correcta, y más potente de lo que parece.** Es una decisión de
producto que *convierte un problema de visión difícil en aritmética*.

### 3.1 ¿Permite sustituir GrabCut por algo trivial? Sí.

Con fondo de un color conocido, el quitafondo es *chroma-key*: marcar como
primer plano todo píxel a más de un `deltaE` del color de fondo (muestreado de
las esquinas). Lo probé sobre una escena sintética (fondo verde croma + outfit
de 3 colores):

```
chroma-key numpy puro: 96,8 ms   IoU vs máscara real = 1,000   fg = 24,7 %
paleta recuperada: rojo(210,70,60) 0,41 · azul(40,60,160) 0,32 · amarillo(230,220,40) 0,27
```

Segmentación **perfecta** (IoU 1,0), en **<0,1 s**, **numpy puro** (portable a
móvil sin modelo ni runtime), y la paleta sale limpia. Es estrictamente mejor
que GrabCut *y* que rembg en el caso controlado: más rápido, sin modelo, sin
dependencias, **determinista** (mata B7 de paso), coste marginal cero (D2).

### 3.2 ¿Qué bugs mata el fondo liso y cuáles sobreviven?

| Bug | ¿Lo resuelve el fondo liso? | Por qué |
|---|---|---|
| **B4** sujeto lejano / varias personas | **Sí** (con encuadre; ver 3.3) | El chroma-key segmenta perfecto; el tutorial encuadra al sujeto llenando el marco y pide "solo tú". |
| Contaminación de fondo (graffiti, peatones, B6 parcial) | **Sí** | No hay fondo que contaminar. |
| **B7** no-determinismo | **Sí** | Chroma-key no usa RNG. |
| **B3** outfit 100 % neutro | **No** | El negro/blanco del outfit es independiente del fondo. Requiere **modo lienzo (D10)**. |
| **B1/B2** piel del sujeto | **No** | La piel está *en* el sujeto, no en el fondo. Sigue dependiendo del filtro de piel (adaptativo #20) y de F2.5. Ojo: recalibrar `MAX_SKIN_FRACTION` (§2.2). |
| **B2 duro** prenda ≈ tono de piel | **No** | Solo lo resuelve la segmentación de ropa ML (F2.5). |

**Conclusión:** el fondo liso elimina *exactamente* la clase de bugs de
segmentación (B4, contaminación, B7) y deja intactos *exactamente* los bugs que
ya están (a) decididos (B3 → D10) o (b) diferidos por diseño a F2.5 (B1/B2).
No hay ningún bloqueante nuevo. Y como bonus: la batería g0 es el caso
*adversarial* (fotos reales sucias, sujetos lejanos, multitudes) — es decir, el
**peor caso**, no el caso del MVP. El 2/8 mide un mundo que el onboarding
elimina.

### 3.3 Qué pedirle al tutorial de UX (para ux-designer) para maximizar el beneficio

1. **Color del fondo:** liso, **mate** (no brillante: los reflejos rompen el
   umbral) y **lejano en color de la piel y de los neutros**. Recomiendo
   **verde o azul medio-saturado** (lógica greenscreen; además queda lejos de
   tonos de piel en LAB). **Evitar blanco/gris/negro** (colisionan con outfits
   neutros y hacen desaparecer la ropa negra) y **evitar beige/rosa/tierra**
   (se confunden con piel). Una pared o una sábana lisa sirve.
2. **Encuadre:** el outfit debe **llenar la mayor parte del marco** (regla:
   altura del sujeto > ~50 % del alto). Esto ataca el otro flanco de B4 (el
   sujeto minúsculo de g0-04, donde ni la máscara perfecta salva la paleta por
   falta de píxeles).
3. **Una sola persona** en el encuadre (elimina el flanco multi-persona de B4).
4. **Iluminación** uniforme y frontal; **sin sombras marcadas sobre el fondo**
   (una sombra crea un "segundo color de fondo" y ensucia el umbral).
5. **Cuerpo completo** visible si se quiere la paleta de todo el outfit.

Con estas 5 condiciones, el quitafondo pasa de "problema de CV" a "resta de
color", y el pipeline entra en su régimen bueno (el de los casos OK y el demo
sintético).

---

## 4. Recomendación: ¿avanzar a Fase 1 YA? — **SÍ**

Tomo partido: **sí, avanzar a Fase 1 ahora.** Justificación:

- El valor del producto (paleta + armonías) **ya funciona** cuando la entrada
  es razonable. Lo demostró el demo sintético y los casos OK.
- El gate G0 (2/8) **no es un veredicto sobre el algoritmo, sino sobre la
  entrada no controlada.** La decisión de producto del CEO (onboarding con
  fondo liso) *cambia la entrada*, y con ella el chroma-key resuelve B4 sin ML.
- Probé la alternativa "mejor segmentación" (rembg): **no mueve el gate**. No
  hay un arreglo de algoritmo pendiente que justifique retrasar la app. Seguir
  en Fase 0 sería optimizar el caso adversarial que el onboarding elimina.
- La prioridad declarada es un **MVP demoable cuanto antes, aunque falle en
  casos difíciles**. Fase 1 es precisamente construir el vehículo (app +
  onboarding) que *evita* los casos difíciles.

### Trabajo de algoritmo mínimo, antes o en paralelo a Fase 1

Poco, y todo barato y con test de regresión obligatorio:

1. **Modo lienzo D10 (B3)** — *antes de la demo*. Es el fallo más vistoso
   (proponer armonías de matiz arbitrario sobre un negro). Ya está decidido,
   falta implementarlo. Sin esto, cualquier outfit total-black/white en la demo
   queda mal. **Máxima prioridad de algoritmo.**
2. **Path chroma-key** — *en paralelo con la app*. `_remove_bg_chromakey` en la
   cascada (o modo explícito activado por el onboarding). ~1 día. Es la
   segmentación del MVP y el on-device es directo (numpy). Recalibrar
   `MAX_SKIN_FRACTION` para las máscaras más ajustadas (§2.2) y fijar regresión.
3. **B7 determinismo** — *trivial*. Las constantes `GRABCUT_RNG_SEED` y
   `GRABCUT_SEED_FRACTION` ya existen sin usarse; sembrar el RNG y pintar la
   caja-semilla. Deja el fallback GrabCut reproducible.

### Diferido explícitamente a Fase 2.5 (no bloquea Fase 1)

- Segmentación de ropa por prenda (F2.5) y con ella **B2 duro** (prenda ≈ piel,
  el coral de g0-01 a dE 1,6 del tono del sujeto) y **B6** (pelo como prenda).
- Residuo de **B1** (pelo / sombra profunda no separable por tono).
- Port on-device de la segmentación fina (MediaPipe/TFLite), Fase 2.

---

## 5. Preparación del backend (FastAPI local, Fase 1)

**¿Está `colorlab` listo para envolverse tal cual? Casi, con un refactor
pequeño pero necesario.** CLAUDE.md manda que el backend sea un envoltorio fino
y que *la lógica viva en la librería, nunca en los endpoints*. Hoy eso **no se
cumple del todo**: la orquestación del pipeline (quitafondo → filtrar → K-means
→ base → armonías) vive **solo en `cli.py`**. Si el endpoint la replicara,
estaríamos metiendo lógica en el endpoint. Refactor mínimo:

1. **Extraer un `pipeline.py` con una función pura de librería**, p. ej.:

   ```python
   def analizar_outfit(img: Image.Image, *, n_colores: int = 5,
                       quitar_fondo: bool = True, filtrar_piel: bool = True
                       ) -> ResultadoAnalisis: ...
   ```

   que devuelva un dato estructurado (dataclass) con: `paleta` (lista de
   `{hex, rgb, peso, es_neutro}`), `base_armonias` (hex), `armonias`
   (`{esquema: [hex, ...]}`), y opcionalmente tiempos. **Sin `print`, sin
   escribir ficheros.** `cli.py` y el endpoint FastAPI llaman ambos a esta
   función (la CLI añade el `print` y el `render_panel`). Esto es lo que hace
   del backend un envoltorio fino de verdad.

2. **Entrada desde bytes.** `load_image` hoy toma una ruta; `PIL.Image.open`
   acepta un `BytesIO`, así que basta permitir `str | Path | IO[bytes]` para
   recibir el `UploadFile` de FastAPI sin tocar disco (encaja con el procesado
   efímero del PRD §9 / GDPR).

3. **`render_panel` no es para la API.** Es matplotlib (pesado, orientado a
   fichero, para CLI/debug). El endpoint devuelve **JSON** (los hex y pesos ya
   los produce `hexstr`/`is_neutral`); el render visual, si se quiere, es una
   ruta aparte o se hace en el cliente Flutter con los tokens de color.

**Contrato de API propuesto (lo documento aquí; el OpenAPI lo generará
FastAPI):**

```
POST /analyze   (multipart/form-data: image=<archivo>)
200 →
{
  "paleta": [
    {"hex": "#43A9BE", "rgb": [67,169,190], "peso": 0.54, "es_neutro": false},
    ...
  ],
  "base_armonias": "#43A9BE",
  "armonias": {
    "Complementario": ["#43A9BE", "#BE5843"],
    "Analogo": ["#43BE9E", "#43A9BE", "#4358BE"],
    "Triadico": [...],
    "Complementario dividido": [...]
  },
  "modo_lienzo": false          // true si el outfit es 100% neutro (D10)
}
```

**Tiempos y gate G1 (< 10 s en dispositivo).** Medidos en este equipo,
end-to-end quitafondo+pipeline: **GrabCut 2–5 s**, **rembg 6–7 s**,
**chroma-key < 0,1 s** (+ K-means, décimas). En backend local (portátil del
CEO) cualquiera de los tres cabe en G1; on-device el único plan viable es
chroma-key/MediaPipe. Con chroma-key el análisis es prácticamente instantáneo,
lo que además deja margen para el rewarded ad de F8 sin que "se note" espera.

**Refactor total estimado:** ~0,5–1 día. No hay reescritura; es mover la
orquestación de `cli.py` a `pipeline.py` y aceptar bytes. Recomiendo hacerlo
como primera tarea de Fase 1, junto con el "chore idioma" que el PRD ya sitúa
al arrancar Fase 1 (si se aprueba, `analizar_outfit` nace ya en inglés).

---

## 6. ADRs y deuda técnica a registrar

Propongo abrir dos ADRs formales (`docs/adr/`), con su línea en PRD §10:

- **ADR-011 — Chroma-key como path primario de quitafondo del MVP**, habilitado
  por el onboarding de fondo liso; GrabCut como fallback; rembg opcional de
  servidor, nunca on-device (contexto/opciones/decisión/consecuencias con la
  evidencia de este informe).
- **ADR-012 — `colorlab.pipeline.analizar_outfit` como única entrada de
  librería**; CLI y FastAPI son clientes. Formaliza "el backend es un
  envoltorio fino".

**Deuda técnica nueva (con fase donde pagarla):**

| Deuda | Origen | Dónde se paga |
|---|---|---|
| `MAX_SKIN_FRACTION` calibrado contra máscaras holgadas de GrabCut; máscaras finas (chroma-key/rembg) lo disparan y desactivan el filtro de piel (regresión g0-07) | §2.2 | Fase 1, al añadir chroma-key (recalibrar + test) |
| B7: GrabCut no siembra su RNG (constantes existen sin usar) | §1, eval G0 | Fase 1 (trivial) |
| Orquestación del pipeline vive en `cli.py`, no en la librería | §5 | Fase 1 (ADR-012) |
| B3 modo lienzo decidido (D10) pero sin implementar | GATE-REVIEWS | Fase 1, antes de la demo |
| B1/B2 duros y B6 (piel≈prenda, pelo) solo resolubles con segmentación de ropa | §3.2 | Fase 2.5 (por diseño) |
| `rembg`/`onnxruntime` (~225 MB) instalados en el `.venv` local para este informe | §2 | Quitar cuando no se use; no forma parte del plan on-device |

---

### Nota de entorno

Para este informe dejé **`rembg` 2.0.76 + `onnxruntime` 1.27 instalados en el
`.venv`** (Python 3.12). La suite pasa 47/47 con ellos presentes. Si se quiere
volver al comportamiento "solo GrabCut" documentado en CLAUDE.md, desinstalar
ambos (`pip uninstall rembg onnxruntime`). El extra `hq-bg` del `pyproject`
sigue siendo la vía oficial para instalarlos donde se quiera calidad de
servidor.
