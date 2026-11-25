# Non-runtime source references

These files are deliberately outside Flutter's asset declarations.

- `us-universities.json`: the unchanged directory formerly used only by the
  retired local `UniversityPickerField` and its tests. The current campus picker
  uses the server catalog. Retaining this reference does not bundle it, load it
  into app memory, or clear any saved local university value.
