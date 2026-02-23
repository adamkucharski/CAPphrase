# Setup script for CAPphrase analysis
# Reads preprocessed CSVs from data/ and exposes
# df_raw, df_wide, df_pairwise, valid_terms for downstream scripts

# Required packages
required_packages <- c(
  "dplyr",        # Data manipulation
  "tidyr",        # Reshaping (pivot_wider, pivot_longer)
  "readr",        # CSV reading/writing
  "ggplot2",      # Plotting
  "stringr",      # String manipulation
  "forcats",      # Factor handling
  "tibble",       # Tibbles and tribble
  "scales",       # Axis formatting
  "ggridges",     # Ridgeline plots
  "viridis"       # Color palettes
)

# Install missing packages
install_if_missing <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
}

invisible(lapply(required_packages, install_if_missing))

# Load packages
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(stringr)
library(forcats)
library(tibble)
library(scales)
library(ggridges)
library(viridis)

# Load plot styling (fonts, theme, colors)
source("00_plot.R")

# Data directory (relative to R/)
data_dir <- "../data"

# Load valid terms
valid_terms <- read_csv(
  file.path(data_dir, "terms.csv"),
  show_col_types = FALSE
)$term

cat(sprintf("Loaded %d valid terms from terms.csv\n", length(valid_terms)))

# ── Read preprocessed CSVs ───────────────────────────────────────────────────
df_absolute <- read_csv(
  file.path(data_dir, "absolute_judgements.csv"),
  show_col_types = FALSE
)

df_pairwise <- read_csv(
  file.path(data_dir, "pairwise_comparisons.csv"),
  show_col_types = FALSE
)

df_metadata <- read_csv(
  file.path(data_dir, "respondent_metadata.csv"),
  show_col_types = FALSE
)

# ── Reconstruct df_raw (absolute judgements + metadata) ──────────────────────
df_raw <- df_absolute %>%
  left_join(df_metadata, by = "response_id")

# ── Remove outliers: responses > 4 SD from mean for each term ───────────────
outlier_threshold <- 4
n_before <- nrow(df_raw)

df_raw <- df_raw %>%
  group_by(term) %>%
  mutate(
    term_mean = mean(probability, na.rm = TRUE),
    term_sd = sd(probability, na.rm = TRUE),
    z_score = abs(probability - term_mean) / term_sd,
    is_outlier = z_score > outlier_threshold
  ) %>%
  filter(!is_outlier | is.na(is_outlier)) %>%
  select(-term_mean, -term_sd, -z_score, -is_outlier) %>%
  ungroup()

n_outliers <- n_before - nrow(df_raw)
cat(sprintf("Removed %d outlier observations (>%.1f SD from term mean)\n",
            n_outliers, outlier_threshold))

# Create wide format from raw data
df_wide <- df_raw %>%
  select(response_id, timestamp, term, probability,
         age_band, english_background, education_level, country_of_residence) %>%
  pivot_wider(
    id_cols = c(response_id, timestamp, age_band, english_background,
                education_level, country_of_residence),
    names_from = term,
    values_from = probability
  )

# Create output directory for plots
output_dir <- "../docs/output"
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# Print data summary
cat("Data loaded successfully!\n")
cat(sprintf("- Raw estimates: %d observations from %d respondents\n",
            nrow(df_raw), n_distinct(df_raw$response_id)))
cat(sprintf("- Wide estimates: %d respondents\n", nrow(df_wide)))
cat(sprintf("- Pairwise comparisons: %d observations\n", nrow(df_pairwise)))
cat(sprintf("- Respondents with age data: %d\n",
            sum(!is.na(df_raw$age_band) & df_raw$age_band != "")))
