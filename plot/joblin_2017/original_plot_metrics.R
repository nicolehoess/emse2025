# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

# Plots the agreement for metrics observed in the original study by Joblin et al.. 2017.

Sys.setenv(LANG = "en")
Sys.setenv(TZ = "UTC")

library(conflicted)
library(dplyr)
library(ggplot2)
library(ggh4x) # devtools::install_github("teunbrand/ggh4x")
library(gridExtra)
library(patchwork)
library(scales)
library(yaml)
library(tidyverse)
library(this.path)

setwd(this.path::here())
source("layout.R", chdir=TRUE)

library(tikzDevice)
options(tikzLatexPackages = c(getOption("tikzLatexPackages"),
                              "\\usepackage{amsmath}"))

library("optparse")


option_list = list(
  make_option(c("--res_path"), type="character", default=NULL,
              help="Path to the study's analysis results directory",
              metavar="character"),
  make_option(c("--conf_path"), type="character", default=NULL,
              help="Path to the folder containing the project configuration files",
              metavar="character"),
  make_option(c("--tikz"), type="logical", default=FALSE, action="store_true",
              help="Plot the tikz graph")
);

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);


#' Plots the metrics agreement observed in the original study.
#' Values are hard-coded because scripts were not fully available,
#' which does not allow for an exact reproduction.
#'
#' @param project the project name.
#' @return the agreement plot.
#'
original_agreement_plot <- function(project, y_axis=FALSE, cap="") {
  cols <- c("Hierarchy",  "EigenCent", "Degree", "LOC",
            "Commits")
  metric_1 = c("EigenCent", "Degree", "Degree",
               "LOC", "LOC", "LOC",
               "Commits", "Commits", "Commits", "Commits")
  metric_2 = c("Hierarchy", "Hierarchy", "EigenCent", "Hierarchy",
               "EigenCent", "Degree", "Hierarchy", "EigenCent",
               "Degree", "LOC")
  if (project == "django") {
    value = c(0.56, 0.79, 0.62, 0.53, 0.43, 0.49, 0.49, 0.4, 0.49, 0.57)
  } else if (project == "ffmpeg") {
    value = c(0.64, 0.85, 0.63, 0.57, 0.59, 0.57, 0.62, 0.52, 0.62, 0.63)
  } else if (project == "gcc") {
    value = c(0.51, 0.8, 0.56, 0.37, 0.29, 0.33, 0.56, 0.36, 0.52, 0.58)
  } else if (project == "linux") {
    value = c(0.49, 0.8, 0.51, 0.44, 0.31, 0.38, 0.53, 0.35, 0.47, 0.63)
  } else if (project == "llvm-project") {
    value = c(0.65, 0.9, 0.64, 0.58, 0.56, 0.55, 0.63, 0.57, 0.60, 0.70)
  } else if (project == "postgresql") {
    value = c(0.58, 0.85, 0.57, 0.36, 0.32, 0.35, 0.64, 0.56, 0.64, 0.53)
  } else if (project == "qemu") {
    value = c(0.47, 0.83, 0.48, 0.56, 0.40, 0.52, 0.62, 0.43, 0.60, 0.72)
  } else if (project == "u-boot") {
    value = c(0.48, 0.81, 0.49, 0.39, 0.29, 0.39, 0.45, 0.35, 0.45, 0.62)
  } else if (project == "wine") {
    value = c(0.49, 0.87, 0.5, 0.53, 0.35, 0.52, 0.68, 0.42, 0.67, 0.72)
  }

  df <- data.frame(metric_1 = metric_1, metric_2 = metric_2, value = value)

  df_mirror <- df
  df_mirror$metric_1 <- factor(df$metric_1, levels=rev(cols))
  df_mirror$metric_2 <- factor(df$metric_2, levels=rev(cols))
  df_long <- rbind(df, df_mirror)

  if (y_axis) {
    y_axis_el <- element_text(size = SMALL.SIZE*1.5)
  } else {
    y_axis_el <- element_blank()
  }

  p <- ggplot(df_long, aes(x = metric_1, y = metric_2, fill = value)) +
    labs(title=cap) +
    xlim(cols[2:length(cols)]) + # Save space by shifting duplicate features
    ylim(cols[1:(length(cols)-1)]) +
    geom_tile(colour="black",
              size=1, lwd=LINE.SIZE-0.1) +
    scale_fill_gradient2(low = COLOURS.LIST[3],  mid = "#FFFFFF",
                         high = COLOURS.LIST[2], limits=c(-1, 1), guide="none") +
    geom_text(aes(label = round(value, 2)), color = "black",
              size = TABLE.FONT.SIZE*1.5) +
    coord_equal() +
    theme_paper_base() +
    theme(plot.title=element_text(size=SMALL.SIZE*1.5, hjust = 0.5),
          axis.title.x=element_blank(), axis.title.y=element_blank(),
          axis.text = element_text(size = SMALL.SIZE*1.5), # Tick font size
          axis.text.x = element_text(size = SMALL.SIZE*1.5,  # x-axis tick font size
                                     angle=45, hjust=1, vjust=1), # x-axis tick angle
          axis.text.y = y_axis_el  # x-axis tick font size
    )

  return(p)
}

projects <- c("django", "ffmpeg", "gcc", "linux", "llvm-project", "postgresql", "qemu", "u-boot", "wine")
captions <- c("Django", "FFmpeg", "GCC", "Linux", "LLVM", "PostgreSQL", "QEMU", "U-Boot", "Wine")


# Agreement matrix plot.
i <- 1
for (project in projects) {
  if (!dir.exists(path.join(opt$res_path, "codeface", project))) {
    next  # Skip if the project was not analysed.
  }

  # Plot the pairwise agreement for each metric.
  p <- original_agreement_plot(project = project,
                      y_axis=TRUE, cap=captions[i])

  # Save the plot.
  plot_save_path <- str_c("original_agreement.pdf")
  if (!dir.exists(project)) {
    dir.create(project, recursive = TRUE)
  }
  ggsave(file.path(project, plot_save_path), plot = p,
         width = 0.61*TEXTWIDTH, height = 0.62*TEXTWIDTH, units = "in")
  plot(p)

  if (opt$tikz) {
    plot_save_path <- str_c("original_", project, "_agreement", ".tex")
    tikz(file.path("img-tikz", plot_save_path),
         width = 0.61*TEXTWIDTH, height = 0.62*TEXTWIDTH)
    print(p)
    dev.off()
  }
  i <- i+1
}
