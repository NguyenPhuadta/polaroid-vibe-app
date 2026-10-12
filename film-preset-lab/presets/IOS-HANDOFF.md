# Indoor Flash Print v1 — approved implementation

Use `../app.js` and `indoor-flash-print.json` together. The JSON records parameters; app.js is the complete rendering reference, including grain and softness math. Use the original `../assets/gmic-px680.png` and keep attribution from `../assets/ATTRIBUTION-gmic.txt`.

## Processing order

1. Decode the image with orientation applied. Prototype scales the long edge to at most 1600 pixels and reads through an sRGB canvas.
2. `indoorTint` with amount 0.19: multiply RGB by [1.0228, 0.9772, 1.0228], clamp to 0–255. This operates on encoded sRGB values, not linear RGB or a RAW white balance.
3. Sample PX-680 HaldCLUT with `sampleLut` (red-fastest trilinear interpolation), mix 88% LUT output with 12% tinted input. Output is assigned to Uint8ClampedArray before the next step.
4. Run `printColor`: luma [0.2126, 0.7152, 0.0722], saturation 0.82, exponent 1.12, floor [11,7,6], ceiling [250,245,235]. Again assign to Uint8ClampedArray.
5. `applyDisposable(image, 1, true)`. The boolean true selects the recipe's **no-color-cast** branch: it skips faded black point and warm/cyan cast but retains softness, grain and vignette. Its vignette coefficient is 0.23, not the other branch's 0.13. Use the original grain/hash and channel-noise math in app.js.
6. Add the paper frame when exporting with `printCanvas`. Border/top = round(width × 0.055), bottom = round(width × 0.19), background #eeeae0, no crop.

## Verification on iOS

Compare the same decoded image at 1200×1600 against browser export first. Match sRGB interpretation, intermediate clamping/rounding, orientation, LUT axes and deterministic grain. A higher-resolution render requires an explicit grain-size decision; the current recipe uses pixel coordinates. Save original image + recipe version + texture seed so edits can be reproduced.

Approved controls: LUT 88%, texture 100% enabled, Tint +19, paper frame enabled. Tint numbers are prototype-specific. This recipe does not recreate physical flash lighting and has not been calibrated against film scans. Personal test photos and exports are not included in the repository.
