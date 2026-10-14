# Scene wallpapers: why they render flat — diagnosis

_Phase 1 deliverable, 2026-09-27. No renderer code changed yet._

## Evidence gathered
- **Code read:** `scene_layers()`, `motion_terms()`, `compose_live()`, `compose()` in
  `scripts/wallpaper_library.py`.
- **Format scan** of all 172 scenes in `wallpaper phase 1 data` (aggregate only).
- **Visual comparison** of 8 heavy-effect scenes: Workshop preview vs current render
  vs a map of where the current loop actually moves.
- **The scenes' own shaders:** the packages ship Wallpaper Engine's effect GLSL
  (1,632 `shaders/effects/*` entries), so the real math was read, not guessed.

## Where information is lost, by pipeline stage

| Stage | What the data says | What the pipeline does | Scale |
|---|---|---|---|
| Effects (motion) | Per-pixel UV displacement inside **masks** and **flow maps** (waterwaves, waterripple, waterflow, shake), a corner-weighted warp (foliagesway), texture scroll, sine/threshold pulse | Replaces every effect with a **whole-layer x/y sine slide** of a hardcoded size | pulse 66 scenes, shake 62, ripple 59, waves 45, flow 32, sway 25, scroll 18 |
| Effect parameters | Speed, strength, scale, direction, phase, friction, per-shader defaults | Reads only shake's speed/strength; everything else is a constant | all effect uses |
| Masks / flow maps | Nearly every effect use carries its own mask texture | Never loaded | ~900 effect uses with a mask |
| Invented motion | Camera parallax in these scenes is **mouse-driven** (`cameraparallaxmouseinfluence`) | Adds an automatic camera orbit the data doesn't describe | every live loop |
| Keyframed properties | `animation` tracks with bezier keys, fps, length, loop/mirror mode on alpha, scale, origin, colour, effect params | `value()` keeps the static value and discards the track | 15 scenes |
| Sprite-sheet layers | Frame-timed animated textures | **Dropped entirely** | 47 layers in 9 scenes |
| Colour / brightness | Object colour tint and brightness | Ignored | 78 tinted layers, 37 with brightness |
| Hierarchy | Parent transforms include **rotation** | Parent rotation ignored (translation and scale only) | 21 child layers |
| Anchoring | `alignment` (left, right, bottomleft…) | Always centred | 24 layers |
| Background copies | `copybackground` layers refract what is behind them (water reflections) | Skipped as "no picture" | ~50 layers |

**Root cause:** the pipeline treats a scene as *pictures plus motion hints*, and then
invents the motion. The data is actually a *shader program per layer*. Every loss
above follows from not executing that program.

## Why "port each effect" doesn't work
Each package ships its **own copy** of each effect shader, and they differ between
packages: 3–7 versions per effect across these 172 scenes. The versions move
texture slots (the normal map is `g_Texture1` in some versions and `g_Texture2` in
others), rename parameters (`ripplestrength` vs `ui_editor_properties_ripple_strength`),
and change the math (shake gained a 4-sine mix, direction modes and audio variants).
A hand-port of one version renders the others wrong.

## Options

| | Approach | Fidelity | Cost / risk |
|---|---|---|---|
| **A (recommended)** | Run the scene's **own shipped shaders** in an offscreen OpenGL context inside the offline importer; bake to video exactly as today | Highest: every version, every parameter, every mask, in the author's own code | OpenGL is a system framework but deprecated; it's confined to the importer, and already-rendered wallpapers are plain videos either way. Feasibility measured: 55/78 shader versions compile unmodified; the other 23 need two engine headers that aren't shipped (blend-mode helpers), written once |
| B | Translate the shaders to Metal with glslang + SPIRV-Cross | Same as A | Two new Homebrew dependencies and a translation layer |
| C | Hand-port each effect to Metal | Correct for the ported version only | This is the per-version special-casing the brief rules out; every future version needs a new port |

In every option the app's runtime playback path (AVFoundation, pausing,
multi-display) is untouched. Only how the loop is *made* changes.

## Assumptions any option must make (to be logged, not hidden)
- The engine-internal **blend-mode enum** and **object colour-tint shader** aren't
  shipped. The standard 30-mode list is assumed; any mode outside it is reported.
- **Mouse parallax has no input** in a wallpaper that plays behind windows, so
  scenes whose *only* motion is parallax would become sharp stills unless you
  want an explicit, opt-in ambient drift.
- **Audio-reactive** variants (`AUDIOPROCESSING`) have no audio. They are rendered
  at their silent state and reported.
