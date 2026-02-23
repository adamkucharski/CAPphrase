# Reusable plot styling for R projects
# Source this file to get consistent fonts, theme, and colors

# Required packages for plotting
plot_packages <- c("ggplot2", "showtext", "scales")

for (pkg in plot_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
  library(pkg, character.only = TRUE)
}

# -----------------------------------------------------------------------------
# Font setup
# -----------------------------------------------------------------------------
font_add("Arial", "/Library/Fonts/Arial.ttf")
showtext_auto()
showtext_opts(dpi = 300)  # Match ggsave dpi to prevent sizing issues

# -----------------------------------------------------------------------------
# Custom theme
# -----------------------------------------------------------------------------
theme_minimal_clean <- function(base_size = 12) {
  theme_minimal(base_size = base_size, base_family = "Arial") +
    theme(
      # Faint horizontal gridlines at y-axis ticks; no vertical or minor gridlines
      panel.grid.major.y = element_line(color = "#e8e8e8", linewidth = 0.3),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      # Clean axis lines
      axis.line = element_line(color = "#333333", linewidth = 0.3),
      axis.ticks = element_line(color = "#333333", linewidth = 0.3),
      # Text styling
      axis.text = element_text(color = "#333333"),
      axis.title = element_text(color = "#333333", face = "plain"),
      plot.title = element_text(color = "#333333", face = "bold", hjust = 0),
      plot.subtitle = element_text(color = "#666666", hjust = 0),
      plot.caption = element_text(color = "#999999", hjust = 1),
      # Clean background
      panel.background = element_rect(fill = "white", color = NA),
      plot.background = element_rect(fill = "white", color = NA),
      # Legend styling
      legend.background = element_rect(fill = "white", color = NA),
      legend.key = element_rect(fill = "white", color = NA),
      legend.text = element_text(color = "#333333"),
      legend.title = element_text(color = "#333333"),
      # No axis text rotation
      axis.text.x = element_text(angle = 0, hjust = 0.5, vjust = 1),
      # Margins
      plot.margin = margin(15, 15, 15, 15)
    )
}

# Set as default theme
theme_set(theme_minimal_clean())

# -----------------------------------------------------------------------------
# Scale defaults - axes cross at min values, no gap
# -----------------------------------------------------------------------------
scale_y_continuous <- function(..., limits = c(0, NA), expand = expansion(mult = c(0, 0.05))) {
  ggplot2::scale_y_continuous(..., limits = limits, expand = expand)
}

scale_x_continuous <- function(..., expand = expansion(mult = c(0, 0.05))) {
  ggplot2::scale_x_continuous(..., expand = expand)
}

# -----------------------------------------------------------------------------
# Color palette
# -----------------------------------------------------------------------------
colors_main <- c(
  primary = "#1e3a5f",
  secondary = "#e63946",
  tertiary = "#457b9d",
  light = "#a8dadc",
  dark = "#333333"
)

# -----------------------------------------------------------------------------
# Credit annotation - adds faint credit to bottom right of saved plots
# -----------------------------------------------------------------------------
add_credit <- function(p, label = "github.com/adamkucharski") {
  p + labs(tag = label) +
    theme(
      plot.tag = element_text(size = 8, color = "#999999", family = "Arial",
                              hjust = 1),
      plot.tag.position = "topright"
    )
}

# Override ggsave to automatically add credit
ggsave <- function(filename, plot = ggplot2::last_plot(), ...) {
  ggplot2::ggsave(filename, plot = add_credit(plot), ...)
}
