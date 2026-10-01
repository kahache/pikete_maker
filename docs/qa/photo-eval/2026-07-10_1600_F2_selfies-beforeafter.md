# F2 — Selfies (31) before/after de #21/#22/#57

**Fecha:** 2026-07-10 · **Issue:** #23 (rama selfies) · **Muestra:** las 31
selfies reales del CEO (`samples/selfies/`, gitignored). AFTER = HEAD
(#21/#22/#57), BEFORE = commit padre (algoritmo pre-sesión), misma máquina /
backend **rembg** → el delta aísla los fixes. Reproducible:
`scratchpad/run_selfies_beforeafter.sh`. Es el dataset que representa el caso
real del MVP (espejo/neutros), a diferencia de Fashionpedia.

## Resumen (semántica KO corregida: NEUTRAL_BASE = canvas-mode, no KO)

| categoría | BEFORE | AFTER | delta |
|---|---|---|---|
| **KO real** (skin/collapsed/overfiltered/…) | 23 (74 %) | 22 (71 %) | −1 |
| **canvas-mode** (D10, ok) | 3 (10 %) | 7 (23 %) | **+4** |
| **clean** | 5 (16 %) | 2 (6 %) | −3 |

## Qué hicieron #21/#22/#57 (6 selfies cambiaron)

- **selfie17** — era **KO (base=piel `#978477`)** → **canvas mode** (outfit neutro,
  croma 0.5). **Arreglo claro.**
- **selfie23 / selfie24** — near-neutrals oscuros (croma 4.4 / 9.4) → canvas mode.
  selfie24 es el patrón #22 documentado (puffer navy + vaqueros). Correcto.
- **selfie21 (HERO, blazer navy)** — paleta 95 % `#383E4B` (croma **8.8**) → canvas
  mode. **Caso conocido, ver abajo.**
- selfie14 / selfie27 — siguen KO (piel), solo cambió la base. Sin efecto real.

Ningún selfie perdió una base cromática legítima hacia una peor; los heroes
mostaza (selfie01) y burdeos (selfie04) **no se movieron**.

## Hallazgo: el KO automático es RUIDOSO en selfies (más que en Fashionpedia)

Los flags fallan en ambos sentidos sobre esta distribución. Los propios heroes
que el CEO aprobó como "se ven bien" salen marcados KO:

| selfie | base extraída | flag KO | ¿real? |
|---|---|---|---|
| selfie01 (mostaza, hero) | `#B36F1E` = **la mostaza ✓** | `OVERFILTERED` | **Falso-KO** |
| selfie04 (burdeos, hero) | `#43171E` = **el top burdeos ✓** | `BASE_IS_SKIN` | **Falso positivo** (burdeos oscuro leído como piel) |
| selfie02 | `#9E9389` (gris) | `COLLAPSED_PALETTE` | outfit neutro → debería ser canvas, no KO |
| selfie03 | `#202024` (casi-negro) | `COLLAPSED_PALETTE` | ídem |

→ El "71 % KO" está **inflado por falsos positivos**, sobre todo el **proxy de
piel** (YCbCr/dE, crudo: confunde burdeos/marrón oscuro con piel). La señal real
de calidad es el ojo del CEO (3 heroes se ven bien), no el flag automático.

## Conclusiones

1. **#21/#22/#57 funcionan correctamente en el caso real**: 4 selfies
   correctamente a canvas mode, 0 regresiones de base cromática legítima.
2. **El KO real no baja** (~71 %) y está **dominado por piel/atribución +
   ruido de flags** → lo mueve la **Fase 2.5 (segmentación)**. Además, la clase
   de piel real de MediaPipe (D21) **retiraría el proxy YCbCr** que genera los
   falsos `BASE_IS_SKIN` (p.ej. selfie04). Doble motivo para priorizar 2.5.
3. **Caso conocido — selfie21 (navy blazer):** croma 8.8 cae bajo el umbral (13)
   → canvas mode. Es la zona gris navy≈neutro (selfie24, puffer navy, está en el
   mismo croma 9.4 → no hay umbral limpio que los separe). **CEO decide
   (2026-07-10): dejar canvas mode como provisional; la decisión real del navy
   la resuelve la segmentación (Fase 2.5), que sabría que el navy es prenda.**

## Artefactos

`outputs/selfies-eval/{before,after}.json` + panels (gitignored). n=31.
