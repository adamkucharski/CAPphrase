# 02c: Repeated pair internal disagreement
# Each respondent sees pair 1 again as pair 10 (terms swapped).
# This plot shows disagreement rate per unique repeated pair.

# Load setup
source("00_setup.R")

# ── Extract pair 1 and pair 10 per respondent ────────────────────────────────
pair1 <- df_pairwise %>%
  filter(pair_id == 1) %>%
  select(response_id, term1, term2, selected)

pair10 <- df_pairwise %>%
  filter(pair_id == 10) %>%
  select(response_id, selected_repeat = selected)

df_repeat <- pair1 %>%
  inner_join(pair10, by = "response_id") %>%
  mutate(consistent = (selected == selected_repeat))

# ── Consistency rate per unique pair ─────────────────────────────────────────
# Standardise pair label alphabetically, keeping both terms as columns
df_repeat <- df_repeat %>%
  mutate(
    term_a = pmin(term1, term2),
    term_b = pmax(term1, term2),
    pair_label = paste(term_a, "vs", term_b)
  )

pair_consistency <- df_repeat %>%
  group_by(pair_label, term_a, term_b) %>%
  summarise(
    n = n(),
    pct_consistent = mean(consistent, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(pct_inconsistent = 1 - pct_consistent) %>%
  arrange(pct_consistent)

overall_consistency <- mean(df_repeat$consistent, na.rm = TRUE)

# ── Plot ─────────────────────────────────────────────────────────────────────
# Order terms by mean probability (same as other heatmaps)
term_means <- df_raw %>%
  group_by(term) %>%
  summarise(mean_prob = mean(probability, na.rm = TRUE), .groups = "drop") %>%
  arrange(mean_prob)

term_order <- term_means %>%
  filter(term %in% valid_terms) %>%
  pull(term)

terms_without_slider <- setdiff(valid_terms, term_order)
term_order <- c(term_order, sort(terms_without_slider))

# Expand to both directions for the full grid
df_cons_long <- bind_rows(
  pair_consistency %>% transmute(term_row = term_a, term_col = term_b, pct_inconsistent, n),
  pair_consistency %>% transmute(term_row = term_b, term_col = term_a, pct_inconsistent, n)
)

complete_grid <- expand.grid(
  term_row = term_order,
  term_col = term_order,
  stringsAsFactors = FALSE
) %>%
  filter(term_row != term_col) %>%
  as_tibble()

df_cons_plot <- complete_grid %>%
  left_join(df_cons_long, by = c("term_row", "term_col")) %>%
  filter(match(term_col, term_order) > match(term_row, term_order)) %>%
  mutate(
    label = ifelse(is.na(pct_inconsistent), "", sprintf("%.0f%%", pct_inconsistent * 100)),
    term_row = factor(term_row, levels = term_order),
    term_col = factor(term_col, levels = rev(term_order))
  )

p_repeat <- ggplot(df_cons_plot, aes(x = term_row, y = term_col, fill = pct_inconsistent)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(
    aes(label = label),
    size = 2.5,
    color = ifelse(is.na(df_cons_plot$pct_inconsistent), "grey50",
                   ifelse(df_cons_plot$pct_inconsistent > 0.3, "white", "black"))
  ) +
  scale_fill_gradient(
    low = "#f7f7f7",
    high = "#b2182b",
    limits = c(0, NA),
    na.value = "#e0e0e0",
    name = "Disagreement",
    labels = percent_format()
  ) +
  labs(
    title = "Internal disagreement on repeated pair",
    subtitle = "% of respondents who gave a different answer to pair 1 and its repeat (pair 10)",
    x = NULL,
    y = NULL,
    caption = "Terms ordered by mean probability estimate (low to high). Grey cells = no data."
  ) +
  theme_minimal_clean() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1, size = 9),
    axis.text.y = element_text(size = 9),
    legend.position = "right",
    panel.border = element_rect(color = "#cccccc", fill = NA, linewidth = 0.5),
    panel.grid = element_blank()
  ) +
  coord_fixed()

ggsave(
  file.path(output_dir, "02c_repeated_pair_consistency.png"),
  p_repeat,
  width = 11,
  height = 9.5,
  dpi = 300,
  bg = "white"
)

# ── Summary ───────────────────────────────────────────────────────────────────
cat(sprintf("\nOverall repeated-pair disagreement: %.1f%% of %d respondents\n",
            (1 - overall_consistency) * 100, nrow(df_repeat)))
cat("\nDisagreement by pair (highest first):\n")
pair_consistency %>%
  arrange(desc(pct_inconsistent)) %>%
  mutate(pct = sprintf("%.0f%% (%d respondents)", pct_inconsistent * 100, n)) %>%
  select(pair_label, pct) %>%
  print(n = Inf)

cat("\nPlot saved to output/02c_repeated_pair_consistency.png\n")
