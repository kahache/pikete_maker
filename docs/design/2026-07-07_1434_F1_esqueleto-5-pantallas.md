# Esqueleto MVP-demo — 5 pantallas (D12) · specs + mockups

| | |
|---|---|
| **Owner** | ux-designer |
| **Fecha** | 2026-07-07 |
| **Fase** | F1 · MVP-demo instalable, on-device, offline (D15) |
| **Alcance** | El esqueleto de 5 pasos exacto de D12. Nada fuera de él. |
| **Decisiones marco** | D7/D8/D9 (dirección visual) · D11/F13 (tutorial) · D12 (esqueleto) · D14 (logo) · D15 (pivote a demo) |
| **Fuente de verdad de valores** | `docs/design/tokens.json` (v1.2) |
| **Mockup navegable (CEO)** | `docs/design/mockups/skeleton-5-pasos.html` — los 5 pasos en una página |
| **Docs base (no re-litigar)** | `DESIGN_SYSTEM.md` · `onboarding-tutorial.md` · `user-flows.md` · `logo/LOGO.md` · `mockups/result.html` |

---

## 0. Qué es esto y qué NO es

Este documento consolida las **5 pantallas del esqueleto D12** en una sola historia
revisable, con wireframes, specs de componentes y copy. Es el material que el CEO
abre en el navegador (`skeleton-5-pasos.html`) para ver el demo "de punta a punta".

- **Pasos 4 (analizando) y 5 (resultado)** ya eran **canónicos** en
  `mockups/result.html`: aquí se referencian, no se rediseñan. El HTML del
  esqueleto los reproduce idénticos para contar la historia completa.
- **Paso 2 (onboarding)** tenía specs low-fi cerradas en `onboarding-tutorial.md`;
  aquí se elevan a hi-fi en el HTML (ver §7 sobre la única casilla abierta).
- **Pasos 1 (splash) y 3 (subir foto)** son **nuevos**: no existían mockup ni spec.
  Se especifican por completo abajo.

No inventa features: F5-lite (deep-links) y F6 (compartir story) salen del camino
crítico por D12 y quedan como fast-follow; en el esqueleto sus CTAs existen pero
no bloquean.

**Mapa de los 5 pasos → features:**

| # | Pantalla | Feature | Estado del asset |
|---|---|---|---|
| 1 | Abrir app (splash) | entrada de marca | **nuevo** (este doc) |
| 2 | Tutorial onboarding (2 sub-pantallas) | F13 | specs previas → hi-fi aquí |
| 3 | Subir foto (home + sheet origen) | F1/camino crítico | **nuevo** (este doc) |
| 4 | Analizando + hueco de ad | F8 | canónico (`result.html`) |
| 5 | Resultado: paleta + armonías | F3 + F4 | canónico (`result.html`) |

---

## 1. Paso 1 · Abrir app (splash / entrada)

Primer contacto. Objetivo triple: (a) marca en 1 segundo, (b) fijar el "esto va
solo, sin cuenta y sin red" que es el argumento del demo (D15), (c) puente al
tutorial (primer arranque) o al home (arranques posteriores).

```
┌─────────────────────────────── 390 ──┐
│  ●●● 9:41                             │
│                                       │
│                                       │
│                                       │
│              [ isotipo ]              │  ← isotipo D14 96px, centrado
│             PiketeMaker               │  ← wordmark D14 (Pikete morado / Maker turquesa)
│    Los colores de tu fit, con criterio│  ← tagline · body · textTertiary
│                                       │
│               (aire)                  │
│                                       │
│                 ◜◝                    │  ← spinner mint (bright, no textual)
│      ● 100% offline · sin cuenta      │  ← sello demo · caption · textTertiary
│              ── homebar ──            │
└───────────────────────────────────────┘
```

| Elemento | Token / componente | Notas |
|---|---|---|
| Isotipo | logo D14 (SVG inline, 96px) | Asta morada + panza turquesa `#17B598` + punto. Sin borde. |
| Wordmark | `Pikete` morado `#6C3FD1` + `Maker` turquesa `#17B598`, weight 800 | Nunca "Pikete" a solas (LOGO.md). |
| Tagline | `body` · `textTertiary` | La visión en una frase. Opcional; refuerza pitch. |
| Spinner | `action.bright` sobre `action.tint` | Elemento no textual (regla de `bright`). Solo si la carga on-device tarda; si es instantánea, se omite. |
| Sello "offline · sin cuenta" | `caption` · `textTertiary` | Marketing del demo: robustez sin red (D15). |

**Reglas.** Cero morado funcional (el morado del logo es logo, no UI). Fondo blanco
puro. Transición de salida con `motion.base` (200 ms). El turquesa `#17B598` aparece
**solo** dentro del logo — no se cuela como color de UI (nota abierta de LOGO.md
sobre convivencia con `action.bright`).

**Estados:**

| Estado | Qué se ve |
|---|---|
| Normal (carga rápida) | Logo estático, sin spinner, ~400 ms y fuera. |
| Carga on-device perceptible | Logo + spinner mint girando. |
| Primer arranque | Al terminar → onboarding (F13). |
| Arranques posteriores | Al terminar → home (paso 3). |

Copy: **tagline** "Los colores de tu fit, con criterio." · **sello** "100% offline · sin cuenta".

---

## 2. Paso 2 · Tutorial onboarding (F13)

Specs completas, copy y decisiones de flujo ya cerradas en
**`onboarding-tutorial.md`** (2 pantallas, saltable, permiso contextual). Aquí solo
lo imprescindible para el esqueleto; el HTML las eleva a hi-fi.

- **2a · Bienvenida** — lockup de marca + `display` con la propuesta de valor +
  CTA "Empezar" (mint) + "Saltar". Cero acento morado.
- **2b · Tip pro "Clava los colores"** — badge "Tip pro" (única dosis de morado),
  `display`, ejemplo BIEN/MAL con siluetas ilustradas (sin fotos → sin sesgo de
  cuerpo), 3 tips (hero = fondo liso), refuerzo, CTA "Hacer mi primera foto".

Indicador de progreso: **2 puntos** (pill activo en `action.ink`), añadido en el
hi-fi para que se lea como secuencia de 2 y refuerce que es corto.

Copy (de `onboarding-tutorial.md §3`, sin cambios): titulares "Los colores de tu
fit, con criterio." / "El truco para clavar los colores"; tips "Ponte frente a una
pared lisa de un solo color." · "Que se te vea el fit entero, de arriba abajo." ·
"Un paso atrás y con buena luz."; refuerzo "Cuanto más liso el fondo, mejor te leo
los colores."

**Casilla abierta (heredada, no la reabro):** el *matiz* exacto del fondo (claro
vs gris medio) sigue pendiente de reconciliar con backend (`onboarding-tutorial.md
§4`). El copy "de un solo color" está construido para absorber esa decisión con
**una sola palabra** — no bloquea el demo.

---

## 3. Paso 3 · Subir foto (home + sheet de origen)

D12 llama a este paso "subir foto (cámara/galería)". En el flujo es: **home de una
decisión** → **sheet de origen** (Cámara / Galería) → captura/confirmar → analizar.
El esqueleto lo representa con el home + el sheet abierto (el momento de decisión).

```
┌─────────────────────────────── 390 ──┐        ┌──────────── SHEET (sobre scrim) ──┐
│  PiketeMaker                     ⚙   │        │             ──── grab ────         │
│                                       │        │  ¿De dónde sacamos la foto?        │  ← title
│                                       │        │  Tu foto no sale del móvil:        │  ← caption · textTertiary
│             [ isotipo ]               │        │  se analiza aquí mismo.            │
│           Analiza tu fit              │  ← display
│   Una foto y tienes tu paleta y con   │  ← body │  ┌────────────────────────────┐  │
│         qué combina.                  │        │  │ 📷  Hacer una foto        › │  │  ← opción · ic mint
│                                       │        │  │     Cuerpo entero, fondo   │  │
│  ┌─────────────────────────────────┐ │        │  │     liso                   │  │
│  │        Analiza tu fit           │ │  ← CTA │  └────────────────────────────┘  │
│  └─────────────────────────────────┘ │        │  ┌────────────────────────────┐  │
│              ── homebar ──            │        │  │ 🖼  Elegir de la galería  › │  │
└───────────────────────────────────────┘        │  │     Una que ya tengas      │  │
                                                  │  └────────────────────────────┘  │
                                                  │  ◆ Fondo liso = colores más finos│  ← hint F13 (action.tint)
                                                  └────────────────────────────────────┘
```

| Elemento | Token / componente | Notas |
|---|---|---|
| Home top | wordmark pequeño + icono ajustes (`textTertiary`, 44px) | Ajustes es acceso discreto, fuera del pulgar. |
| Home hero | isotipo 64px + `display` "Analiza tu fit" + `body` | **Una sola decisión** (user-flows §1). |
| CTA home | `btn-primary` mint · pill · 56px · zona de pulgar | Abre el sheet. |
| Sheet | radius `lg`, `shadow-lg`, grabber, sobre `scrim` teñido (D9) | Bottom sheet; puede ser el del sistema estilizado. |
| Opción origen | fila 64px, icono en `action.tint`/`action.ink`, chevron mint | 2 targets grandes. |
| Sub del sheet | "Tu foto no sale del móvil: se analiza aquí mismo." | Refuerza privacidad + on-device (D15). |
| Hint fondo liso | banda `action.tint`, texto `action.ink` | **Red de seguridad F13** para quien saltó el tutorial. |

**Permiso de cámara: contextual.** No hay pantalla de permiso propia; se pide al
pulsar "Hacer una foto". Si se deniega → **E1** (`user-flows §2`), con galería
siempre como alternativa. Galería nunca es un muro.

**Pasos internos (mismo paso D12, no pantallas del esqueleto):** tras elegir origen
→ **captura con guías** (overlay cuerpo entero + hint fondo liso repetido) o
**selector del sistema** → **confirmar foto** ("¿Se ve bien tu fit?" · Analizar /
Repetir) → analizar. Specs en `user-flows §1` y §4 (pendientes de mockup hi-fi, no
bloquean el esqueleto).

**Estados del sheet / origen:**

| Estado | Qué se ve |
|---|---|
| Normal | 2 opciones + hint. |
| Cámara denegada permanente | Salta a E1 (no re-pide en bucle). |
| Sin foto elegida (cancela sheet) | Vuelve al home. |
| Confirmar foto | Foto + Analizar (primario) / Repetir (secundario). |

Copy: **home** "Analiza tu fit" / "Una foto y tienes tu paleta y con qué combina." ·
**sheet** "¿De dónde sacamos la foto?" · "Hacer una foto" / "Cuerpo entero, fondo
liso" · "Elegir de la galería" / "Una que ya tengas" · **hint** "Fondo liso =
colores más finos."

---

## 4. Paso 4 · Analizando (hueco rewarded ad, F8)

**Canónico en `mockups/result.html`** (pantalla "Analizando"). Sin cambios. Resumen:

- Copy hero "Leyendo los colores de tu fit…" + sub del paso actual del pipeline.
- **Progreso siempre visible arriba** (barra mint `bright` sobre `tint`, % en `action.ink`).
- **Hueco rewarded ad (F8)** en `surfaceSubtle` teñida, radius `lg`, contenedor máx
  4:5. Parte del layout desde el día 1 (D12): cuando entre AdMob (Fase 5) no se
  rediseña el flujo. En el demo el hueco muestra su etiqueta, sin ad real.
- El morado firma **una sola vez** ("ya casi").
- Al completar: revelación con `motion.reveal` (600 ms) — "el momento de la app".

**Estados** (de `user-flows §2/§3`): reintento automático silencioso al primer
fallo (E3) sin repetir ad; sin inventario de AdMob el hueco muestra un tip de
captura (el layout no salta); sin conexión no aplica en el demo on-device (E2
desaparece del camino crítico, D15).

---

## 5. Paso 5 · Resultado (paleta + armonías)

**Canónico en `mockups/result.html`**. Sin cambios. Resumen:

- **Card superior = objeto compartible (F6):** `display` "Tu paleta" + meta +
  paleta en bandas **proporcionales al peso** con hex/% en mono + línea BASE
  (badge morado, D5) + watermark. Diseñada para sobrevivir sin la UI (story 9:16).
- **Armonías (F4):** 4 filas tocables (Complementario / Análogo / Triádico /
  Complementario dividido) con tira de color + chevron mint. El tap parametriza el
  deep-link de "Ver looks así".
- **CTAs zona de pulgar:** "Ver looks así" (F5-lite, primario) + "Súbela a tu story"
  (F6, secundario).

**Nota de esqueleto (D12):** F5-lite y F6 son fast-follow post-MVP. En el demo, sus
CTAs pueden **quedar deshabilitados** o abrir un placeholder honesto ("Muy pronto")
sin romper la narrativa — el clímax del demo es *la paleta apareciendo*, no el
compartir. Ver §7, decisión para el CEO.

**Estados:** el caso "outfit 100% neutro" (modo lienzo, D10) y el caso sin
sujeto/paleta no fiable (E4) están definidos en `user-flows §2`; no entran en el
happy path del demo (se cubre con fotos hero curadas, D15).

---

## 6. Decisiones de diseño que tomé (y por qué)

1. **Splash con sello "100% offline · sin cuenta".** El argumento de venta del demo
   (D15) es "le das el móvil a un inversor y va sin red". Lo hago explícito en la
   primera pantalla: convierte una restricción técnica en mensaje de producto.
   Coste cero, cero morado funcional, coherente con minimalismo.
2. **Paso 3 = home + sheet, no una pantalla de "subir" aislada.** El camino crítico
   ya definido (`user-flows §1`) entra por el home de una decisión. Reutilizo ese
   patrón en vez de inventar pantalla nueva → menos superficie, coherencia con lo
   ya especificado. El sheet abierto es el "momento de subir foto" que pide D12.
3. **Hint de fondo liso repetido en el sheet.** F13 dice que el consejo debe
   reaparecer fuera del tutorial para no perder el de-risking si se salta. El sheet
   de origen es el primer punto natural; lo reforzará luego el overlay de captura.
4. **Sub del sheet "tu foto no sale del móvil".** Refuerza on-device/privacidad
   (D2/D15) justo donde el usuario entrega una imagen suya. Barato y confiable.
5. **Indicador de 2 puntos en onboarding.** Comunica "esto es corto" (2 pasos),
   alineado con la tensión activación de F13. No estaba en las specs low-fi; lo
   añado en hi-fi porque ayuda a la percepción de brevedad.
6. **HTML de los 5 pasos en una sola página.** Para el pitch, ver la historia
   completa de izquierda a derecha vale más que 5 archivos sueltos. Reutiliza el
   CSS de tokens de `result.html` (misma fuente de verdad, cero drift).
7. **Onboarding elevado a hi-fi pese a la casilla del matiz abierta.** El pivote a
   demo pide "que se vea pro"; la casilla abierta es una *palabra* del copy, no la
   estructura. Construyo con la recomendación actual ("de un solo color") y dejo la
   nota. No reabro §4 de `onboarding-tutorial.md`.

**Disciplina de marca verificada en las 5 pantallas:** mint solo en lo pulsable;
morado ≤ 2 dosis/pantalla (splash 0, onb-1 0, onb-2 1, subir-foto 0, analizando 1,
resultado 2); neutros teñidos; el turquesa `#17B598` vive **solo** dentro del logo.

---

## 7. Qué necesito del CEO / PM

1. **CTAs del resultado en el esqueleto (D12):** ¿"Ver looks así" (F5-lite) y "Súbela
   a tu story" (F6) van **deshabilitados**, con **placeholder "muy pronto"**, o
   **fuera** en el demo? Recomiendo *deshabilitados con placeholder honesto*: cuentan
   el roadmap sin prometer lo que aún no hace, y el clímax sigue siendo la paleta.
2. **Nº de pantallas del onboarding (heredado):** 2 (recomendado) vs 1 (mínimo).
   Sigue abierto de `onboarding-tutorial.md §8`.
3. **Matiz del fondo (heredado, ux ↔ backend):** cerrar "claro-neutro" vs "gris
   medio". Solo cambia una palabra del copy; no bloquea el demo, pero conviene
   cerrarlo antes de que mobile-dev fije el copy del overlay de captura.
4. **Splash con o sin spinner:** depende de cuánto tarde el arranque on-device en el
   dispositivo real. Es una pregunta para mobile-dev; lo dejo previsto (con y sin).

Nada de lo anterior bloquea que mobile-dev empiece a montar el esqueleto: las 5
pantallas están specificadas y el HTML es la referencia visual.
