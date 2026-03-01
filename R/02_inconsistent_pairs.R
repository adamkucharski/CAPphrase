# Least Consistent Pairs - Heatmap grid
# Shows proportion of times term A was judged higher than term B

# Load setup
source("00_setup.R")

# Calculate proportion by pooling both presentation orders per unordered pair
# This ensures mirror values across the diagonal sum to 1
df_pairs_pooled <- df_pairwise %>%
  mutate(
    # Standardize each pair so term_a < term_b alphabetically
    term_a = pmin(term1, term2),
    term_b = pmax(term1, term2),
    # Did the respondent choose term_a (the alphabetically first term)?
    a_chosen = (selected == term_a)
  ) %>%
  group_by(term_a, term_b) %>%
  summarise(
    n_comparisons = n(),
    prop_a_higher = mean(a_chosen, na.rm = TRUE),
    .groups = "drop"
  )

# Expand back to both directions for the grid
df_pairs_long <- bind_rows(
  df_pairs_pooled %>%
    transmute(term_row = term_a, term_col = term_b,
              n_comparisons, prop_row_higher = prop_a_higher),
  df_pairs_pooled %>%
    transmute(term_row = term_b, term_col = term_a,
              n_comparisons, prop_row_higher = 1 - prop_a_higher)
)

# Calculate inconsistency score for each pair
# Most inconsistent pairs are closest to 0.5 (50-50 split)
df_pairs_long <- df_pairs_long %>%
  mutate(
    inconsistency = abs(prop_row_higher - 0.5),
    label = sprintf("%.0f%%", prop_row_higher * 100)
  )

# Order terms by mean probability (from Part 2 data)
term_means <- df_raw %>%
  group_by(term) %>%
  summarise(mean_prob = mean(probability, na.rm = TRUE), .groups = "drop") %>%
  arrange(mean_prob)

# Use all valid terms to create a complete grid
term_order <- term_means %>%
  filter(term %in% valid_terms) %>%
  pull(term)

# Add any valid terms not in slider data (shouldn't happen but just in case)
terms_without_slider <- setdiff(valid_terms, term_order)
term_order <- c(term_order, sort(terms_without_slider))

# Create complete grid of all term pairs
complete_grid <- expand.grid(
  term_row = term_order,
  term_col = term_order,
  stringsAsFactors = FALSE
) %>%
  filter(term_row != term_col) %>%
  as_tibble()

# Join with actual data, filling in NA for missing pairs
df_pairs_plot <- complete_grid %>%
  left_join(df_pairs_long, by = c("term_row", "term_col")) %>%
  mutate(
    label = ifelse(is.na(prop_row_higher), "", sprintf("%.0f%%", prop_row_higher * 100)),
    # Inconsistency: 0.5 at 50-50, 0 at 0% or 100%
    fill_inconsistency = 0.5 - abs(prop_row_higher - 0.5),
    term_row = factor(term_row, levels = term_order),
    term_col = factor(term_col, levels = rev(term_order))
  )

# Create heatmap - color by inconsistency (deviation from 0% or 100%)
p_pairs <- ggplot(df_pairs_plot, aes(x = term_row, y = term_col, fill = fill_inconsistency)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(
    aes(label = label),
    size = 2.5,
    color = ifelse(is.na(df_pairs_plot$fill_inconsistency), "grey50",
                   ifelse(df_pairs_plot$fill_inconsistency > 0.2, "white", "black"))
  ) +
  scale_fill_gradient(
    low = "#f4f4f4",
    high = "#e63946",
    limits = c(0, 0.5),
    na.value = "#e0e0e0",
    name = "",
    labels = percent_format()  # Scale to show as deviation from 50%
  ) +
  labs(
    title = "Pairwise comparison results",
    subtitle = "Percentage of respondents who judged the column phrase as higher probability than the row phrase",
    x = NULL,
    y = NULL,
    caption = "Terms ordered by mean probability estimate (low to high). Red = closer to 50-50 (most inconsistent)."
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

# Save plot
ggsave(
  file.path(output_dir, "02_inconsistent_pairs.png"),
  p_pairs,
  width = 11,
  height = 9.5,
  dpi = 300,
  bg = "white"
)

# Find most inconsistent pairs (closest to 50-50)
most_inconsistent <- df_pairs_long %>%
  filter(!is.na(prop_row_higher)) %>%
  filter(prop_row_higher >= 0.5) %>%  # Only take one direction
  arrange(inconsistency) %>%
  head(15) %>%
  mutate(
    pair = paste(term_row, "vs", term_col),
    split = sprintf("%.0f%% - %.0f%%", prop_row_higher * 100, (1 - prop_row_higher) * 100)
  )

cat("\nMost inconsistent pairs (closest to 50-50):\n")
cat("============================================\n")
most_inconsistent %>%
  select(pair, split) %>%
  print(n = Inf)

cat("\nPlot saved to output/02_inconsistent_pairs.png\n")

# -----------------------------------------------------------------------------
# Plot 02b: Inconsistency between Part 1 (pairwise) and Part 2 (slider) rankings
# For each pair: % who ranked them one way in pairwise but the other way in absolute
# -----------------------------------------------------------------------------

# Get absolute estimates for each respondent
part2_estimates <- df_wide %>%
  select(response_id, all_of(intersect(valid_terms, names(df_wide)))) %>%
  pivot_longer(
    cols = -response_id,
    names_to = "term",
    values_to = "probability"
  ) %>%
  filter(!is.na(probability))

# Join pairwise data with absolute estimates for both terms
# For each pairwise comparison, check if absolute estimates agree
inconsistency_by_respondent <- df_pairwise %>%
  # Get absolute estimate for term1
  left_join(part2_estimates, by = c("response_id", "term1" = "term")) %>%
  rename(prob1 = probability) %>%
  # Get absolute estimate for term2
  left_join(part2_estimates, by = c("response_id", "term2" = "term")) %>%
  rename(prob2 = probability) %>%
  # Only keep rows where we have both estimates
  filter(!is.na(prob1) & !is.na(prob2)) %>%
  mutate(
    # In pairwise, which term did they say was higher?
    pairwise_winner = selected,
    # In absolute, which term did they give higher probability?
    absolute_winner = ifelse(prob1 > prob2, term1,
                             ifelse(prob2 > prob1, term2, NA_character_)),
    # Are they inconsistent? (ranked differently in the two methods)
    is_inconsistent = !is.na(absolute_winner) & (pairwise_winner != absolute_winner)
  )

# Aggregate by term pair (standardize order alphabetically for symmetric matrix)
inconsistency_by_pair <- inconsistency_by_respondent %>%
  mutate(
    term_row = pmin(term1, term2),
    term_col = pmax(term1, term2)
  ) %>%
  group_by(term_row, term_col) %>%
  summarise(
    n_comparisons = n(),
    n_inconsistent = sum(is_inconsistent, na.rm = TRUE),
    prop_inconsistent = mean(is_inconsistent, na.rm = TRUE),
    .groups = "drop"
  )

# Create complete grid for plotting
complete_grid <- expand.grid(
  term_row = term_order,
  term_col = term_order,
  stringsAsFactors = FALSE
) %>%
  filter(term_row != term_col) %>%
  mutate(
    # Standardize order
    t1 = pmin(term_row, term_col),
    t2 = pmax(term_row, term_col)
  ) %>%
  as_tibble()

# Join with inconsistency data; keep only below-diagonal (lower triangle)
# x = term_row (col), y = term_col (row). Below diagonal = row index > col index.
df_inconsistency_plot <- complete_grid %>%
  left_join(inconsistency_by_pair, by = c("t1" = "term_row", "t2" = "term_col")) %>%
  filter(match(term_col, term_order) > match(term_row, term_order)) %>%
  mutate(
    label = ifelse(is.na(prop_inconsistent), "", sprintf("%.0f%%", prop_inconsistent * 100)),
    term_row = factor(term_row, levels = term_order),
    term_col = factor(term_col, levels = rev(term_order))
  )

# Create heatmap
p_inconsistency <- ggplot(df_inconsistency_plot, aes(x = term_row, y = term_col, fill = prop_inconsistent)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(
    aes(label = label),
    size = 2.5,
    color = ifelse(is.na(df_inconsistency_plot$prop_inconsistent), "grey50",
                   ifelse(df_inconsistency_plot$prop_inconsistent > 0.3, "white", "black"))
  ) +
  scale_fill_gradient(
    low = "#f7f7f7",
    high = "#b2182b",
    limits = c(0, NA),
    na.value = "#e0e0e0",
    name = "Inconsistency",
    labels = percent_format()
  ) +
  labs(
    title = "Comparative vs absolute judgment inconsistency",
    subtitle = "% who ranked the pair one way in pairwise comparison but the other way in absolute estimates",
    x = NULL,
    y = NULL,
    caption = "Red = higher inconsistency. Terms ordered by mean probability (low to high)."
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

# Save plot
ggsave(
  file.path(output_dir, "02b_part1_vs_part2_inconsistency.png"),
  p_inconsistency,
  width = 11,
  height = 9.5,
  dpi = 300,
  bg = "white"
)

# Print most inconsistent pairs
cat("\nMost inconsistent pairs (different ranking in pairwise vs absolute):\n")
cat("====================================================================\n")
inconsistency_by_pair %>%
  arrange(desc(prop_inconsistent)) %>%
  head(15) %>%
  mutate(
    pair = paste(term_row, "vs", term_col),
    inconsistent = sprintf("%.0f%%", prop_inconsistent * 100),
    n = n_comparisons
  ) %>%
  select(pair, inconsistent, n) %>%
  print(n = Inf)

cat("\nPlot saved to output/02b_part1_vs_part2_inconsistency.png\n")
