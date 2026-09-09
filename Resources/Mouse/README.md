# Mouse images

`naga-perspective.png` is the generated perspective cutout used by the side-button editor. It is 1024 x 1536 with a real alpha channel. Its hotspot coordinates live in `MouseHotspot.side`.

`naga-top.png` is the transparent top product image from the [Razer product page](https://www.razer.com/gaming-mice/Razer-Naga-V2-HyperSpeed/RZ01-03600100-R3U1). Its canvas is 1500 x 1000. Keep its transparent margins because the top control coordinates include them. Product photography and trademarks belong to Razer; the repository's MIT code license does not transfer rights to those assets.

## Generation record

Tool: Codex built-in `image_gen`, no CLI image generation.

References: the [Razer programmable-controls illustration](https://assets2.razerzone.com/images/pnx.assets/09bfb47da5dc6380d567a49e9551bafb/razer-naga-v2-hyperspeed-programmable-controls-1920x600-new.webp) and the official top photograph.

Initial prompt:

> Use case: precise-object-edit. Asset type: product photograph for an interactive macOS mouse configuration interface. Make one isolated Razer Naga V2 HyperSpeed mouse on a genuinely transparent background with preserved alpha. Reference 1 is the geometric source of truth: preserve that exact three-quarter view, its front at the top and visible left thumb panel, surface materials, precise proportions, and exact 4 rows of 3 thumb buttons labeled 1 2 3 / 4 5 6 / 7 8 9 / 10 11 12. Remove every bright green circular annotation and every callout including +12. Reference 2 shows the complete shape of the same model for restoring the cropped bottom in reference 1. Show the complete mouse centered, comfortably inside the image with 6 percent transparent margin, no other object. Keep the camera angle and button geometry of reference 1. Photorealistic studio product cutout, neutral lighting with soft edge highlights so the black plastic is readable on both light and dark UI backgrounds. No environment, no floor, no cast shadow, no glow. Retain only the actual small physical button numerals and embossed Razer emblem. No added text, watermarks, graphic UI, neon lights, or invented controls. Portrait composition.

Correction prompt:

> Use case: background-extraction. Remove the entire white and grey checkerboard surrounding the mouse. The checkerboard is an unwanted opaque background. Deliver a true transparent PNG with an actual alpha channel and fully transparent pixels outside the mouse, NOT a painted checkerboard. Preserve every pixel of the mouse, all 12 side buttons, exact numbering, geometry, camera, dimensions, position and neutral lighting. No shadows outside the object. No change to the mouse. Do not represent transparency using any visible pattern, solid fill, grey or white.

Both generated outputs contained an opaque checkerboard. The user explicitly approved local background removal and selected the second output. The final mask isolates the connected dark mouse silhouette, fills internal holes and smooths the inner edge. Foreground RGB values were preserved. The cutout was checked on light and dark backgrounds. Do not replace it with an opaque checkerboard or regenerate it for routine UI changes.
