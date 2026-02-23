# 08b: Demographic regression model with position effect
# Output: 08_demographic_effects_position.png

source("00_setup.R")

install_if_missing("glmmTMB")
library(glmmTMB)

# Prepare modelling data
age_levels <- c("Under 18", "18-24", "25-34", "35-44", "45-54", "55-64")
education_levels <- c("Less than high school", "High school", "Some college",
                      "Bachelor", "Postgraduate")
english_levels <- c(
  "English is my first language",
  "English is not my first language but I am fluent",
  "English is not my first language and I am not fluent"
)

df_model <- df_raw %>%
  filter(
    age_band %in% age_levels,
    education_level %in% education_levels,
    english_background %in% english_levels,
    !is.na(country_of_residence) & country_of_residence != "",
    !is.na(order)
  ) %>%
  mutate(
    country_group = case_when(
      country_of_residence == "United Kingdom" ~ "UK",
      country_of_residence == "United States" ~ "US",
      TRUE ~ "Other"
    ),
    position_group = case_when(
      order <= 3  ~ "1-3",
      order <= 6  ~ "4-6",
      order <= 9  ~ "7-9",
      order <= 12 ~ "10-12",
      order <= 15 ~ "13-15",
      order <= 19 ~ "16-19"
    ),
    position_group = factor(position_group,
                            levels = c("1-3", "4-6", "7-9", "10-12", "13-15", "16-19")),
    age_band = relevel(factor(age_band, levels = age_levels), ref = "35-44"),
    education_level = relevel(factor(education_level, levels = education_levels),
                              ref = "Postgraduate"),
    english_background = factor(english_background, levels = english_levels),
    country_group = factor(country_group, levels = c("UK", "US", "Other")),
    prob_01 = pmin(pmax(probability / 100, 0.001), 0.999)
  )

model <- glmmTMB(
  prob_01 ~ age_band + education_level + english_background + country_group +
    position_group + term + (1 | response_id),
  family = beta_family(link = "logit"),
  data = df_model
)

# Extract fixed effects and compute fold differences
cc <- summary(model)$coefficients$cond
intercept <- cc["(Intercept)", "Estimate"]
cc <- cc[rownames(cc) != "(Intercept)", , drop = FALSE]
cc <- cc[!str_starts(rownames(cc), "term"), , drop = FALSE]

pred_ref <- plogis(intercept)

effect_df <- tibble(
  coef_name = rownames(cc),
  estimate = cc[, "Estimate"],
  se = cc[, "Std. Error"],
  p_value = cc[, "Pr(>|z|)"],
  fold = plogis(intercept + estimate) / pred_ref,
  fold_lower = plogis(intercept + estimate - 1.96 * se) / pred_ref,
  fold_upper = plogis(intercept + estimate + 1.96 * se) / pred_ref
) %>%
  mutate(
    demographic = case_when(
      str_starts(coef_name, "age_band") ~ "Age",
      str_starts(coef_name, "education_level") ~ "Education",
      str_starts(coef_name, "english_background") ~ "English",
      str_starts(coef_name, "country_group") ~ "Country",
      str_starts(coef_name, "position_group") ~ "Position"
    ),
    level = str_remove(coef_name,
                       "^(age_band|education_level|english_background|country_group|position_group)"),
    level = case_when(
      level == "English is not my first language but I am fluent" ~
        "Not first, fluent",
      level == "English is not my first language and I am not fluent" ~
        "Not first, not fluent",
      TRUE ~ level
    ),
    significant = p_value < 0.05,
    demographic = factor(demographic,
                         levels = c("Age", "Education", "English", "Country", "Position"))
  )

# Add sample sizes per group
n_respondents <- n_distinct(df_model$response_id)
n_by_group <- list(
  age = df_model %>% distinct(response_id, age_band) %>% count(age_band),
  edu = df_model %>% distinct(response_id, education_level) %>% count(education_level),
  eng = df_model %>% distinct(response_id, english_background) %>% count(english_background),
  cty = df_model %>% distinct(response_id, country_group) %>% count(country_group),
  pos = df_model %>% count(position_group)
)

effect_df <- effect_df %>%
  mutate(
    orig_level = case_when(
      level == "Not first, fluent" ~
        "English is not my first language but I am fluent",
      level == "Not first, not fluent" ~
        "English is not my first language and I am not fluent",
      TRUE ~ as.character(level)
    ),
    n_group = case_when(
      demographic == "Age" ~
        n_by_group$age$n[match(orig_level, n_by_group$age$age_band)],
      demographic == "Education" ~
        n_by_group$edu$n[match(orig_level, n_by_group$edu$education_level)],
      demographic == "English" ~
        n_by_group$eng$n[match(orig_level, n_by_group$eng$english_background)],
      demographic == "Country" ~
        n_by_group$cty$n[match(orig_level, n_by_group$cty$country_group)],
      demographic == "Position" ~
        as.integer(n_by_group$pos$n[match(orig_level, n_by_group$pos$position_group)])
    )
  )

# Add reference category rows
ref_n <- c(
  n_by_group$age$n[n_by_group$age$age_band == "35-44"],
  n_by_group$edu$n[n_by_group$edu$education_level == "Postgraduate"],
  n_by_group$eng$n[n_by_group$eng$english_background == "English is my first language"],
  n_by_group$cty$n[n_by_group$cty$country_group == "UK"],
  as.integer(n_by_group$pos$n[n_by_group$pos$position_group == "1-3"])
)

ref_rows <- tibble(
  coef_name = NA_character_,
  estimate = 0, se = 0, p_value = NA_real_,
  fold = 1, fold_lower = 1, fold_upper = 1,
  demographic = factor(c("Age", "Education", "English", "Country", "Position"),
                       levels = c("Age", "Education", "English", "Country", "Position")),
  level = c("35-44 (ref)", "Postgraduate (ref)",
            "First language (ref)", "UK (ref)", "1-3 (ref)"),
  significant = NA,
  orig_level = NA_character_,
  n_group = ref_n
)

all_levels <- rev(c(
  "__hdr_Age",
  "Under 18", "18-24", "25-34", "35-44 (ref)", "45-54", "55-64",
  "__hdr_Education",
  "Less than high school", "High school", "Some college", "Bachelor",
  "Postgraduate (ref)",
  "__hdr_English",
  "Not first, not fluent", "Not first, fluent", "First language (ref)",
  "__hdr_Country",
  "Other", "US", "UK (ref)",
  "__hdr_Position",
  "1-3 (ref)", "4-6", "7-9", "10-12", "13-15", "16-19"
))

hdr_rows <- tibble(
  coef_name = NA_character_,
  estimate = 0, se = 0, p_value = NA_real_,
  fold = NA_real_, fold_lower = NA_real_, fold_upper = NA_real_,
  demographic = factor(c("Age", "Education", "English", "Country", "Position"),
                       levels = c("Age", "Education", "English", "Country", "Position")),
  level = c("__hdr_Age", "__hdr_Education", "__hdr_English", "__hdr_Country", "__hdr_Position"),
  significant = NA,
  orig_level = NA_character_,
  n_group = NA_integer_,
  is_header = TRUE
)

effect_df <- bind_rows(effect_df, ref_rows) %>%
  mutate(is_ref = is.na(significant), is_header = FALSE) %>%
  bind_rows(hdr_rows) %>%
  mutate(
    level = factor(level, levels = all_levels),
    is_header = ifelse(is.na(is_header), FALSE, is_header)
  )

# Forest plot
non_hdr <- !effect_df$is_header & !effect_df$is_ref
fold_max <- max(c(effect_df$fold_upper[non_hdr],
                  1 / effect_df$fold_lower[non_hdr])) ^ 1.6

df_points <- effect_df %>% filter(!is_header)

df_points <- df_points %>%
  mutate(
    label = ifelse(is_ref,
                   sprintf("ref (n=%d)", n_group),
                   sprintf("%.2f (n=%d)", fold, n_group)),
    label_x = ifelse(is_ref, 1, fold_upper),
    label_color = ifelse(is_ref, "#999999", "#666666"),
    xmin_plot = ifelse(is_ref, 1, fold_lower),
    xmax_plot = ifelse(is_ref, 1, fold_upper),
    evidence = ifelse(is_ref, NA_real_, pmin(-log10(p_value), 4)),
    point_shape = ifelse(is_ref, 18L, 16L),
    point_size = ifelse(is_ref, 0.8, 0.6),
    line_width = ifelse(is_ref, 0, 0.6)
  )

hdr_labels <- c("__hdr_Age" = "Age", "__hdr_Education" = "Education",
                "__hdr_English" = "English", "__hdr_Country" = "Country",
                "__hdr_Position" = "Position in list")

hdr_y_pos <- match(names(hdr_labels), all_levels)

p_forest <- ggplot(df_points, aes(x = fold, y = level)) +
  annotate("text", x = 1 / fold_max, y = hdr_y_pos - 0.4,
           label = hdr_labels, fontface = "bold", hjust = 0, vjust = 0.5,
           size = 3.5, color = "#333333") +
  geom_vline(xintercept = 1, linetype = "dashed", color = "#cccccc") +
  geom_pointrange(
    aes(xmin = xmin_plot, xmax = xmax_plot, color = evidence),
    shape = df_points$point_shape,
    size = df_points$point_size,
    linewidth = df_points$line_width
  ) +
  geom_text(
    aes(label = label, x = label_x),
    hjust = -0.08, size = 2.8,
    color = df_points$label_color
  ) +
  geom_text(
    aes(label = as.character(level), x = 1 / fold_max),
    hjust = 0, size = 2.8, color = "#333333"
  ) +
  scale_color_gradient(
    low = "#cccccc", high = "#0072B2",
    na.value = "#555555",
    name = "p-value",
    breaks = -log10(c(0.1, 0.01, 0.001, 1e-4)),
    labels = c("0.1", "0.01", "0.001", "\u22640.0001"),
    limits = c(0, 4)
  ) +
  scale_x_log10(
    limits = c(1 / fold_max, fold_max),
    breaks = c(0.9, 0.95, 1, 1.05, 1.1, 1.15),
    expand = expansion(mult = c(0.02, 0.25)),
    labels = function(x) paste0(x, "x")
  ) +
  scale_y_discrete(drop = FALSE) +
  labs(
    title = "Demographic and position effects on probability estimates",
    subtitle = "Fold difference from beta regression with fixed effects for phrase and position, random intercepts for respondent",
    x = "Fold difference from reference group",
    y = NULL,
    caption = paste0(
      format(n_respondents, big.mark = ","),
      " respondents with complete demographics (",
      format(nrow(df_model), big.mark = ","), " observations).\n",
      "Reference categories: Age 35\u201344, Postgraduate, English first language, UK, position 1\u20133.\n",
      ">1x = higher probability estimates than reference; <1x = lower. Error bars show 95% CI."
    )
  ) +
  theme_minimal_clean() +
  theme(
    panel.grid.major.x = element_line(color = "#e8e8e8", linewidth = 0.3),
    panel.grid.major.y = element_blank(),
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y = element_blank(),
    legend.position = c(0.95, 0.95),
    legend.justification = c(1, 1),
    legend.background = element_rect(fill = alpha("white", 0.8), color = NA),
    legend.key.height = unit(1.2, "cm"),
    legend.key.width = unit(0.4, "cm"),
    legend.title = element_text(size = 9),
    legend.text = element_text(size = 7),
    plot.caption = element_text(hjust = 0, color = "#666666", size = rel(0.8),
                               lineheight = 1.3),
    plot.margin = margin(15, 15, 20, 15)
  )

ggsave(
  file.path(output_dir, "08_demographic_effects_position.png"),
  p_forest,
  width = 10, height = 10, dpi = 300, bg = "white"
)
