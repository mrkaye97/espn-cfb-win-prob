money_line_to_odds <- function(line) {
  ifelse(
    line < 0,
    abs(line) / (100 + abs(line)),
    100 / (100 + line)
  )
}

brier_score <- function(truth, estimate) {
  mean((truth - estimate)^2)
}

brier_skill_score <- function(truth, estimate, ref) {
  ref_bs <- brier_score(truth, ref)
  estimate_bs <- brier_score(truth, estimate)

  1 - (estimate_bs / ref_bs)
}
