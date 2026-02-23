# Individual Response Patterns - Rounding preferences
# Output: 07_rounding.png

source("00_setup.R")
install_if_missing("patchwork")
library(patchwork)

# Define what counts as a "round" number
df_rounding <- df_raw %>%
  mutate(
    is_multiple_10 = (probability %% 10 == 0),
    is_multiple_5 = (probability %% 5 == 0),
    last_digit = probability %% 10
  )

# Calculate rounding tendency per respondent
respondent_rounding <- df_rounding %>%
  group_by(response_id) %>%
  summarise(
    n_responses = n(),
    prop_multiple_10 = mean(is_multiple_10, na.rm = TRUE) * 100,
    prop_multiple_5 = mean(is_multiple_5, na.rm = TRUE) * 100,
    .groups = "drop"
  ) %>%
  filter(n_responses >= 5)

# Distribution of rounding tendency (multiples of 5)
p_rounding_dist <- ggplot(respondent_rounding, aes(x = prop_multiple_5)) +
  geom_histogram(
    breaks = seq(0, 100, by = 5),
    fill = colors_main["primary"],
    color = "white",
    alpha = 0.8
  ) +
  scale_x_continuous(limits = c(0, 100), breaks = seq(0, 100, 10), expand = c(0, 0)) +
  labs(
    title = "Rounding preference varies across respondents",
    subtitle = "Distribution of % responses that are multiples of 5",
    x = "% of responses that are multiples of 5",
    y = "Number of respondents"
  ) +
  theme_minimal_clean()

# Last digit frequency (shows digit preference)
digit_freq <- df_rounding %>%
  count(last_digit) %>%
  mutate(
    proportion = n / sum(n) * 100,
    expected = 10,
    is_round = last_digit %in% c(0, 5)
  )

p_digit_freq <- ggplot(digit_freq, aes(x = factor(last_digit), y = proportion, fill = is_round)) +
  geom_col(alpha = 0.8, width = 0.7) +
  geom_hline(yintercept = 10, linetype = "dashed", color = "#666666", linewidth = 0.5) +
  scale_fill_manual(
    values = c("FALSE" = "#cccccc", "TRUE" = colors_main["primary"]),
    guide = "none"
  ) +
  scale_y_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.1))) +
  labs(
    title = "Strong preference for round numbers",
    subtitle = "Frequency of last digit in probability responses",
    x = "Last digit",
    y = "% of all responses",
    caption = "Dashed line shows expected 10% if uniform"
  ) +
  theme_minimal_clean()

p_rounding_combined <- p_digit_freq + p_rounding_dist +
  plot_annotation(
    caption = sprintf("Based on %s respondents ", format(nrow(respondent_rounding), big.mark = ",")),
    theme = theme(
      plot.caption = element_text(size = 9, color = "#999999", family = "Arial", hjust = 1)
    )
  )

ggsave(
  file.path(output_dir, "07_rounding.png"),
  p_rounding_combined,
  width = 14,
  height = 6,
  dpi = 300,
  bg = "white"
)
