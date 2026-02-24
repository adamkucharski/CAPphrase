[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.18750055.svg)](https://doi.org/10.5281/zenodo.18750055)

# CAPphrase

Comparative and Absolute Probability phrase dataset, based on an [online quiz](https://probability.kucharski.io/) created as an independent project by Adam Kucharski.

You can view visualisations and preliminary analysis [here](https://adamkucharski.github.io/CAPphrase/). And you can read more about the history of probabilistic judgement in [my recent blog post](https://kucharski.substack.com/p/possibly-a-serious-possibility).

## Datasets

The `data/` folder contains preprocessed CSVs ready for analysis. This version contains data from 5,174 quiz participants.

### Comparative estimates: [`pairwise_comparisons.csv`](data/pairwise_comparisons.csv)

| Column | Description |
|---|---|
| `response_id` | Unique respondent identifier |
| `pair_id` | Pair sequence number within the respondent's session (1--10) |
| `term1` | First term shown |
| `term2` | Second term shown |
| `selected` | The term the respondent chose as higher probability |

### Absolute estimates: [`absolute_judgements.csv`](data/absolute_judgements.csv)

| Column | Description |
|---|---|
| `response_id` | Unique respondent identifier |
| `term` | Probability phrase |
| `probability` | Numerical estimate (0--100) |
| `order` | Presentation order of this term for the respondent |

### Individual metadata: [`respondent_metadata.csv`](data/respondent_metadata.csv)

| Column | Description |
|---|---|
| `response_id` | Unique respondent identifier |
| `timestamp` | Submission month (YYYY-MM) |
| `age_band` | Self-reported age band (e.g. "25-34") |
| `english_background` | English language background |
| `education_level` | Highest education level |
| `country_of_residence` | Country of residence |

## Citation and licence

**Citation:** Kucharski AJ (2026) CAPphrase: Comparative and Absolute Probability phrase dataset. DOI: 10.5281/zenodo.18750055

**Licence:** [CC-BY](https://creativecommons.org/licenses/by/4.0/)

## Methods

The quiz had three parts, administered in a single session:

1. **Part 1: Pairwise comparisons.** Respondents are shown pairs of probability phrases and asked which phrase conveys a higher probability. Each respondent sees 10 pairs (9 unique + 1 repeated pair for internal consistency checking).

2. **Part 2: Absolute probability estimates.** Respondents enter a numerical value (0--100%) for each of 19 probability phrases. The presentation order is randomised per respondent.

3. **Demographics.** Optional questions on age band, English language background, education level, and country of residence.

All data was collected anonymously; the quiz website did not collect any personal data (e.g. IP addresses, device identifiers, browser fingerprints, or location data). Participants were informed that the full dataset would be made publicly available in Feb 2026.

### Randomisation

- From the 19 terms, 18 are randomly sampled (the largest even number <= 19).
- The 18 terms are shuffled and paired sequentially to produce 9 unique pairs.
- Within each pair the left/right order is randomised.
- A 10th pair repeats the first pair with terms swapped, providing an internal consistency check.
- Phrase presentation order for Part 2 is independently randomised per respondent.

### Outlier removal

Before analysis, responses that fall more than 4 standard deviations from their term's mean are removed. This guards against misreadings on otherwise narrowly interpreted phrases (e.g. "Highly Unlikely" interpreted as "Highly Likely"), without affecting phrases that have a lot of variability in interpretation (e.g. "Might happen").

## Analysis scripts

All scripts are in `R/` and are run via `run_all.R`:

```bash
cd R
Rscript run_all.R
```

| Script | Description | Key outputs |
|---|---|---|
| `00_setup.R` | Load preprocessed data, set up plot styling | `df_raw`, `df_wide`, `df_pairwise` |
| `01_probability_words.R` | Distribution of probability estimates per term | `01_*.png` |
| `02_inconsistent_pairs.R` | Pairwise consistency heatmap + Part 1 vs Part 2 inconsistency | `02_*.png`, `02b_*.png` |
| `02c_pairwise_disagreement.R` | Inter-respondent disagreement on pairwise choices | `02c_*.png` |
| `03_position_effect.R` | Presentation position/order effects | `03_*.png` |
| `06_demographics_and_pairs.R` | Demographic tables + pair frequency summary | `06_*.png`, CSV tables |
| `07_individual_patterns.R` | Individual-level response patterns | `07_*.png` |
| `08b_demographic_effects_position.R` | As above, with list position effect | `08_*_position.png` |
