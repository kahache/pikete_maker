# Análisis del ground truth del CEO — revisión manual batería-200 (50 filas)

- **Fecha:** 2026-07-09 · **Fase:** F1 · **Autor:** QA Engineer
- **Fuente:** `docs/qa/photo-eval/2026-07-08_F1_revision-manual-bateria-200.xlsx`, hoja "Revisión",
  filas 1-50 (col H = veredicto CEO, col I = observaciones).
- **Cruce:** `outputs/bateria-100/resultados.json` (semilla 42, n=200).
- **Informe previo:** `docs/qa/photo-eval/2026-07-07_1225_F0_bateria-200.md`.
- **Estado de la muestra:** 50 de 125 KO-auto revisadas. **Las 50 llevan flag BASE_ES_PIEL**
  (son las primeras 50 del bloque BASE_ES_PIEL, que tiene 79 filas; los bloques
  BASE_NEUTRA (24), PALETA_COLAPSADA (8) y SOBREFILTRADO (14) están sin revisar,
  igual que las 75 OK-auto). Todo lo que sigue extrapola SOLO dentro del bloque BASE_ES_PIEL.

Veredictos CEO sobre las 50: **13 OK (26%) · 18 KO (36%) · 19 DUDA (38%)**.

---

## 1. Precisión del flag BASE_ES_PIEL

Sobre 50 fotos donde el flag saltó:

| La base era… | n | % | Filas |
|---|---|---|---|
| **Piel de verdad** (flag acierta) | **8** | **16%** | 14, 15, 17, 18, 21, 32, 45, 48 |
| Prenda color-piel legítima (vestido, suéter, medias) | 4 | 8% | 1, 5, 10, 27 |
| Color correcto de prenda/imagen (resultado bueno pese al flag) | 11 | 22% | 4, 19, 22, 23, 29, 33, 35, 36, 37, 39, 50 |
| Color del FONDO (bien extraído, mal atribuido) | 20 | 40% | 2, 3, 6, 7, 9, 11, 12, 13, 16, 20, 25, 26, 30, 31, 41, 43, 44, 46, 47, 49 |
| Piel solo en color secundario (base correcta) | 4 | 8% | 24, 28, 34, 40 |
| Otros (pelo=38, ni piel ni fondo=8, nada corresponde=42) | 3 | 6% | 8, 38, 42 |

**Precisión del flag: 8/50 = 16%** (24% si se cuenta piel en cualquier posición de la paleta,
no solo la base). El flag es, en la práctica, un detector de "color tierra/beige en la base",
no de piel.

### Cruce con `de_base_piel` del JSON: ¿hay umbral que separe?

**No.** Las distribuciones se solapan por completo:

| Categoría | n | min | mediana | max |
|---|---|---|---|---|
| Piel real (TP) | 8 | 3,62 | 8,09 | 17,76 |
| Prenda color-piel legítima | 4 | 4,10 | 11,06 | 21,82 |
| Resultado correcto | 11 | 4,82 | 16,33 | 21,44 |
| Fondo | 20 | 3,05 | 10,00 | 23,87 |

Barrido de umbrales (criterio: `de_base_piel <= u`):

| Umbral | Piel real capturada | Falsos arrastrados |
|---|---|---|
| ≤ 5 | 2/8 | 11/42 |
| ≤ 8 | 4/8 | 15/42 |
| ≤ 12 | 5/8 | 21/42 |
| ≤ 16 | 7/8 | 29/42 |

A cualquier umbral, los falsos superan a los aciertos ~3:1 o peor. La distancia colorimétrica
a piel **no contiene la información necesaria**: distinguir "piel" de "vestido camel" o
"pared beige" es un problema semántico (¿de quién es ese píxel?), no colorimétrico.

---

## 2. Taxonomía de las 50 observaciones del CEO

Categoría primaria por foto (una por fila; solapes anotados):

| Categoría emergente | n | % |
|---|---|---|
| **Fondo no discriminado, pero color del fondo BIEN extraído** | 20 | 40% |
| Resultado correcto pese al flag (falso positivo puro) | 11 | 22% |
| Piel real como base (el flag acierta) | 8 | 16% |
| Prenda color-piel legítima bien extraída (medias/suéter/vestido) | 4 | 8% |
| Piel en color secundario, base correcta | 4 | 8% |
| Paleta incompleta / no corresponde | 1 (+2 solapes: filas 9, 20) | 2% |
| Pelo como color dominante | 1 | 2% |
| Sin causa clara ("ni piel ni fondo") | 1 | 2% |

Lectura transversal: en **~35/50 (70%)** de las fotos el CEO dice que los colores extraídos
son correctos como colores DE LA IMAGEN; el fallo (cuando lo hay) es de **atribución**
(fondo/piel/pelo contados como prenda) o de **peso** (fila 1: "el porcentaje debería ser
menor"). Solo en ~3 filas (9, 20, 42) el CEO señala colores que faltan o no corresponden —
fallo de extracción propiamente dicho.

---

## 3. Estimación honesta de la tasa de KO real

La cifra auto era 62,5% (125/200). Con el ground truth parcial:

- Dentro del bloque BASE_ES_PIEL (79 fotos, muestra de 50): KO real entre **36%**
  (DUDA→OK) y **74%** (DUDA→KO). Nota: muchas DUDAs son "colores bien, atribución mal",
  es decir, KO contra el criterio *ropa* pero OK contra el criterio *paleta de foto entera*
  que es el que rige el MVP-demo (D15).
- Bloques BASE_NEUTRA/PALETA_COLAPSADA/SOBREFILTRADO (46 fotos): sin revisar. Rango 0-100%.
- OK-auto (75 fotos): sin revisar → falsos negativos desconocidos.

**Rango sobre las 200:**

| Escenario | Cálculo | KO real |
|---|---|---|
| Optimista (DUDA→OK; otros bloques como éste; 0 falsos negativos) | 0,36×125/200 | **≈ 22%** |
| Pesimista (DUDA→KO; los 46 sin revisar todos KO; 0 falsos negativos) | (0,74×79+46)/200 | **≈ 52%** |

**Rango honesto: 22-52%**, casi con seguridad por debajo del 62,5% auto — los flags
sobre-reportan. Para cerrar la cifra falta: (a) las 29 filas restantes de BASE_ES_PIEL,
(b) las 46 de los otros tres bloques (los flags son distintos; no extrapolables), y
(c) una muestra de ≥20 OK-auto para medir falsos negativos. También conviene que el CEO
fije el criterio de las DUDA (¿KO contra ropa o contra foto entera?): mueve 15 puntos.

---

## 4. Veredicto sobre las 2 hipótesis del CEO

### H-a: "BASE_ES_PIEL no siempre es piel; a menudo es el fondo mal discriminado, pero el color del fondo se ACIERTA. Sería perfecto para fotos de producto (zapatillas)."

**CONFIRMADA con datos.** El flag solo acierta piel en 8/50 (16%); la categoría dominante
es "fondo colado con color correcto" (20/50, 40%); y en ~70% de las fotos los colores
extraídos son correctos como colores de la imagen. El problema dominante es **ATRIBUCIÓN
semántica, no EXTRACCIÓN**. Implicaciones:

1. Refuerza que la solución de fondo es **Fase 2.5** (segmentación de ropa con ML): ningún
   ajuste colorimétrico (umbral, distancia, guardarraíl) resuelve "¿este beige es pared,
   piel o gabardina?".
2. Da evidencia empírica a **ICEBOX I1 (modo producto/zapatillas)**: en foto de producto no
   hay piel y el fondo suele ser liso/controlado, es decir, desaparecen exactamente las dos
   causas de KO. El extractor "casi funciona ya" para ese caso de uso — con la ventaja de
   que 21/50 fotos con fondo "liso" también están en la muestra y el patrón se mantiene.

### H-b: "Con 1 vestido de un solo color, a veces da error pero se matchea bien."

**CONFIRMADA (n pequeño).** Filas 1 (vestido), 10 (suéter), 5 y 27 (medias): el flag salta,
pero la base es la prenda y el color coincide ("se aproxima al color real del suéter",
"el color es correcto en el vestido"). 4/50 casos, todos consistentes con la hipótesis;
ninguno la contradice.

### Consecuencia para el fix propuesto en #29 (excluir de la base colores a distancia-de-piel)

**Con este ground truth, PERJUDICARÍA más de lo que ayuda.** Números:

- Ganancia máxima: arregla las 8 bases que sí son piel (16%).
- Daño directo: rompe las 4 prendas color-piel legítimas (filas 1, 5, 10, 27) y varias de
  las 11 bases correctas que caen bajo el umbral (p. ej. fila 39, `de_base_piel` 4,82;
  fila 1, 4,10 — la prenda legítima más "piel" de todas).
- Y no hay umbral que lo salve (§1): a umbral ≤8 arregla 4 pieles reales pero excluye 15
  bases que NO eran piel; a umbral ≤16 arregla 7 pero excluye 29.
- En las 20 de fondo, excluir la base ni siquiera garantiza mejora: el siguiente candidato
  puede ser otra vez fondo.

Recomendación sobre #29: **replantear el issue**. El diagnóstico original ("el guardarraíl
desactiva el filtro de piel y por eso 39,5% de KO") queda desmentido por el ground truth:
la piel real solo explica ~16% del bloque; el fondo explica ~40%. El fix por
distancia-de-piel no debe implementarse tal cual ni en Python ni en el port Dart de #40.

---

## 5. Re-priorización recomendada de la deuda

1. **#29 — DEGRADAR y reescribir.** De "prioridad 1" a bloqueado-por-datos: la causa nº1
   real no es el filtro de piel, es el fondo. Reetiquetar como "detección de piel requiere
   señal semántica (→ Fase 2.5)"; cerrar la vía del umbral colorimétrico con este informe
   como evidencia.
2. **#40 — misma advertencia.** Propone la misma vía ("excluir de la BASE cualquier color a
   distancia de piel") para el camino demo en Dart. Este análisis muestra que esa vía tiene
   16% de precisión y daña prendas legítimas. Mantener la mitigación ya activa (curación de
   fotos hero, #33) como LA solución del demo; no portar el fix colorimétrico.
3. **SUBIR: discriminación de fondo.** Es el 40% del bloque revisado y no tiene issue
   propio como tal (el quitafondo es Fase 2.5, pero un heurístico barato tipo "descontar el
   color del borde de la imagen cuando bg_std es bajo" podría atacar los 21 casos de fondo
   liso sin ML). Proponer issue nuevo, prioridad por delante de #29.
4. **SUBIR: ICEBOX I1 (modo producto/zapatillas).** Pasa de icebox a candidato con
   evidencia: es el caso de uso donde el algoritmo actual ya rinde. Decisión de producto
   para el CEO/PM, pero QA certifica que el soporte empírico existe.
5. **#22 y #21 — mantener.** Sin datos nuevos en esta muestra (los bloques BASE_NEUTRA /
   PALETA_COLAPSADA / SOBREFILTRADO, donde viven B5/B8 y el modo lienzo, están sin
   revisar). Revisarlos es el siguiente paso natural de la revisión manual.
6. **Cerrar la medición:** cuando el CEO complete las 75 KO-auto restantes + muestra de
   OK-auto, re-emitir la tasa KO real y actualizar `CLAUDE.md` (el "62,5%" citado ahí ya
   sabemos que sobre-reporta).

---

## Anexo: clasificación fila a fila (QA a partir de col I del CEO)

- TP piel real: 14, 15, 17, 18, 21, 32, 45, 48
- Prenda color-piel legítima: 1, 5, 10, 27
- Correcto pese al flag: 4, 19, 22, 23, 29, 33, 35, 36, 37, 39, 50
- Fondo mal atribuido: 2, 3, 6, 7, 9, 11, 12, 13, 16, 20, 25, 26, 30, 31, 41, 43, 44, 46, 47, 49
- Piel secundaria: 24, 28, 34, 40
- Otros: 8, 38, 42

Reproducible: cruce hecho con openpyxl + `outputs/bateria-100/resultados.json` (campos
`de_base_piel`, `fg_frac`, `skin_frac`, `bg_std`). El xlsx del CEO no se ha modificado.
