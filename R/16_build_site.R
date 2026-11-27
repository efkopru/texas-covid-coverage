# 16_build_site.R -- build the interactive report site from the result files.
#
#   Rscript --vanilla R/16_build_site.R
#
# Reads the tables written by steps 5-15 and the county boundaries, and writes
#   site/index.html     a standalone app: one file holding the page, its code,
#                       the county map outlines and every number it draws. It
#                       loads nothing from the network; open it in a browser.
#   site/preview.png    the picture that link previews show for the web copy
#                       (1200 x 630 pixels: county coverage on 9 May 2023)
# from the template site/src/page.html. Numbers quoted in the page text are
# filled from outputs/tables/report_values.csv and early_report_values.csv
# ({{v:key}} for the main report, {{v:x_key}} for the early-rollout extension, {{v:rr_key}} for the rerun check),
# so the site cannot drift from the reports.

source("R/_common.R")
source("R/_report.R")
suppressMessages({library(sf); library(jsonlite)})
options(scipen = 999)
dir.create("site/src", recursive = TRUE, showWarnings = FALSE)
r1 <- function(x, d = 1) ifelse(is.na(x), NA, round(x, d))
rdf <- function(f, ...) fread(file.path(DIR_DERIVED, f), ...)

# ---------------------------------------------------------------------------
# 1. County outlines as SVG paths (Texas Centric Albers Equal Area, 1000 units wide)
# ---------------------------------------------------------------------------
shape <- st_read(file.path(DIR_DERIVED, "tx_counties.gpkg"), quiet = TRUE)[, "fips"]
g <- st_simplify(st_transform(shape, 3083), preserveTopology = TRUE, dTolerance = 500)
g <- st_cast(g, "MULTIPOLYGON")
bb <- st_bbox(g); W <- 1000; sc <- W / as.numeric(bb["xmax"] - bb["xmin"]); H <- as.numeric(bb["ymax"] - bb["ymin"]) * sc
ring <- function(m) {
  x <- round((m[, 1] - bb["xmin"]) * sc, 1); y <- round((bb["ymax"] - m[, 2]) * sc, 1)
  keep <- c(TRUE, diff(x) != 0 | diff(y) != 0)
  paste0("M", paste(paste(x[keep], y[keep], sep = " "), collapse = "L"), "Z")
}
paths <- vapply(seq_len(nrow(g)), function(i) paste(unlist(lapply(st_geometry(g)[[i]], function(poly) lapply(poly, ring))), collapse = ""), "")
cen <- st_coordinates(st_point_on_surface(st_geometry(g)))
geo <- data.table(fips = g$fips, d = paths, cx = round((cen[, 1] - bb["xmin"]) * sc, 1), cy = round((bb["ymax"] - cen[, 2]) * sc, 1))
msg("County outlines: %d paths, %.0f KB of path data, view box %d x %.0f", nrow(geo), sum(nchar(geo$d)) / 1024, W, H)

# ---------------------------------------------------------------------------
# 2. Data
# ---------------------------------------------------------------------------
ct  <- rd("county_results.csv", colClasses = list(character = "fips"))
ca  <- rdf("early_county_allocation.csv", colClasses = list(character = "fips"))
rec <- rdf("early_reconstruction.csv", colClasses = list(character = "fips")); rec[, as_of := as.Date(as_of)]
ed  <- rdf("coverage_editions.csv", colClasses = list(character = "fips")); ed[, as_of := as.Date(as_of)]
px  <- rdf("panel_ext_H.csv", colClasses = list(character = "fips"))
mu  <- rd("modelled_uptake_county_interval.csv", colClasses = list(character = "fips"))
me  <- rd("early_modelled_uptake.csv", colClasses = list(character = "fips"))
ru  <- rd("early_relative_uptake_by_period.csv", colClasses = list(character = "fips"))
ho  <- rd("fig11_heldout_county_prediction.csv", colClasses = list(character = "fips"))
n_early <- length(EARLY_ASOF)
dates <- c(EARLY_ASOF, GRIDS$main)
fmt <- function(x) sub("^0", "", format(as.Date(x), "%d %b %Y"))
date_meta <- data.table(through = fmt(dates - 1), iso = format(dates - 1), kind = c(rep("reconstructed", n_early), rep("recorded", length(GRIDS$main))))

covm <- rbind(rec[as_of %in% EARLY_ASOF, .(fips, as_of, cov = fifelse(excl_county | early_unstable, NA_real_, cov_H))],
              ed[as_of %in% GRIDS$main, .(fips, as_of, cov = cov16)])
covw <- dcast(covm, fips ~ as_of, value.var = "cov")
iv <- unique(px[, .(k, label, data_from, data_to, days, early)])[order(k)]
n_iv <- nrow(iv)
upm <- rbind(me[, .(fips, k, rec = fifelse(usable, reconstructed_uptake30_pct, NA_real_),
                    med = fifelse(informed_by_own_count, modelled_uptake30_pct, NA_real_),
                    lo = fifelse(informed_by_own_count, modelled_lo, NA_real_), hi = fifelse(informed_by_own_count, modelled_hi, NA_real_))],
             mu[, .(fips, k = k + iv[early == TRUE, .N], rec = fifelse(usable, recorded_uptake30_pct, NA_real_),
                    med = modelled_uptake30_pct, lo = modelled_lo, hi = modelled_hi)])
setorder(upm, fips, k)
stopifnot(upm[, .N, by = fips][, all(N == n_iv)])
wide <- function(v, d = 3) { w <- dcast(upm, fips ~ k, value.var = v); m <- as.matrix(w[, -1]); rownames(m) <- w$fips; round(m, d) }
U <- list(rec = wide("rec"), med = wide("med"), lo = wide("lo"), hi = wide("hi"))

cty <- merge(ct[, .(fips, county, pop16, excl_county, pct65 = pct65_of_16plus, income = med_hh_income, cov_baseline, cov_end, change_pp,
                    rel_uptake, rel_uptake_lo, rel_uptake_hi, residual_effect, smooth_effect)],
             ca[, .(fips, unsettled = early_unstable, share_april = 100 * odds, elig = 100 * elig_1b_share)], by = "fips")
cty <- merge(cty, ru[, .(fips, rel_e1 = rel_early_restricted, rel_e2 = rel_spring_2021)], by = "fips", all.x = TRUE)
cty <- merge(cty, ho[, .(fips, heldout_err = err, heldout_pred = pred_cov_end)], by = "fips", all.x = TRUE)
cty <- merge(cty, geo, by = "fips")
setorder(cty, fips)
# neighbours of each county, as positions in the county list (0-based, for the page's script)
adj <- rdf("tx_adjacency_edges.csv", colClasses = "character")
nbl <- lapply(split(match(adj$nb_fips, cty$fips) - 1L, adj$fips), sort)
# a few city names for orientation, placed at a point inside their county
cities <- data.table(n = c("Houston", "Dallas", "Fort Worth", "San Antonio", "Austin", "El Paso", "Lubbock", "Amarillo", "Corpus Christi",
                           "Laredo", "McAllen", "Midland", "Tyler", "Waco"),
                     county = c("Harris", "Dallas", "Tarrant", "Bexar", "Travis", "El Paso", "Lubbock", "Potter", "Nueces", "Webb", "Hidalgo",
                                "Midland", "Smith", "McLennan"),
                     # side of the point the name is written on. Beaumont is left out: its name cannot be placed clear
                     # of both Houston's and the east edge of the map
                     a = c("start", "start", "end", "end", "start", "start", "start", "start", "start", "end", "end", "end", "start", "start"))
cities <- merge(cities, cty[, .(county, x = cx, y = cy)], by = "county", sort = FALSE)[, .(n, a, x, y)]
stopifnot(nrow(cities) == 14)
counties <- lapply(seq_len(nrow(cty)), function(i) {
  z <- cty[i]; f <- z$fips
  list(f = f, n = z$county, p = z$pop16, x = as.integer(z$excl_county), u = as.integer(z$unsettled), d = z$d,
       c = c(z$cx, z$cy), nb = I(nbl[[f]]),
       a = r1(z$pct65), inc = z$income, cb = r1(z$cov_baseline), ce = r1(z$cov_end), ch = r1(z$change_pp),
       r = r1(z$rel_uptake, 2), rl = r1(z$rel_uptake_lo, 2), rh = r1(z$rel_uptake_hi, 2), sm = r1(z$smooth_effect, 2),
       re = r1(z$residual_effect, 2), od = r1(z$share_april, 1), el = r1(z$elig, 0), e1 = r1(z$rel_e1, 2), e2 = r1(z$rel_e2, 2),
       ho = r1(z$heldout_err, 1), hp = r1(z$heldout_pred, 1),
       cov = unname(r1(unlist(covw[fips == f, -1]), 1)),
       ur = unname(U$rec[f, ]), um = unname(U$med[f, ]), ul = unname(U$lo[f, ]), uh = unname(U$hi[f, ]))
})

sp <- rd("fig14b_coverage_spread_extended.csv"); sp[, as_of := as.Date(as_of)]
stopifnot(nrow(sp) == length(dates), all(sp$as_of == dates))
st_all <- rbind(rec[as_of %in% EARLY_ASOF, .(cov = 100 * sum(n_H) / sum(pop16)), keyby = as_of],
                ed[as_of %in% GRIDS$main, .(cov = 100 * sum(n16) / sum(pop16_2021)), keyby = as_of])
upi <- rd("fig14_extended_uptake_by_interval.csv")
pa <- rd("early_period_associations.csv")
va <- rd("fig05_validation_summary.csv"); va[, experiment := gsub("\n", " ", experiment)]
un <- rd("fig12a_unassigned_share_daily.csv")
stable_n <- ca[excl_county == FALSE & early_unstable == FALSE, .N]
g4 <- rd("fig04_gap_over_time.csv")[c(1, .N)]          # the 238 modelled counties at the baseline and at the end, as in the main report

data <- list(
  built = format(Sys.Date()), view = c(W, round(H)), n_early_dates = n_early, n_early_intervals = iv[early == TRUE, .N],
  n_stable = stable_n, n_kept = ca[excl_county == FALSE, .N],
  dates = date_meta, cities = cities,
  gap238 = g4[, .(through = fmt(as.Date(data_through)), p10 = r1(p10), med = r1(median), p90 = r1(p90), gap = r1(gap_p90_p10), sd = r1(sd))],
  intervals = iv[, .(label, from = format(as.Date(data_from)), to = format(as.Date(data_to)), days, early)],
  counties = counties,
  spread = sp[, .(p10 = r1(p10), med = r1(median), p90 = r1(p90))],
  state = r1(st_all$cov),
  uptake = upi[, .(pooled = r1(uptake30_pooled_pct, 3), med = r1(modelled_median_county_pct, 3), p10 = r1(modelled_p10_county_pct, 3),
                   p90 = r1(modelled_p90_county_pct, 3))],
  assoc = pa[, .(variant, period, period_label, predictor, hr = r1(hazard_ratio, 4), lo = r1(lo, 4), hi = r1(hi, 4))],
  valid = va[, .(experiment, model, crps = r1(mean_crps_pp, 3), cover = r1(100 * coverage95, 1))],
  unassigned = un[, .(d = as_of, pct = r1(pct, 2))])
js <- as.character(toJSON(data, auto_unbox = TRUE, na = "null", digits = NA, dataframe = "rows"))
js <- gsub("</", "<\\/", js, fixed = TRUE)          # keeps the data from closing its own script block
msg("Data block: %.0f KB", nchar(js) / 1024)

# ---------------------------------------------------------------------------
# 3. The picture for link previews: recorded coverage on 9 May 2023, in the colours of the site's map
# ---------------------------------------------------------------------------
suppressMessages({library(ggplot2); library(grid)})
fams <- tryCatch(unique(systemfonts::system_fonts()$family), error = function(e) character())
f_head <- if ("Bahnschrift" %in% fams) "Bahnschrift" else if ("Segoe UI" %in% fams) "Segoe UI" else "sans"
f_text <- if ("Segoe UI" %in% fams) "Segoe UI" else "sans"
ramp9 <- c("#cde2fb", "#b7d3f6", "#9ec5f4", "#6da7ec", "#3987e5", "#2a78d6", "#1c5cab", "#104281", "#0d366b")
pm <- merge(g, as.data.frame(cty[, .(fips, excl_county, cov_end)]), by = "fips")
stopifnot(nrow(pm) == 254)
pm$fill <- ifelse(pm$excl_county, "#c3c2b7", ramp9[findInterval(pm$cov_end, seq(10, 80, 10)) + 1])
pmap <- ggplot(pm) + geom_sf(aes(fill = fill), colour = "#f9f9f7", linewidth = 0.12) + scale_fill_identity() +
  coord_sf(datum = NA, expand = FALSE) + theme_void()
ragg::agg_png("site/preview.png", width = 1200, height = 630, units = "px", res = 96, background = "#f9f9f7")
grid.newpage()
pushViewport(viewport(x = unit(1, "npc") - unit(34, "pt"), y = 0.5, width = unit(450, "pt"), height = unit(440, "pt"), just = "right"))
print(pmap, newpage = FALSE)
popViewport()
left <- unit(48, "pt")
grid.text("BAYESIAN SPATIOTEMPORAL ANALYSIS", x = left, y = unit(1, "npc") - unit(70, "pt"), just = c("left", "top"),
          gp = gpar(fontfamily = f_text, fontsize = 13, col = "#6f6d67"))
grid.text("COVID-19 vaccination\ncoverage across\nTexas counties", x = left, y = unit(1, "npc") - unit(98, "pt"),
          just = c("left", "top"), gp = gpar(fontfamily = f_head, fontface = "bold", fontsize = 40, lineheight = 1.02, col = "#0b0b0b"))
grid.text("December 2020 to May 2023\n254 counties, from archived state records", x = left, y = unit(1, "npc") - unit(270, "pt"),
          just = c("left", "top"), gp = gpar(fontfamily = f_text, fontsize = 19, lineheight = 1.25, col = "#52514e"))
grid.text("Map: residents aged 16+ with a first dose, 9 May 2023", x = left, y = unit(40, "pt"), just = c("left", "bottom"),
          gp = gpar(fontfamily = f_text, fontsize = 12, col = "#6f6d67"))
invisible(dev.off())
msg("Wrote site/preview.png (%.0f KB)", file.size("site/preview.png") / 1024)

# ---------------------------------------------------------------------------
# 4. The page
# ---------------------------------------------------------------------------
tpl <- "site/src/page.html"
# shown by search engines and link previews; the publishing step adds the preview tags themselves
description <- paste("Interactive county map of first-dose COVID-19 vaccination coverage across Texas, December 2020 to May 2023,",
                     "rebuilt from archived state records and analysed with a Bayesian spatiotemporal model.")
if (file.exists(tpl)) {
  v1 <- rd("report_values.csv"); v2 <- rd("early_report_values.csv")
  V <- c(as.list(setNames(v1$value, v1$name)), as.list(setNames(v2$value, paste0("x_", v2$name))), rerun_values())
  V$built <- sub("^0", "", format(Sys.Date(), "%d %B %Y"))
  body <- fill_template(tpl, tempfile(fileext = ".html"), list(), V, quiet = TRUE)
  msg("Filled %s (%d lines, %d values)", tpl, length(body), length(V))
  # the template's title line moves into the head, where link previews look for it
  ti <- grep("^<title>[^<]+</title>$", body)
  stopifnot(length(ti) == 1)
  title_line <- body[ti]; body <- body[-ti]
  i <- which(body == '<script src="data.js"></script>')
  stopifnot(length(i) == 1)
  body[i] <- paste0("<script>window.TXDATA = ", js, ";</script>")
  con <- file("site/index.html", open = "wb")
  writeLines(enc2utf8(c('<!doctype html>', '<html lang="en">', '<head>', '<meta charset="utf-8">',
                        '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">', title_line,
                        sprintf('<meta name="description" content="%s">', description), '</head>', '<body>',
                        body, '</body>', '</html>')), con, useBytes = TRUE)
  close(con)
  msg("Wrote site/index.html (%.0f KB)", file.size("site/index.html") / 1024)
}
msg("Done.")
