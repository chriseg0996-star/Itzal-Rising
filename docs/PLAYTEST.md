# Itzal Rising — Guion de Playtest V1 (A3)

Objetivo: cerrar `docs/BUGS_P0.md` con **0 P0** tras juego real. Los gates headless
prueban que arranca, que win/loss dispara y que save/load round-trippea; **este
pase manual valida lo que headless no puede**: navegación, economía de la IA,
combate y game-feel.

Clasifica cada hallazgo **P0** (crash / softlock / win-loss roto / save corrupto /
misión imposible) o **P1/P2**. Los P0 bloquean el lanzamiento.

---

## 1. Matriz de arranque jugable (skirmish)

Juega **hasta decidir** (ganar o perder) al menos un combo por facción y por mapa.
Mínimo obligatorio: la diagonal (cada facción en un mapa distinto) + los 3 niveles
de dificultad en Jungle Basin.

| Facción | Mapa | Dificultad | ¿Ganable? | ¿IA activa? | Notas |
|---------|------|-----------|-----------|-------------|-------|
| Itzal | Jungle Basin | Easy | ☐ | ☐ | |
| Itzal | Jungle Basin | Normal | ☐ | ☐ | |
| Itzal | Jungle Basin | Hard | ☐ | ☐ | |
| Decay | Sunken Reef | Normal | ☐ | ☐ | |
| Ix | Volcanic Crags | Normal | ☐ | ☐ | |
| Itzal | Azure Coast | Normal | ☐ | ☐ | |
| (extra libre) | | | ☐ | ☐ | |

Por cada partida confirma:
- **Nav**: villagers y ejército llegan a su destino, rodean bosques/chokepoints,
  no se quedan pegados ni vibran en un borde.
- **Economía IA**: en los primeros ~3-4 min la IA **construye Barracks, entrena
  unidades y ataca** (no se queda pasiva). *(No verificable headless — nav/economía
  distorsionan en `time_scale`; por eso es manual.)*
- **Win/loss real**: destruir todos los edificios enemigos → VICTORY; perder el TC
  → DEFEAT; la Beacon/Monument disparan su condición.

## 2. Economía y balance (sensación)

- Recolección de wood/food/gold fluida; los nodos grandes duran lo razonable.
- Comida por bayas/granja funciona; el Storehouse acorta el acarreo.
- Población/supply: al topar cap, construir Pylon/Casa lo sube; entrenar se bloquea
  correctamente cuando `usado+cola ≥ cap`.
- Ritmo: llegar a Era II/III se siente ganado, no eterno ni instantáneo.

## 3. Habilidades y sistemas

- Las 3 habilidades (E/R/Q) de cada facción se lanzan, aplican efecto y respetan
  cooldown. Emblemas/identidad de facción correctos.
- Cancelar en cola devuelve recursos.
- Rally point: clic derecho en el mapa con edificio de producción seleccionado.
- Beacon: cargar, recibir daño la pausa; carga completa = victoria.
  **Guardar a media carga y cargar → la carga persiste** (regresión P2-001).

## 4. Save / load en juego real

- Quicksave a mitad de partida (con cola de producción, rally, unidades en combate,
  investigación a medias) → Continue desde el menú → estado idéntico.
- Guardar durante el countdown del Monument → al cargar el reloj sigue donde iba.

## 5. Campaña

- Las 5 misiones + tutorial se completan; **limpiar una desbloquea la siguiente**
  (persistido). Modificadores (`eco_boost`, `fast_aggro`) se notan en juego.

## 6. HUD / UX bajo input real

- Selección: worker→build menu, militar→stances, edificio→producción, recurso→info
  (sin comandos). Multi-selección con unit cards; clic en card selecciona la unidad.
- Minimapa: clic centra cámara; botones +/- de zoom; ping de la Beacon.
- Pausa (Esc), controles (F1), game-end (Restart / Menú) funcionan.

---

## Registro de hallazgos

| # | P0/P1/P2 | Descripción | Repro (facción/mapa/dif/modo) | Estado |
|---|----------|-------------|-------------------------------|--------|
| | | | | |

Al terminar sin P0 abiertos, marca en `docs/SCOPE_V1.md` §3 el ítem
"`docs/BUGS_P0.md` muestra 0 P0 tras playtest manual".
