# Non-runtime source references

These files are deliberately outside Flutter's asset declarations.

- `us-universities.json`: the unchanged directory formerly used only by the
  retired local `UniversityPickerField` and its tests. The current campus picker
  uses the server catalog. Retaining this reference does not bundle it, load it
  into app memory, or clear any saved local university value.
- `flyprox-logo-original.png`: unchanged 1254×1254 RGB PNG source
  (SHA-256 `de8e22c509264e4f371b445f3db67762c81ae9b7ea50a7cbec54897aa50424a1`).
  The runtime asset is a 512×512 PNG generated with Pillow 12.1.1:
  `image.resize((512, 512), Image.Resampling.LANCZOS).save(path, optimize=True)`.
  This exceeds the 448 physical pixels needed by the largest 112 logical-pixel
  call-site at 4× density. No crop, palette reduction or JPEG conversion is used.
