# _plot.R -- shared chart styling.
#
# Colour roles follow one rule each: a single blue ramp for magnitude, a
# blue-grey-red scale for values either side of a reference, and at most three
# fixed hues for named series (checked for colour-vision-deficiency separation).
# Text is always neutral ink; marks carry the colour.

suppressMessages({library(ggplot2); library(sf); library(patchwork); library(scales)})

PAL <- list(
  surface = "#fcfcfb", ink = "#0b0b0b", ink2 = "#52514e", muted = "#898781",
  grid = "#e1e0d9", axis = "#c3c2b7",
  blue = "#2a78d6", orange = "#eb6834", aqua = "#1baf7a",
  seq6 = c("#cde2fb", "#9ec5f4", "#6da7ec", "#3987e5", "#1c5cab", "#0d366b"),
  flag = "#c3c2b7",        # counties whose records exceed their population
  context = "#c3c2b7"      # de-emphasised series
)
# Diverging scale: three blue steps, neutral grey midpoint, three red steps
PAL$div7 <- c(rev(c("#9ec5f4", "#3987e5", "#184f95")), "#f0efec",
              colorRampPalette(c("#f0efec", "#e34948", "#7a1717"), space = "Lab")(7)[c(3, 5, 7)])
PAL$div7 <- rev(PAL$div7)   # low values red ... high values blue

FONT <- local({
  fam <- tryCatch(unique(systemfonts::system_fonts()$family), error = function(e) character())
  if ("Segoe UI" %in% fam) "Segoe UI" else "sans"
})

theme_tx <- function(base_size = 11) {
  theme_minimal(base_size = base_size, base_family = FONT) +
    theme(plot.background = element_rect(fill = PAL$surface, colour = NA),
          panel.background = element_rect(fill = PAL$surface, colour = NA),
          panel.grid.major = element_line(colour = PAL$grid, linewidth = 0.3),
          panel.grid.minor = element_blank(),
          axis.line.x = element_line(colour = PAL$axis, linewidth = 0.4),
          axis.ticks = element_line(colour = PAL$axis, linewidth = 0.3),
          text = element_text(colour = PAL$ink),
          axis.text = element_text(colour = PAL$muted, size = rel(0.9)),
          axis.title = element_text(colour = PAL$ink2, size = rel(0.95)),
          plot.title = element_text(face = "bold", size = rel(1.2), margin = margin(b = 4)),
          plot.subtitle = element_text(colour = PAL$ink2, size = rel(0.95), margin = margin(b = 10), lineheight = 1.1),
          plot.caption = element_text(colour = PAL$muted, hjust = 0, size = rel(0.8), lineheight = 1.15, margin = margin(t = 10)),
          plot.title.position = "plot", plot.caption.position = "plot",
          strip.text = element_text(colour = PAL$ink, face = "bold", hjust = 0, size = rel(0.95)),
          legend.position = "top", legend.justification = "left",
          legend.title = element_text(colour = PAL$ink2, size = rel(0.85)),
          legend.text = element_text(colour = PAL$ink2, size = rel(0.85)),
          legend.key.size = unit(0.9, "lines"),
          plot.margin = margin(14, 16, 12, 14))
}
theme_tx_map <- function(base_size = 11) {
  theme_tx(base_size) +
    theme(axis.text = element_blank(), axis.title = element_blank(), axis.ticks = element_blank(),
          axis.line.x = element_blank(), panel.grid.major = element_blank())
}

save_fig <- function(p, name, width, height) {
  f <- file.path(DIR_FIG, paste0(name, ".png"))
  ragg::agg_png(f, width = width, height = height, units = "in", res = 200, background = PAL$surface)
  print(p)
  invisible(dev.off())
  msg("  wrote %s", f)
}

# Choropleth of a binned variable. `cls` is a factor column in `data`; counties
# with flag == TRUE are drawn in neutral grey whatever their value.
map_binned <- function(shape, data, cls, colours, legend_title, flag_label = "Records exceed population") {
  g <- merge(shape, data, by = "fips")
  lev <- levels(data[[cls]])
  g$fill <- as.character(g[[cls]])
  g$fill[g$flag] <- flag_label
  g$fill <- factor(g$fill, levels = c(lev, flag_label))
  ggplot(g) +
    geom_sf(aes(fill = fill), colour = PAL$surface, linewidth = 0.12, show.legend = TRUE) +
    scale_fill_manual(values = setNames(c(colours, PAL$flag), c(lev, flag_label)), drop = FALSE, name = legend_title,
                      guide = guide_legend(nrow = 1, label.position = "bottom", title.position = "top",
                                           keywidth = unit(2.1, "lines"), keyheight = unit(0.55, "lines"))) +
    coord_sf(datum = NA) +
    theme_tx_map()
}
