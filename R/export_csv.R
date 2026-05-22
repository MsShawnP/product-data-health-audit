frames_dir <- file.path("output", "frames")
rds_files <- list.files(frames_dir, pattern = "[.]rds$", full.names = TRUE)
for (f in rds_files) {
  obj <- readRDS(f)
  if (is.data.frame(obj)) {
    csv_path <- sub("[.]rds$", ".csv", f)
    write.csv(obj, csv_path, row.names = FALSE)
    cat(sprintf("  %s -> %d rows\n", basename(csv_path), nrow(obj)))
  }
}
