# Position Effect Analysis
# Output: 03_position_effect.png

source("00_setup.R")

# Calculate mean probability by position for each term
term_means <- df_raw %>%
  group_by(term) %>%
  summarise(term_mean = mean(probability, na.rm = TRUE), .groups = "drop")

# Join and calculate deviation from term mean
df_position <- df_raw %>%
  left_join(term_means, by = "term") %>%
  mutate(deviation = probability - term_mean)

# Calculate position effects
position_effect <- df_position %>%
  group_by(order) %>%
  summarise(
    mean_deviation = mean(deviation, na.rm = TRUE),
    se = sd(deviation, na.rm = TRUE) / sqrt(n()),
    mean_prob = mean(probability, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  )

p_position <- ggplot(position_effect, aes(x = order, y = mean_deviation)) +
  geom_hline(yintercept = 0, color = "#999999", linetype = "dashed") +
  geom_linerange(
    aes(ymin = mean_deviation - 1.96 * se, ymax = mean_deviation + 1.96 * se),
    color = colors_main["tertiary"],
    linewidth = 1.5
  ) +
  geom_line(color = colors_main["primary"], linewidth = 1) +
  geom_point(color = colors_main["primary"], size = 2.5) +
  scale_x_continuous(breaks = seq(1, max(position_effect$order), 2)) +
  ggplot2::scale_y_continuous(
    labels = function(x) sprintf("%+.1f%%", x),
    limits = c(NA, NA)
  ) +
  labs(
    title = "Position effect on probability estimates",
    subtitle = "Mean deviation from each phrase's average score, by position in the list",
    x = "Position in slider list",
    y = "Mean deviation from phrase average",
    caption = "Error bars show 95% confidence interval"
  ) +
  theme_minimal_clean()

ggsave(
  file.path(output_dir, "03_position_effect.png"),
  p_position,
  width = 10,
  height = 6,
  dpi = 300,
  bg = "white"
)
