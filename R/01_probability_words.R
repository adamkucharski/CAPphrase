# Weaseliest Words plots
# Outputs: 01_words_means.png, 01_words_yardsticks.png

source("00_setup.R")

if (!requireNamespace("ggbeeswarm", quietly = TRUE)) {
  install.packages("ggbeeswarm", repos = "https://cloud.r-project.org")
}
library(ggbeeswarm)

# Calculate variance for each term
term_variance <- df_raw %>%
  group_by(term) %>%
  summarise(
    variance = var(probability, na.rm = TRUE),
    sd = sd(probability, na.rm = TRUE),
    mean = mean(probability, na.rm = TRUE),
    median = median(probability, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  ) %>%
  arrange(desc(variance))

# -----------------------------------------------------------------------------
# 01_words_means: Strip plot ordered by mean probability
# -----------------------------------------------------------------------------
df_strip <- df_raw %>%
  left_join(term_variance, by = "term") %>%
  mutate(term_ordered_mean = fct_reorder(term, mean))

strip_summary_mean <- df_strip %>%
  group_by(term_ordered_mean) %>%
  summarise(
    mean_prob = mean(probability, na.rm = TRUE),
    median_prob = median(probability, na.rm = TRUE),
    .groups = "drop"
  )

p_strip_mean <- ggplot(df_strip, aes(x = probability, y = term_ordered_mean)) +
  geom_quasirandom(
    groupOnX = FALSE,
    width = 0.35,
    alpha = 0.15,
    size = 1,
    color = colors_main["primary"]
  ) +
  geom_point(
    data = strip_summary_mean,
    aes(x = median_prob, y = term_ordered_mean),
    shape = 18, size = 3.5, color = colors_main["secondary"]
  ) +
  geom_point(
    data = strip_summary_mean,
    aes(x = mean_prob, y = term_ordered_mean),
    shape = 1, size = 2.5, color = colors_main["secondary"], stroke = 1.2
  ) +
  scale_x_continuous(
    limits = c(0, 100),
    breaks = seq(0, 100, 25),
    expand = c(0.01, 0)
  ) +
  labs(
    title = "Probability phrases ranked by mean",
    subtitle = "Ordered by mean probability (lowest at bottom). Each point is one response.\nHollow circle = mean; diamond = median.",
    x = "Probability (%)",
    y = NULL,
    caption = sprintf("Based on %s survey responses", format(n_distinct(df_raw$response_id), big.mark = ","))
  ) +
  theme_minimal_clean() +
  theme(
    axis.text.y = element_text(size = 10),
    panel.grid.major.x = element_line(color = "#eeeeee", linewidth = 0.3),
    panel.grid.major.y = element_line(color = "#e0e0e0", linewidth = 0.3)
  )

ggsave(
  file.path(output_dir, "01_words_means.png"),
  p_strip_mean,
  width = 10,
  height = 10,
  dpi = 300,
  bg = "white"
)

# -----------------------------------------------------------------------------
# Load yardstick data (shared by yardstick plots below)
# -----------------------------------------------------------------------------
yardstick_dir <- data_dir

yardstick_ipcc <- read_csv(file.path(yardstick_dir, "yardstick_ipcc.csv"), show_col_types = FALSE)
yardstick_us <- read_csv(file.path(yardstick_dir, "yardstick_us_nic.csv"), show_col_types = FALSE)
yardstick_uk <- read_csv(file.path(yardstick_dir, "yardstick_uk.csv"), show_col_types = FALSE)
yardstick_efsa <- read_csv(file.path(yardstick_dir, "yardstick_efsa.csv"), show_col_types = FALSE)
yardstick_nato <- read_csv(file.path(yardstick_dir, "yardstick_nato.csv"), show_col_types = FALSE)

term_mapping <- tribble(
  ~survey_term, ~ipcc_term, ~us_term, ~uk_term, ~efsa_term, ~nato_term,
  "Almost Certain", NA, "Almost certain", "Almost certain", "Almost certain", NA,
  "Highly Likely", "Very likely", "Very likely", "Highly likely", "Very likely", "Highly likely",
  "Very Good Chance", NA, NA, NA, NA, NA,
  "Likely", "Likely", "Likely", "Likely", "Likely", "Likely",
  "Probable", NA, "Likely", "Probable", NA, NA,
  "Better than Even", NA, NA, NA, NA, NA,
  "About Even", NA, "Roughly even chance", NA, NA, "Even chance",
  "Realistic Possibility", NA, NA, "Realistic possibility", NA, NA,
  "Unlikely", "Unlikely", "Unlikely", "Unlikely", "Unlikely", "Unlikely",
  "Improbable", NA, "Unlikely", NA, NA, NA,
  "Chances are Slight", NA, NA, NA, NA, NA,
  "Little Chance", NA, NA, NA, NA, NA,
  "Highly Unlikely", NA, NA, "Highly unlikely", "Very unlikely", "Highly unlikely",
  "Almost No Chance", NA, "Almost no chance", NA, NA, NA,
  "Remote Chance", NA, "Remote chance", "Remote chance", NA, NA,
  "May Happen", NA, NA, NA, NA, NA,
  "Might Happen", NA, NA, NA, NA, NA,
  "Will Happen", NA, NA, NA, NA, NA,
  "Could Happen", NA, NA, NA, NA, NA
)

create_yardstick_ranges <- function(term_mapping, yardstick_data, yardstick_col, source_name) {
  term_mapping %>%
    select(survey_term, yardstick_term = !!sym(yardstick_col)) %>%
    filter(!is.na(yardstick_term)) %>%
    left_join(yardstick_data, by = c("yardstick_term" = "term")) %>%
    mutate(source = source_name) %>%
    select(survey_term, low, high, source)
}

yardstick_ranges <- bind_rows(
  create_yardstick_ranges(term_mapping, yardstick_ipcc, "ipcc_term", "IPCC"),
  create_yardstick_ranges(term_mapping, yardstick_us, "us_term", "US Intelligence"),
  create_yardstick_ranges(term_mapping, yardstick_uk, "uk_term", "UK Intelligence"),
  create_yardstick_ranges(term_mapping, yardstick_efsa, "efsa_term", "European Food Safety Authority"),
  create_yardstick_ranges(term_mapping, yardstick_nato, "nato_term", "NATO")
)

yardstick_colors <- c("IPCC" = "#e0808a", "European Food Safety Authority" = "#6fbf66", "US Intelligence" = "#4db8ad", "UK Intelligence" = "#e5c968", "NATO" = "#a67cc4")

# -----------------------------------------------------------------------------
# 01_words_yardsticks: Strip plot by variance with official scale overlays
# -----------------------------------------------------------------------------
df_strip_var <- df_raw %>%
  left_join(term_variance, by = "term") %>%
  mutate(term_ordered_var = fct_reorder(term, variance, .desc = FALSE))

yardstick_plot <- yardstick_ranges %>%
  inner_join(
    df_strip_var %>% select(term, term_ordered_var) %>% distinct(),
    by = c("survey_term" = "term")
  ) %>%
  mutate(
    source = factor(source, levels = c("IPCC", "European Food Safety Authority", "US Intelligence", "UK Intelligence", "NATO"))
  ) %>%
  group_by(survey_term) %>%
  mutate(n_sources = n()) %>%
  ungroup() %>%
  mutate(
    y_offset = case_when(
      n_sources == 1 ~ 0,
      source == "IPCC" ~ -0.24,
      source == "European Food Safety Authority" ~ -0.12,
      source == "US Intelligence" ~ 0,
      source == "UK Intelligence" ~ 0.12,
      source == "NATO" ~ 0.24
    )
  )

yardstick_plot <- yardstick_plot %>%
  mutate(
    y_center = as.numeric(term_ordered_var) + y_offset,
    y_min = y_center - 0.06,
    y_max = y_center + 0.06
  )

p_strip_yardstick <- ggplot(df_strip_var, aes(x = probability, y = term_ordered_var)) +
  geom_rect(
    data = yardstick_plot,
    aes(
      xmin = low, xmax = high,
      ymin = y_min, ymax = y_max,
      fill = source
    ),
    alpha = 0.7,
    inherit.aes = FALSE
  ) +
  geom_quasirandom(
    groupOnX = FALSE,
    width = 0.35,
    alpha = 0.2,
    size = 1,
    color = colors_main["primary"]
  ) +
  scale_fill_manual(values = yardstick_colors, name = "Official scale") +
  scale_x_continuous(
    limits = c(0, 100),
    breaks = seq(0, 100, 25),
    expand = c(0.01, 0)
  ) +
  labs(
    title = "The most ambiguous phrases",
    subtitle = "Ranked by variance (highest at top). Each point is one response.",
    x = "Probability (%)",
    y = NULL,
    caption = sprintf("Based on %s survey responses.",
                      format(n_distinct(df_raw$response_id), big.mark = ","))
  ) +
  theme_minimal_clean() +
  theme(
    axis.text.y = element_text(size = 10),
    panel.grid.major.x = element_line(color = "#eeeeee", linewidth = 0.3),
    panel.grid.major.y = element_line(color = "#e0e0e0", linewidth = 0.3),
    legend.position = "bottom"
  ) +
  guides(fill = guide_legend(override.aes = list(alpha = 1)))

ggsave(
  file.path(output_dir, "01_words_yardsticks.png"),
  p_strip_yardstick,
  width = 10,
  height = 10,
  dpi = 300,
  bg = "white"
)
