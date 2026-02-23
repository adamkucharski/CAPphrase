# Run all analysis scripts
# Execute from the R/ directory: Rscript run_all.R

source("00_setup.R")
source("01_probability_words.R")
source("02_inconsistent_pairs.R")
source("02c_pairwise_disagreement.R")
source("03_position_effect.R")
source("06_demographics_and_pairs.R")
source("07_individual_patterns.R")
source("08b_demographic_effects_position.R")
