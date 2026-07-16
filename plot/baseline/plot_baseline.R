# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

# Plots the baseline metrics time series across tools.
Sys.setenv(LANG = "en")
Sys.setenv(TZ = "UTC")

library(conflicted)  
library(dplyr)
library(ggplot2)
library(ggh4x) # devtools::install_github("teunbrand/ggh4x")
library(ggforce)
library(patchwork)
library(gridExtra)
library(scales)
library(tidyverse)
library(TSclust)
library(this.path)
library(matrixStats)

setwd(this.path::here())
source("layout.R", chdir=TRUE)

library(knitr)
library(formattable)
library(kableExtra)
options(knitr.table.format = "latex")

library(tikzDevice)
options(tikzLatexPackages = c(getOption("tikzLatexPackages"),
                              "\\usepackage{amsmath}"))

library("optparse")

option_list = list(
  make_option(c("--res_path"), type="character", default=NULL,
              help="Path to the baseline data analysis results directory",
              metavar="character"),
  make_option(c("--tikz"), type="logical", default=FALSE, action="store_true",
              help="Plot the tikz graph")
);

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);

#' Formats project and tool names in the given data frame.
#'
#' @param df the data frame with original names.
#' @return the data frame with formatted names.
#'
recode_projects <- function(df) {
  df <- df %>%
    mutate(project = recode(project,
                            "birt" = "Birt",
                            "conductor" = "Conductor",
                            "django" = "Django",
                            "flink" = "Flink",
                            "postgresql" = "PostgreSQL",
                            "qemu" = "QEMU",
                            "u-boot" = "U-Boot",
                            "wine" = "Wine"),
           tool = recode(tool,
                         "codeface" = "Codeface",
                         "git2net" = "git2net",
                         "grimoire" = "GrimoireLab",
                         "kaiaulu" = "Kaiaulu"))
  return(df)
}

#' Creates a time series plot.
#'
#' @param df the merged time series data frame for all tools.
#' @return the plot.
#'
ts_plot <- function(df) {
  df <- df %>%
    rename(Time = "range_id", Tool = "tool")
  
  df_long <- pivot_longer(df,
                          cols = c(Commits,Files,Entities,Developers),
                          names_to = "metric",
                          values_to = "Count")
  df_long$Tool <- factor(df_long$Tool, levels = unique(df_long$Tool)[order(tolower(unique(df_long$Tool)))])
  df_long$metric <- factor(df_long$metric, levels = c("Commits", "Files", "Developers", "Entities"))
  df_long <- df_long %>% mutate(metric = recode(metric, "Entities" = "Entity Blocks"))
  
  p_1 <- ggplot(subset(df_long, project %in% c("Birt", "Conductor", "Django", "Flink")), 
                aes(x = Time, y = Count, color = Tool, linetype = Tool, shape = Tool)) +
    labs(x = "Time") +
    geom_line(linewidth = LINE.SIZE-0.3, alpha=1,
              position=position_dodge(width=0.5)) +
    geom_point(size = POINT.SIZE-0.1, alpha=1,
               position=position_dodge(width=0.5)) +
    scale_colour_manual(values=COLOURS.LIST[c(17,15,18,16)], name="Tool") +
    scale_linetype_manual(values=c("solid","42","solid","42"), name="Tool") +
    scale_shape_manual(values=c(16,17,4,18), name="Tool") +
    facet_grid2(metric ~ project,
                scales = "free", independent = "y") +
    scale_x_continuous(breaks = function(x) pretty(c(1, x), n = 5)) +
    theme_paper_base() +
    theme(axis.text = element_text(size = SMALL.SIZE*1.2),
          axis.text.x = element_text(size = SMALL.SIZE*1.2),
          axis.text.y = element_text(size = SMALL.SIZE*1.2),
          axis.title.x = element_blank(),
          axis.title.y = element_text(size = SMALL.SIZE*1.6),
          legend.text = element_text(size = SMALL.SIZE*1.5),
          legend.title = element_text(size = SMALL.SIZE*1.5),
          legend.key.size = unit(SYM.SIZE, "line"),
          legend.position = "top",
          strip.text = element_text(size = SMALL.SIZE*1.5))
  
  p_2 <- ggplot(subset(df_long, project %in% c("PostgreSQL", "QEMU", "U-Boot", "Wine")), 
                aes(x = Time, y = Count, color = Tool, linetype = Tool, shape = Tool)) +
    labs(x = "Time") +
    geom_line(linewidth = LINE.SIZE-0.3, alpha=1,
              position=position_dodge(width=0.5)) +
    geom_point(size = POINT.SIZE-0.1, alpha=1,
               position=position_dodge(width=0.5)) +
    scale_colour_manual(values=COLOURS.LIST[c(17,15,18,16)], name="Tool") +
    scale_linetype_manual(values=c("solid","42","solid","42"), name="Tool") +
    scale_shape_manual(values=c(16,17,4,18), name="Tool") +
    facet_grid2(metric ~ project,
                scales = "free", independent = "y") +
    scale_x_continuous(breaks = function(x) pretty(c(1, x), n = 5)) +
    theme_paper_base() +
    theme(axis.text = element_text(size = SMALL.SIZE*1.2),
          axis.text.x = element_text(size = SMALL.SIZE*1.2),
          axis.text.y = element_text(size = SMALL.SIZE*1.2),
          axis.title.x = element_text(size = SMALL.SIZE*1.6),
          axis.title.y = element_text(size = SMALL.SIZE*1.6),
          legend.position = "none",
          strip.text = element_text(size = SMALL.SIZE*1.5))
  
  
  p_1 <- p_1 + theme(plot.margin = margin(0, 0, 10, 0))
  p <- p_1 / p_2
  return(p)
}


# Prepare data.
df_codeface <- read.csv(file.path(opt$res_path, "codeface", "statistics.csv"), 
                        stringsAsFactors = FALSE)
df_git2net <- read.csv(file.path(opt$res_path, "git2net", "statistics.csv"), 
                        stringsAsFactors = FALSE)
df_grimoire <- read.csv(file.path(opt$res_path, "grimoire", "statistics.csv"), 
                        stringsAsFactors = FALSE)
df_kaiaulu <- read.csv(file.path(opt$res_path, "kaiaulu", "statistics.csv"), 
                        stringsAsFactors = FALSE)
df <- rbind(df_codeface, df_git2net, df_grimoire, df_kaiaulu)
df <- recode_projects(df)

# Plot metrics time series.
p <- ts_plot(df)
ggsave("ts.pdf", plot = p, width = TEXTWIDTH, height = 1.4*TEXTWIDTH, units = "in")
plot(p)
if (opt$tikz) {
  plot_save_path <- file.path("img-tikz", "ts.tex")
  tikz(plot_save_path, width = TEXTWIDTH, height = 1.4*TEXTWIDTH)
  print(p)
  dev.off()
}
