# 00_setup.R -- install the R packages this project needs.
#
# Packages that are missing are installed into a project-local library (r-lib/)
# so the user's global R library is left alone. Run from the project root:
#   Rscript --vanilla R/00_setup.R
#
# R-INLA is not on CRAN; it comes from the R-INLA project's own repository.

lib <- file.path(getwd(), "r-lib")
dir.create(lib, showWarnings = FALSE)
.libPaths(c(lib, .libPaths()))

repos <- c(CRAN = "https://cloud.r-project.org",
           INLA = "https://inla.r-inla-download.org/R/stable")

need <- c(
  "curl", "data.table", "readxl", "jsonlite",  # downloading and reading source files
  "sf", "spdep",                               # county boundaries, adjacency
  "Matrix", "INLA", "sn",                      # Bayesian model fitting
  "ggplot2", "patchwork", "scales", "ragg", "systemfonts",   # figures
  "commonmark", "base64enc"                    # HTML copies of the documents
)

have <- rownames(installed.packages())
miss <- setdiff(need, have)
cat("Already installed:", paste(intersect(need, have), collapse = ", "), "\n")
cat("To install       :", paste(miss, collapse = ", "), "\n")

# Prebuilt (binary) packages where R offers them, on Windows and macOS. Elsewhere, as on Linux, R only
# installs from source, which needs compilers and, for sf and spdep, the GDAL, GEOS and PROJ libraries.
pkg_type <- if (.Platform$pkgType == "source") "source" else "binary"
if (length(miss)) {
  install.packages(miss, lib = lib, repos = repos,
                   dependencies = c("Depends", "Imports", "LinkingTo"),
                   type = pkg_type)
}

have <- rownames(installed.packages())
still <- setdiff(need, have)
if (length(still)) stop("Could not install: ", paste(still, collapse = ", "))

v <- as.data.frame(installed.packages()[need, c("Package", "Version", "LibPath")], stringsAsFactors = FALSE)
# which library each package came from, without the full path (it would name the folders of whoever ran this)
same <- normalizePath(v$LibPath, winslash = "/", mustWork = FALSE) == normalizePath(lib, winslash = "/", mustWork = FALSE)
v$Library <- ifelse(same, "project library (r-lib)", "library outside the project")
v$LibPath <- NULL
dir.create("outputs", showWarnings = FALSE)
write.csv(v, "outputs/r_package_versions.csv", row.names = FALSE)
print(v, quote = FALSE, row.names = FALSE)
cat("\n", R.version.string, "\n")
