library(tidyverse)
library(readxl)
library(tidycensus)
library(gt)
library(ggtext)
library(scales)

# get idaho ACS pop data --------------------------------------------------

# id_pop <- 2009:2019 %>%
#   map_df(~get_acs("county", variables = "B01001_001", year = ., state = "Idaho"), .id = "year") %>%
#   mutate(year = 2008 + as.numeric(year))
#
# write_csv(id_pop, "static/data/idaho-inflow/id-total-population-acs-5year.csv")

id_pop <- read_csv("../../static/data/idaho-inflow/id-total-population-acs-5year.csv")

total_pop <- id_pop %>%
  group_by(year) %>%
  summarise(estimate = sum(estimate))

us_pop_change_09_19 <- (324697795 - 301461533) / 301461533

pop_change_09_19 <- total_pop %>%
  filter(year %in% c(2009, 2019)) %>%
  arrange(desc(year)) %>%
  summarise(pct_chg = (first(estimate) - last(estimate)) / last(estimate)) %>%
  pull(pct_chg)

pop_change_14_18 <- total_pop %>%
  filter(year %in% c(2014, 2018)) %>%
  arrange(desc(year)) %>%
  summarise(pct_chg = (first(estimate) - last(estimate)) / last(estimate)) %>%
  pull(pct_chg)

p_id_total_pop <- ggplot() +
  geom_line(data = total_pop, aes(x = year, y = estimate), color = "grey", size = 1.1) +
  geom_line(
    data = filter(total_pop, year %in% 2014:2018),
    aes(x = year, y = estimate), color = "orange", size = 1.1
  ) +
  geom_point(data = total_pop, aes(x = year, y = estimate), color = "grey", size = 2) +
  geom_point(
    data = filter(total_pop, year %in% 2014:2018),
    aes(x = year, y = estimate), color = "orange",
    size = 2
  ) +
  annotate("text", x = 2014, y = 1615000, label = comma(1599464, scale = 1/1000000, suffix = "M", accuracy = 0.01), color = "orange") +
  annotate("text", x = 2018.4, y = 1680000, label = comma(1687809, scale = 1/1000000, suffix = "M", accuracy = 0.01), color = "orange") +
  scale_x_continuous(name = "", breaks = seq(2009, 2019, 2)) +
  scale_y_continuous(
    name = "Total Population",
    limits = c(1470000, 1730000),
    labels = label_number(scale = 1/1000000, suffix = "M", accuracy = 0.01)
  ) +
  labs(
    title = "Idaho State Population, 2009-2014",
    caption = md("Source: ACS 5-year Estimates, gathered from the Census API via *tidycensus*")
  ) +
  theme_minimal(base_size = 15) +
  theme(panel.grid.minor = element_blank(), plot.caption = element_markdown())

# prep county-county inflow data ------------------------------------------

fp <- dir("../../static/data/idaho-inflow/", pattern = "xlsx", full.names = TRUE)

id <- read_excel(fp, sheet = "Idaho", skip = 3)

names(id) <- c(
  "current_state_code",
  "current_fips_code",
  "prior_state_code",
  "prior_fips_code",
  "current_state",
  "current_county",
  "current_pop_est",
  "current_pop_moe",
  "current_nonmovers_est",
  "current_nonmovers_moe",
  "current_movers_us_est",
  "current_movers_us_moe",
  "current_movers_same_county_est",
  "current_movers_same_county_moe",
  "current_movers_diff_county_est",
  "current_movers_diff_county_moe",
  "current_movers_diff_state_est",
  "current_movers_diff_state_moe",
  "current_movers_abroad_est",
  "current_movers_abroad_moe",
  "prior_state",
  "prior_county",
  "prior_pop_est",
  "prior_pop_moe",
  "prior_nonmovers_est",
  "prior_nonmovers_moe",
  "prior_movers_us_est",
  "prior_movers_us_moe",
  "prior_movers_same_county_est",
  "prior_movers_same_county_moe",
  "prior_movers_diff_county_est",
  "prior_movers_diff_county_moe",
  "prior_movers_diff_state_est",
  "prior_movers_diff_state_moe",
  "prior_movers_pr_est",
  "prior_movers_pr_moe",
  "movers_in_county_to_county_flow_est",
  "movers_in_county_to_county_flow_moe"
)

# find top 15 counties ----------------------------------------------------

id_top_10 <- id %>%
  group_by(prior_state, prior_county = str_remove(prior_county, " County")) %>%
  summarise(
    est = sum(movers_in_county_to_county_flow_est),
    moe = moe_sum(movers_in_county_to_county_flow_moe, movers_in_county_to_county_flow_est)
  ) %>%
  ungroup() %>%
  filter(prior_state %in% state.name, prior_state != "Idaho") %>%
  arrange(desc(est)) %>%
  slice(1:10)

ada_top_10 <- id %>%
  filter(current_county == "Ada County") %>%
  group_by(prior_state, prior_county = str_remove(prior_county, " County")) %>%
  summarise(
    est = sum(movers_in_county_to_county_flow_est),
    moe = moe_sum(movers_in_county_to_county_flow_moe, movers_in_county_to_county_flow_est)
  ) %>%
  ungroup() %>%
  filter(prior_state %in% state.name, prior_state != "Idaho") %>%
  arrange(desc(est)) %>%
  slice(1:10)

inflow_ranking_table <- function(dat, location = "Idaho") {
  gt(data = dat) %>%
    tab_header(
      title = str_glue("Top 10 US counties contributing to {location} Growth"),
      subtitle = "Out-of-state moves counted between 2014-2018. Estimates for people aged 1+ years."
    ) %>%
    tab_footnote(footnote = "Prior state/county of residence", cells_column_labels("prior_state")) %>%
    tab_footnote(footnote = "Margin of Error (aggregated)", cells_column_labels("moe")) %>%
    tab_source_note(md("Source: 2014-2018 ACS County-to-County Migration Inflows.<br>Table: Andrew Moore @mooreaw_ 6/8/21")) %>%
    tab_style(
      style = cell_text(font = google_font("Roboto"), size = px(15)),
      locations = cells_body(columns = everything())
    ) %>%
    tab_style(
      style = cell_text(font = google_font("Roboto"), weight = "bold", size = px(18)),
      locations = cells_column_labels(everything())
    ) %>%
    fmt_number(columns = c("moe", "est"), decimals = 0) %>%
    cols_label(
      prior_state = "State",
      prior_county = "County",
      est = "Est.",
      moe = "(MoE.)"
    )
}

t_id_top_10  <- inflow_ranking_table(id_top_10, "Idaho Population")
t_ada_top_10 <- inflow_ranking_table(ada_top_10, "Ada County")
