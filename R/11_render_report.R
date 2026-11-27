# 11_render_report.R -- turn the Markdown documents into self-contained HTML.
#
#   Rscript --vanilla R/11_render_report.R
#
# docs/00_summary.md          -> docs/00_summary.html         (figures embedded)
#                             -> docs/00_summary.pdf          (printed from the HTML copy by Edge or Chrome,
#                                                              if one of them is installed; see the end)
# docs/01_source_inventory.md -> docs/01_source_inventory.html
# docs/02_report.md           -> docs/02_report.html          (figures embedded)
# docs/03_early_rollout.md    -> docs/03_early_rollout.html   (figures embedded)
# The Markdown files stay the source of truth; the HTML is only for reading.

source("R/_common.R")
stopifnot(requireNamespace("commonmark", quietly = TRUE), requireNamespace("base64enc", quietly = TRUE))

css <- "
:root { --surface:#fcfcfb; --ink:#0b0b0b; --ink2:#52514e; --muted:#898781; --rule:#e1e0d9; --accent:#1c5cab; --wash:#f3f2ee; }
@media (prefers-color-scheme: dark) { :root { --surface:#1a1a19; --ink:#f0efec; --ink2:#c3c2b7; --muted:#898781; --rule:#383835; --accent:#86b6ef; --wash:#232321; } }
* { box-sizing: border-box; }
body { margin:0; background:var(--surface); color:var(--ink); font:16px/1.6 system-ui,-apple-system,'Segoe UI',sans-serif; }
main { max-width: 60rem; margin: 0 auto; padding: 2.5rem 1.25rem 5rem; }
h1 { font-size: 1.9rem; line-height: 1.2; margin: 0 0 1rem; }
h2 { font-size: 1.35rem; margin: 2.6rem 0 0.6rem; padding-top: 1.2rem; border-top: 1px solid var(--rule); }
h3 { font-size: 1.08rem; margin: 1.8rem 0 0.4rem; }
p, li { max-width: 46rem; }
a { color: var(--accent); }
code { font: 0.86em ui-monospace, Consolas, monospace; background: var(--wash); padding: 0.08em 0.3em; border-radius: 3px; overflow-wrap: anywhere; }
pre { background: var(--wash); padding: 0.9rem 1rem; border-radius: 6px; overflow-x: auto; }
pre code { background: none; padding: 0; }
img { max-width: 100%; height: auto; display: block; margin: 1.2rem 0 0.3rem; border: 1px solid var(--rule); border-radius: 6px; background:#fcfcfb; }
.tablewrap { overflow-x: auto; margin: 1rem 0 1.4rem; }
table { border-collapse: collapse; font-size: 0.88rem; font-variant-numeric: tabular-nums; min-width: 60%; }
th, td { padding: 0.38rem 0.7rem; border-bottom: 1px solid var(--rule); text-align: left; vertical-align: top; }
th { color: var(--ink2); font-weight: 600; border-bottom: 2px solid var(--rule); }
td[align=right], th[align=right] { text-align: right; }
thead:not(:has(th:not(:empty))) { display: none; }   /* a header row with no text in it */
blockquote { margin: 1rem 0; padding: 0.2rem 1rem; border-left: 3px solid var(--rule); color: var(--ink2); }
/* on paper: always the light colours, full-width text, and no figure or table row split across pages */
@page { size: Letter; margin: 19mm 19mm 20mm; }
@media print {
  :root { --surface:#ffffff; --ink:#0b0b0b; --ink2:#3a3936; --muted:#6f6d67; --rule:#cfcdc4; --accent:#1c5cab; --wash:#f3f2ee; }
  body { font-size: 10.5pt; line-height: 1.45; }
  main { max-width: none; padding: 0; }
  h1 { font-size: 19pt; } h2 { font-size: 13.5pt; margin-top: 1.5rem; padding-top: 0.8rem; } h3 { font-size: 11.5pt; }
  h1, h2, h3 { break-after: avoid; }
  p, li { max-width: none; orphans: 3; widows: 3; }
  img { max-height: 150mm; width: auto; margin-left: auto; margin-right: auto; break-inside: avoid; }
  p:has(> img) { break-after: avoid; margin-bottom: 0; }
  .tablewrap { overflow: visible; break-inside: avoid; } table { width: 100%; font-size: 9pt; } tr { break-inside: avoid; }
  p:has(+ .tablewrap) { break-after: avoid; }
}
"

# title and description go into the head, where search engines and link previews look for them
render <- function(md_file, html_file, title, description) {
  txt <- paste(readLines(md_file, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  body <- commonmark::markdown_html(txt, extensions = c("table", "autolink", "strikethrough"))
  # embed local PNG figures
  m <- gregexpr('<img src="([^"]+[.]png)"', body)
  srcs <- unique(sub('<img src="', "", sub('"$', "", regmatches(body, m)[[1]])))
  for (s in srcs) {
    f <- normalizePath(file.path(dirname(md_file), s), mustWork = FALSE)
    if (file.exists(f)) body <- gsub(paste0('src="', s, '"'), paste0('src="', base64enc::dataURI(file = f, mime = "image/png"), '"'), body, fixed = TRUE)
  }
  # links between these documents point at their HTML versions (other
  # Markdown files, such as the README, have no HTML copy and keep their link)
  body <- gsub('href="(00_summary|01_source_inventory|02_report|03_early_rollout)[.]md(#[^"]*)?"', 'href="\\1.html\\2"', body)
  body <- gsub("<table>", '<div class="tablewrap"><table>', body, fixed = TRUE)
  body <- gsub("</table>", "</table></div>", body, fixed = TRUE)
  html <- paste0('<!doctype html>\n<html lang="en"><head><meta charset="utf-8">',
                 '<meta name="viewport" content="width=device-width, initial-scale=1">',
                 "<title>", title, "</title>", '<meta name="description" content="', description, '">',
                 "<style>", css, "</style></head><body><main>\n", body, "\n</main></body></html>\n")
  con <- file(html_file, open = "wb"); writeLines(enc2utf8(html), con, useBytes = TRUE); close(con)
  msg("Wrote %s (%.1f MB)", html_file, file.size(html_file) / 1e6)
}
if (file.exists("docs/00_summary.md")) render("docs/00_summary.md", "docs/00_summary.html", "Texas vaccination study: summary report",
  paste("Summary of a Bayesian spatiotemporal analysis of first-dose COVID-19 vaccination coverage across Texas counties,",
        "December 2020 to May 2023: main findings, key numbers and limitations."))
render("docs/01_source_inventory.md", "docs/01_source_inventory.html", "Texas vaccination study: source inventory",
  paste("Every source of the Texas county vaccination study, what was verified in it, and why the age group, time",
        "intervals and study period differ from the proposal."))
if (file.exists("docs/02_report.md")) render("docs/02_report.md", "docs/02_report.html", "Texas vaccination study: report",
  paste("Full report of a Bayesian spatiotemporal analysis of COVID-19 vaccination coverage across Texas counties,",
        "May 2021 to May 2023: methods, results, model checks and limitations."))
if (file.exists("docs/03_early_rollout.md")) render("docs/03_early_rollout.md", "docs/03_early_rollout.html",
                                                    "Texas vaccination study: early rollout extension",
  paste("Extension of the Texas county vaccination study back to the first doses, December 2020 to May 2021, under an",
        "explicit assumption about recipients who had no county on record."))

# ---------------------------------------------------------------------------
# PDF copy of the summary, for readers who do not have this folder.
# A Chromium-based browser (Microsoft Edge or Google Chrome) prints the HTML
# copy; if none is installed the step is skipped with a message. Set the
# environment variable TXCOV_BROWSER to the browser's program file to choose one.
# Links are turned into plain text first: a PDF would store them as absolute
# paths on this computer, which mean nothing to another reader and name the
# user's own folders. Page headers and footers are off for the same reason.
# ---------------------------------------------------------------------------
find_browser <- function() {
  cand <- c(Sys.getenv("TXCOV_BROWSER"),
            file.path(Sys.getenv("ProgramFiles(x86)"), "Microsoft/Edge/Application/msedge.exe"),
            file.path(Sys.getenv("ProgramFiles"), "Microsoft/Edge/Application/msedge.exe"),
            file.path(Sys.getenv("ProgramFiles"), "Google/Chrome/Application/chrome.exe"),
            file.path(Sys.getenv("LOCALAPPDATA"), "Google/Chrome/Application/chrome.exe"),
            "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            unname(Sys.which(c("microsoft-edge", "google-chrome", "chromium", "chromium-browser"))))
  cand <- cand[nzchar(cand) & file.exists(cand) & !dir.exists(cand)]
  if (length(cand)) cand[1] else NA_character_
}
html_to_pdf <- function(html_file, pdf_file) {
  exe <- find_browser()
  if (is.na(exe)) { msg("No Edge or Chrome found, so %s was not written", pdf_file); return(invisible(FALSE)) }
  html <- paste(readLines(html_file, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  html <- gsub('<a href="[^"]*">(.*?)</a>', "\\1", html, perl = TRUE)
  stopifnot(!grepl("<a ", html, fixed = TRUE))
  work <- tempfile("txcov_pdf_"); dir.create(work)
  on.exit(unlink(work, recursive = TRUE), add = TRUE)
  src <- file.path(work, "summary.html")
  con <- file(src, open = "wb"); writeLines(enc2utf8(html), con, useBytes = TRUE); close(con)
  out <- file.path(normalizePath(dirname(pdf_file), winslash = "/"), basename(pdf_file))
  if (file.exists(out)) file.remove(out)
  url <- paste0("file:///", sub("^/", "", utils::URLencode(normalizePath(src, winslash = "/"))))
  args <- c("--headless=new", "--disable-gpu", "--no-first-run", "--no-default-browser-check", "--disable-background-networking",
            "--disable-component-update", "--disable-sync", "--no-pdf-header-footer", "--print-to-pdf-no-header",
            paste0("--user-data-dir=", shQuote(file.path(work, "profile"))), paste0("--print-to-pdf=", shQuote(out)), shQuote(url))
  system2(exe, args, stdout = FALSE, stderr = FALSE)
  ok <- file.exists(out) && file.size(out) > 20000
  if (ok) msg("Wrote %s (%.1f MB), printed by %s", pdf_file, file.size(out) / 1e6, basename(exe))
  else msg("The browser did not produce %s", pdf_file)
  invisible(ok)
}
if (file.exists("docs/00_summary.html")) html_to_pdf("docs/00_summary.html", "docs/00_summary.pdf")
