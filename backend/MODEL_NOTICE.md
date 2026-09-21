# Model and data notices

The backend downloads the pinned model repository
[`AmeerHesham/distilhubert-finetuned-baby_cry`](https://huggingface.co/AmeerHesham/distilhubert-finetuned-baby_cry)
at startup. The model card declares the model under Apache License 2.0. Review
that license and the current model card before redistributing or offering the
service beyond a private evaluation.

The model card says the model was trained using the Donate-a-Cry corpus. The
corpus has separate data terms and attribution requirements; the app does not
copy or redistribute its recordings. The corpus maintainers state that the
uploaded clips were not independently verified and that labels can be a
contributor's suspected reason for crying. Those labels are not medical
assessments.

The pinned model is a research preview. Its reported test split does not show
that it generalizes to a baby excluded from training, and the output score is
not calibrated. Baby Monitor returns only the model's top-ranked label and
does not present that label as a diagnosis or a measured probability.
