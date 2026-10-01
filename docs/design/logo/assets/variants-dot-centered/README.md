# Variante DOT-CENTERED del icono (issue #50 — pendiente de veredicto del CEO)

Candidata B de la hoja `docs/design/2026-07-09_F1_r5-visual-decisions.html`.
**NO sustituye a los assets actuales** (bbox-centered) hasta que el CEO elija
en dispositivo; el PM cablea la ganadora y entonces se codifica la regla en
`USAGE.md §5`.

Regla de esta variante: **ancla horizontal = centro del punto negro** (el
piquete, cx 43.6 en unidades de símbolo) en el centro del lienzo. La vertical
se mantiene bbox-centered (centro y=48): la observación del CEO es solo
horizontal, y anclar también en vertical hundiría la marca 10u.

Consecuencia medida (escaneo de píxeles):

| Asset | L / R actual (bbox) | L / R dot-centered |
|---|---|---|
| ic_launcher_foreground 432 | 150 / 150 | 163 / 137 |
| app-icon 512 | 184 / 184 | 197 / 170 |
| app-icon 48 | 17 / 17 | 18 / 15 |

Desplazamiento: +4.2u (~9.6% del ancho del glifo) a la derecha. Verificado:
el contenido sigue dentro del círculo seguro de 66 dp del adaptive icon
(punto más lejano del centro: 120 px < 132 px de radio seguro a 432 px).

Colores y geometría congelados intactos (anti-hairline −0.4u incluido).
Generador: script PIL con supersampling ×8, misma geometría de LOGO.md.
