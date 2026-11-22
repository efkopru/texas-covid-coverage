# _report.R -- helpers shared by the scripts that build the Markdown documents
# from their templates (R/10_report_tables.R and R/15_early_outputs.R).
#
# A template contains two kinds of marker:
#   {{TABLE:title}}   on a line of its own: replaced by the table of that title
#   {{v:key}}         anywhere in the text: replaced by the value of that key
# Filling stops with an error if a table or value is missing or a marker is left
# over, so a document cannot be produced with a gap or drift from the result files.

suppressMessages(library(data.table))

rd <- function(f, ...) fread(file.path(DIR_TAB, f), ...)
# A rounded number such as "-0.00" is written "0.00"
nz <- function(s) gsub("-(0[.]0+)(?![0-9])", "\\1", s, perl = TRUE)
# Markdown table from a data frame; `digits` is a named list of decimals per column (default 2)
md <- function(x, digits = NULL) {
  x <- as.data.frame(x, stringsAsFactors = FALSE, check.names = FALSE)
  for (j in seq_along(x)) if (is.numeric(x[[j]])) {
    dg <- if (!is.null(digits) && names(x)[j] %in% names(digits)) digits[[names(x)[j]]] else 2
    x[[j]] <- ifelse(is.na(x[[j]]), "", nz(formatC(x[[j]], format = "f", digits = dg, big.mark = ",")))
  }
  for (j in seq_along(x)) x[[j]][is.na(x[[j]])] <- ""
  c(paste0("| ", paste(names(x), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(x)), collapse = "|"), "|"),
    apply(x, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
}
ci <- function(m, lo, hi, d = 2) nz(sprintf(paste0("%.", d, "f (%.", d, "f to %.", d, "f)"), m, lo, hi))
f1 <- function(x, d = 1) formatC(x, format = "f", digits = d, big.mark = ",")
f0 <- function(x) formatC(round(x), format = "d", big.mark = ",")
pct0 <- function(x) sprintf("%.0f%%", x)
pct1 <- function(x) sprintf("%.1f%%", x)

fill_template <- function(template, output, tables, V, quiet = FALSE) {
  tpl <- readLines(template, encoding = "UTF-8", warn = FALSE)
  res <- character()
  for (ln in tpl) {
    if (grepl("^[{][{]TABLE:.*[}][}]$", ln)) {
      ti <- sub("^[{][{]TABLE:(.*)[}][}]$", "\\1", ln)
      if (is.null(tables[[ti]])) stop("No table called: ", ti)
      res <- c(res, tables[[ti]])
    } else {
      while (grepl("[{][{]v:[A-Za-z0-9_]+[}][}]", ln)) {
        key <- sub(".*?[{][{]v:([A-Za-z0-9_]+)[}][}].*", "\\1", ln, perl = TRUE)
        if (is.null(V[[key]])) stop("No value called: ", key)
        ln <- sub(sprintf("{{v:%s}}", key), as.character(V[[key]])[1], ln, fixed = TRUE)
      }
      res <- c(res, ln)
    }
  }
  left <- grep("[{][{]", res, value = TRUE)
  if (length(left)) stop("Unfilled markers remain:\n", paste(left, collapse = "\n"))
  con <- file(output, open = "wb"); writeLines(enc2utf8(res), con, useBytes = TRUE); close(con)
  if (!quiet) msg("Wrote %s (%d lines, %d values, %d tables)", output, length(res), length(V), length(tables))
  invisible(res)
}
