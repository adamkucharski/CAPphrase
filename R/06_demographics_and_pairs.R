# Demographics summary
# Outputs: 06_demographics.png, table_demographics_*.csv

source("00_setup.R")
install_if_missing("patchwork")
library(patchwork)

# Get unique respondents (one row per person)
df_respondents <- df_wide %>%
  select(response_id, age_band, english_background, education_level, country_of_residence)

n_total <- nrow(df_respondents)

# Age band
age_order <- c("Under 18", "18-24", "25-34", "35-44", "45-54", "55-64", "65+")

age_table <- df_respondents %>%
  mutate(
    age_band = ifelse(is.na(age_band) | age_band == "", "Not provided", age_band),
    age_band = factor(age_band, levels = c(age_order, "Not provided"))
  ) %>%
  count(age_band, name = "n") %>%
  mutate(pct = round(100 * n / sum(n), 1)) %>%
  arrange(age_band)

# Education level
education_order <- c(
  "Less than high school",
  "High school",
  "Some college",
  "Bachelor",
  "Postgraduate"
)

education_table <- df_respondents %>%
  mutate(
    education_level = ifelse(is.na(education_level) | education_level == "", "Not provided", education_level),
    education_level = factor(education_level, levels = c(education_order, "Not provided"))
  ) %>%
  count(education_level, name = "n") %>%
  mutate(pct = round(100 * n / sum(n), 1)) %>%
  arrange(education_level)

# English language background
english_table <- df_respondents %>%
  mutate(
    english_background = ifelse(is.na(english_background) | english_background == "", "Not provided", english_background)
  ) %>%
  count(english_background, name = "n") %>%
  mutate(pct = round(100 * n / sum(n), 1)) %>%
  arrange(desc(n))

# Country of residence
country_table <- df_respondents %>%
  mutate(
    country_of_residence = ifelse(is.na(country_of_residence) | country_of_residence == "", "Not provided", country_of_residence)
  ) %>%
  count(country_of_residence, name = "n") %>%
  mutate(pct = round(100 * n / sum(n), 1)) %>%
  arrange(desc(n))

# Save tables to CSV
write_csv(age_table, file.path(output_dir, "table_demographics_age.csv"))
write_csv(education_table, file.path(output_dir, "table_demographics_education.csv"))
write_csv(english_table, file.path(output_dir, "table_demographics_english.csv"))
write_csv(country_table, file.path(output_dir, "table_demographics_country.csv"))

# 4-panel demographic summary figure
age_plot <- age_table %>% filter(!is.na(age_band), age_band != "Not provided") %>%
  mutate(pct = 100 * n / sum(n))
edu_plot <- education_table %>% filter(education_level != "Not provided") %>%
  mutate(pct = 100 * n / sum(n))
eng_plot <- english_table %>%
  filter(english_background != "Not provided") %>%
  mutate(
    pct = 100 * n / sum(n),
    english_background = case_when(
      english_background == "English is my first language" ~ "First\nlanguage",
      english_background == "English is not my first language but I am fluent" ~ "Not first,\nfluent",
      english_background == "English is not my first language and I am not fluent" ~ "Not first,\nnot fluent",
      TRUE ~ english_background
    )
  )
country_plot <- country_table %>%
  filter(country_of_residence != "Not provided") %>%
  slice_head(n = 10) %>%
  mutate(pct = 100 * n / sum(n))

p_age <- ggplot(age_plot, aes(x = age_band, y = pct)) +
  geom_col(fill = "#0072B2", alpha = 0.7) +
  geom_text(aes(label = sprintf("%.0f%%\n(n=%s)", pct, format(n, big.mark = ","))),
            vjust = -0.15, size = 2.8, color = "#333333", lineheight = 0.9) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(title = "Age", x = NULL, y = "Percentage") +
  theme_minimal_clean()

p_edu <- ggplot(edu_plot, aes(
  x = factor(str_wrap(education_level, 12),
             levels = str_wrap(education_order, 12)),
  y = pct)) +
  geom_col(fill = "#0072B2", alpha = 0.7) +
  geom_text(aes(label = sprintf("%.0f%%\n(n=%s)", pct, format(n, big.mark = ","))),
            vjust = -0.15, size = 2.8, color = "#333333", lineheight = 0.9) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(title = "Education", x = NULL, y = "Percentage") +
  theme_minimal_clean()

p_eng <- ggplot(eng_plot, aes(
  x = factor(english_background,
             levels = c("First\nlanguage", "Not first,\nfluent", "Not first,\nnot fluent")),
  y = pct)) +
  geom_col(fill = "#0072B2", alpha = 0.7) +
  geom_text(aes(label = sprintf("%.0f%%\n(n=%s)", pct, format(n, big.mark = ","))),
            vjust = -0.15, size = 2.8, color = "#333333", lineheight = 0.9) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(title = "English background", x = NULL, y = "Percentage") +
  theme_minimal_clean()

p_country <- ggplot(country_plot, aes(
  x = factor(country_of_residence, levels = rev(country_of_residence)),
  y = pct)) +
  geom_col(fill = "#0072B2", alpha = 0.7) +
  geom_text(aes(label = sprintf("%.0f%% (n=%s)", pct, format(n, big.mark = ","))),
            hjust = -0.08, size = 2.8, color = "#333333") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(title = "Country (top 10)", x = NULL, y = "Percentage") +
  coord_flip(clip = "off") +
  theme_minimal_clean()

p_demographics <- (p_age | p_edu) / (p_eng | p_country) +
  plot_annotation(
    title = "Respondent demographics",
    subtitle = sprintf("N = %s respondents (excluding 'not provided')", format(n_total, big.mark = ",")),
    theme = theme(
      plot.title = element_text(face = "bold", size = 14, family = "Arial"),
      plot.subtitle = element_text(size = 11, color = "#666666", family = "Arial")
    )
  )

ggsave(
  file.path(output_dir, "06_demographics.png"),
  p_demographics,
  width = 11, height = 9, dpi = 300, bg = "white"
)
