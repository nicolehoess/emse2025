# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

# Compares developer classifications agreement across tools.
#
# Split correlation matrix extended from:
# https://stackoverflow.com/questions/65887187/how-to-display-two-categorical-variables-on-one-tile-of-a-heatmap-triangle-til

Sys.setenv(LANG = "en")
Sys.setenv(TZ = "UTC")

library(conflicted)
library(dplyr)
library(ggplot2)
library(ggh4x) # devtools::install_github("teunbrand/ggh4x")
library(gridExtra)
library(patchwork)
library(psych)
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

#' Calculates Cohen's kappa for two tool classifications for the same metric.
#'
#' @param df the data frame with original names.
#' @param classes_1 classifications according to first tool.
#' @param classes_2 classifications according to second tool.
#' @return Cohen's kappa.
#'
compare_classification <- function(df, classes_1, classes_2) {
  if (nrow(df) == 0) {
    res <- 0
  } else if (all(df[[classes_1]] == df[[classes_2]]) && length(unique(df[[classes_1]])) == 1) {
    res <- 1
  } else {
    res <- cohen.kappa(cbind(df[, classes_1], df[, classes_2]))$kappa
  }
  return(res)
}

#' Calculates pairwise Cohen's kappa for all tools and metrics in the data frame.
#'
#' @param df the data frame with classifications for all tools and metrics.
#' @param cols the column names of the cross-tool data frame (including tool postfix).
#' @param metrics the metrics to compare across tools.
#' @return pairwise Cohen's kappa.
#'
calculate_kappa <- function(df, cols, metrics, tools) {
  df_kappa <- data.frame()
  for (m in metrics) {
    for (t1 in tools) {
      for (t2 in tools) {
        row <- data.frame(metric_1=NA, metric_2=NA, kappa=NA)
        row$metric_1 <- paste0(m, "_", t1)
        row$metric_2 <- paste0(m, "_", t2)
        row$kappa <- compare_classification(df, paste0(m, "_", t1), paste0(m, "_", t2))

        df_kappa <- rbind(df_kappa, row)
      }
    }
  }
  
  df_kappa <- df_kappa %>% pivot_wider(names_from = "metric_2", values_from = "kappa")
  tmp <- df_kappa$metric_1
  df_kappa$metric_1 <- NULL
  df_kappa[upper.tri(df_kappa, diag=TRUE)] <- NA
  df_kappa$metric_1 <- tmp
  df_kappa <- df_kappa %>% pivot_longer(cols=all_of(cols), values_to = "kappa", names_to="metric_2")
  df_kappa <- df_kappa %>% drop_na(kappa)
  
  return(df_kappa)
}

#' Creates the polygon coordinates for the tool comparison plot.
#'
#' @param x the original x coordinate.
#' @param y the original y coordinate.
#' @param point the polygon position in each tile.
#' @return the triangle coordinates.
#'
make_polygons <- function(x, y, point) {
  x <- desc(x)
  y <- desc(y)
  x <- as.integer(as.factor((x)))
  y <- as.integer(as.factor((y)))
  
  if (point == "top") {
    newx <- sapply(x, function(x) {
      c(x - 0.5, x - 0.5, x + 0.5)
    }, simplify = FALSE)
    newy <- sapply(y, function(y) {
      c(y - 0.5, y + 0.5, y + 0.5)
    }, simplify = FALSE)
  } else if (point == "left") {
    newx <- sapply(x, function(x) {
      c(x - 0.5, x - 0.5, x + 0)
    }, simplify = FALSE)
    newy <- sapply(y, function(y) {
      c(y - 0.5, y + 0.5, y + 0)
    }, simplify = FALSE)
  } else if (point == "bottom") {
    newx <- sapply(x, function(x) {
      c(x - 0.5, x + 0.5, x + 0)
    }, simplify = FALSE)
    newy <- sapply(y, function(y) {
      c(y - 0.5, y - 0.5, y + 0)
    }, simplify = FALSE)
  } else if (point == "right") {
    newx <- sapply(x, function(x) {
      c(x, x + 0.5, x + 0.5)
    }, simplify = FALSE)
    newy <- sapply(y, function(y) {
      c(y, y - 0.5, y + 0.5)
    }, simplify = FALSE)
  } else if (point == "center") {
    newx <- sapply(x, function(x) {
      c(x, x, x)
    }, simplify = FALSE)
    newy <- sapply(y, function(y) {
      c(y, y, y)
    }, simplify = FALSE)
  }
  return(data.frame(x = unlist(newx), y = unlist(newy)))
}

#' Creates the polygon label coordinates for the tool comparison plot.
#'
#' @param x the original x coordinate.
#' @param y the original y coordinate.
#' @param point the corresponding polygon position in each tile.
#' @return the label coordinates.
#'
make_label_positions <- function(x, y, point) {
  x <- desc(x)
  y <- desc(y)
  x <- as.integer(as.factor(x))
  y <- as.integer(as.factor(y))
  
  if (point == "top") {
    newx <- sapply(x, function(x) {
      c(x)
    }, simplify = FALSE)
    newy <- sapply(y, function(y) {
      c(y+0.35)
    }, simplify = FALSE)
  } else if (point == "left") {
    newx <- sapply(x, function(x) {
      c(x-0.34)
    }, simplify = FALSE)
    newy <- sapply(y, function(y) {
      c(y)
    }, simplify = FALSE)
  } else if (point == "bottom") {
    newx <- sapply(x, function(x) {
      c(x)
    }, simplify = FALSE)
    newy <- sapply(y, function(y) {
      c(y-0.35)
    }, simplify = FALSE)
  } else if (point == "right") {
    newx <- sapply(x, function(x) {
      c(x+0.34)
    }, simplify = FALSE)
    newy <- sapply(y, function(y) {
      c(y)
    }, simplify = FALSE)
  } else if (point == "center") {
    newx <- sapply(x, function(x) {
      c(x)
    }, simplify = FALSE)
    newy <- sapply(y, function(y) {
      c(y)
    }, simplify = FALSE)
  }
  data.frame(x = unlist(newx), y = unlist(newy))
}

#' Creates the tool agreement plot showing pairwise Cohen's kappa for all
#' metrics rating the same set of identified developers across tools.
#'
#' @param df_codeface the classifications when using Codeface.
#' @param df_git2net the classifications when using git2net.
#' @param df_grimoire the classifications when using GrimoireLab.
#' @param df_kaiaulu the classifications when using Kaiaulu.
#' @param y_axis whether to plot y-axis labels.
#' @param cap the plot caption (e.g. project name).
#' @return the agreement plot.
#'
agreement_plot <- function(df_codeface, df_git2net, df_grimoire, df_kaiaulu,
                           project, project_range="", y_axis=FALSE, cap="") {
  # Format data frames to ensure that metrics are in the same order as in the
  # original plot.
  cols <- c("range_id", "developer", 
            "loc_count_class",
            "commit_count_class",
            "degree_class",
            "eigenvector_class",
            "hierarchy_class")
  df_codeface <- df_codeface[cols]
  df_git2net <- df_git2net[cols]
  df_grimoire <- df_grimoire[cols]
  df_kaiaulu <- df_kaiaulu[cols]
  
  # Unify names to make developers comparable.
  # We use the author name, which is captured by all tools.
  df_codeface$developer <- sub("\\s*<.*", "", df_codeface$developer)
  df_git2net$developer <- sub("\\s*<.*", "", df_git2net$developer)
  df_grimoire$developer <- sub("\\s*<.*", "", df_grimoire$developer)
  df_kaiaulu$developer <- sub("\\s*<.*", "", df_kaiaulu$developer)
  
  # Rename value columns.
  tools <- c("codeface", "git2net", "grimoire", "kaiaulu")
  df_list <- list(df_codeface, df_git2net, df_grimoire, df_kaiaulu)
  for (i in 1:4) {
    colnames(df_list[[i]])[match(c("loc_count_class", 
                                  "commit_count_class",
                                  "degree_class",
                                  "eigenvector_class",
                                  "hierarchy_class"), 
                                names(df_list[[i]]))] <- c(paste0("loc_count_class_", tools[i]),
                                                          paste0("commit_count_class_", tools[i]),
                                                          paste0("degree_class_", tools[i]),
                                                          paste0("eigenvector_class_", tools[i]),
                                                          paste0("hierarchy_class_", tools[i]))
  }
  
  # Get common set of developers that was identified and classified by all tools.
  df <- reduce(df_list, inner_join, by = c("range_id", "developer"))
  
  if (project_range != "") {
    common_file_path <- file.path(project, str_c("common_developers_", project_range, ".csv"))
  } else {
    common_file_path <- file.path(project, str_c("common_developers.csv"))
  }
  write.csv(df, common_file_path)
  
  # Calculate Cohen's Kappa for to measure the agreement between tools per metric.
  metrics <- c("loc_count_class", "commit_count_class", "degree_class",
               "eigenvector_class", "hierarchy_class")
  cols <- colnames(df)[-c(1, 2)]
  kappa_dat <- calculate_kappa(df, cols, metrics, tools)
  kappa_dat$param <- sub("_.*", "", kappa_dat$metric_1)
  kappa_dat$metric_1 <- sub(".*_(.*)$", "\\1", kappa_dat$metric_1)
  kappa_dat$metric_2 <- sub(".*_(.*)$", "\\1", kappa_dat$metric_2)

  # Convert the data frame to a wide format with a specific agreement column
  # for each tool.
  kappa_dat_wide <- kappa_dat %>% pivot_wider(names_from = "param",
                                              values_from = "kappa")
  kappa_dat_wide <- kappa_dat_wide[order(desc(kappa_dat_wide$metric_1)),]
  kappa_dat_wide$metric_1 <- factor(kappa_dat_wide$metric_1, levels = rev(tools))
  kappa_dat_wide$metric_2 <- factor(kappa_dat_wide$metric_2, levels = rev(tools))

  # Compute the triangle coordinates for the upper and the lower left and right
  # parts.
  triangle_top <- make_polygons(kappa_dat_wide$metric_1,
                                 kappa_dat_wide$metric_2, point = "top")
  triangle_top <- triangle_top %>% select(xtop = x, ytop = y)

  triangle_right <- make_polygons(kappa_dat_wide$metric_1,
                                   kappa_dat_wide$metric_2, point = "right")
  triangle_right <- triangle_right %>% select(xright = x, yright = y)

  triangle_bottom <- make_polygons(kappa_dat_wide$metric_1,
                                    kappa_dat_wide$metric_2, point = "bottom")
  triangle_bottom <- triangle_bottom %>% select(xbottom = x, ybottom = y)

  triangle_left <- make_polygons(kappa_dat_wide$metric_1,
                                  kappa_dat_wide$metric_2, point = "left")
  triangle_left <- triangle_left %>% select(xleft = x, yleft = y)
  triangle_center <- make_polygons(kappa_dat_wide$metric_1,
                                  kappa_dat_wide$metric_2, point = "center")
  triangle_center <- triangle_center %>% select(xcenter = x, ycenter = y)

  # A triangle is defined by three points (x,y). Thus, we must associate each
  # correlation value with the corresponding three points.
  point_data <- map_df(1:nrow(kappa_dat_wide), function(i) kappa_dat_wide[rep(i, 3), ])
  triangle_data <- bind_cols(point_data, triangle_top, triangle_right,
                             triangle_bottom, triangle_left, triangle_center)

  # Calculate the label coordinates for each triangle.
  label_top <- make_label_positions(kappa_dat_wide$metric_1,
                                    kappa_dat_wide$metric_2, point = "top")
  label_top <- label_top %>% select(xtop = x, ytop = y)

  label_right <- make_label_positions(kappa_dat_wide$metric_1,
                                      kappa_dat_wide$metric_2, point = "right")
  label_right <- label_right %>% select(xright = x, yright = y)

  label_bottom <- make_label_positions(kappa_dat_wide$metric_1,
                                       kappa_dat_wide$metric_2, point = "bottom")
  label_bottom <- label_bottom %>% select(xbottom = x, ybottom = y)

  label_left <- make_label_positions(kappa_dat_wide$metric_1,
                                     kappa_dat_wide$metric_2, point = "left")
  label_left <- label_left %>% select(xleft = x, yleft = y)

  label_center <- make_label_positions(kappa_dat_wide$metric_1,
                                     kappa_dat_wide$metric_2, point = "center")
  label_center <- label_center %>% select(xcenter = x, ycenter = y)

  label_data <- bind_cols(kappa_dat_wide, label_top, label_right, label_bottom,
                          label_left, label_center)

  # Configure the actual plot.
  if (y_axis) {
    y_axis_el <- element_text(size = SMALL.SIZE*1.5)
  } else {
    y_axis_el <- element_blank()
  }
  
  # Format tool names.
  replacements <- c("codeface" = "Codeface", 
                    "grimoire" = "GrimoireLab",
                    "kaiaulu" = "Kaiaulu")
  triangle_data$metric_1 <- stringr::str_replace_all(triangle_data$metric_1, replacements)
  triangle_data$metric_2 <- stringr::str_replace_all(triangle_data$metric_2, replacements)
  label_data$metric_1 <- stringr::str_replace_all(label_data$metric_1, replacements)
  label_data$metric_2 <- stringr::str_replace_all(label_data$metric_2, replacements)
  tools <- c("Codeface", "git2net", "GrimoireLab", "Kaiaulu")

  # Tile borders
  xtiles <- vector()
  ytiles <- vector()
  for (i in 2:length(tools)) {
    xtiles <- c(xtiles, tools[i:length(tools)])
    ytiles <- c(ytiles, rep(tools[i-1], length(tools)-i+1))
  }
  xtiles <- rep(xtiles, 3)
  ytiles <- rep(ytiles, 3)

  # Each tile shows:
  # top: LOC
  # right: commits
  # bottom: degree
  # left: eigenvector
  # center: hierarchy
  p <- ggplot(triangle_data) +
    labs(title=cap) +
    xlim(tools[2:length(tools)]) + # Save space by shifting duplicate features
    ylim(tools[1:(length(tools)-1)]) +
    geom_polygon(aes(x = xtop, y = ytop, fill = loc,
                     group = interaction(metric_1, metric_2)),
                 lwd=0.05, color = COLOURS.LIST[10]) +
    scale_fill_gradient2(low = COLOURS.LIST[3],  mid = "#FFFFFF",
                         high = COLOURS.LIST[2], limits=c(-1, 1), guide="none") +
    ggnewscale::new_scale_fill() +
    geom_polygon(aes(x = xright, y = yright, fill = commit,
                     group = interaction(metric_1, metric_2)),
                 lwd=0.05, color = COLOURS.LIST[10]) +
    scale_fill_gradient2(low = COLOURS.LIST[3],  mid = "#FFFFFF",
                         high = COLOURS.LIST[4], limits=c(-1, 1), guide="none") +
    ggnewscale::new_scale_fill() +
    geom_polygon(aes(x = xbottom, y = ybottom, fill = degree,
                     group = interaction(metric_1, metric_2)),
                 lwd=0.05, color = COLOURS.LIST[10]) +
    scale_fill_gradient2(low = COLOURS.LIST[3], mid = "#FFFFFF",
                         high = COLOURS.LIST[8], limits=c(-1, 1), guide="none") +
    ggnewscale::new_scale_fill() +
    geom_polygon(aes(x = xleft, y = yleft, fill = eigenvector,
                     group = interaction(metric_1, metric_2)),
                 lwd=0.05, color = COLOURS.LIST[10]) +
    scale_fill_gradient2(low = COLOURS.LIST[3],  mid = "#FFFFFF",
                         high = COLOURS.LIST[9], limits=c(-1, 1), guide="none") +
    ggnewscale::new_scale_fill() +
    geom_tile(aes(x = xcenter, y = ycenter, fill = hierarchy,
                     group = interaction(metric_1, metric_2)),
                 lwd=0.05, color = COLOURS.LIST[1],
                 width = 0.35, height = 0.35) +
    scale_fill_gradient2(low = COLOURS.LIST[3],  mid = "#FFFFFF",
                         high = COLOURS.LIST[5], limits=c(-1, 1), guide="none") +
    ggnewscale::new_scale_fill() +
    geom_tile(aes(x = xtiles, y = ytiles), fill="transparent", colour="black",
              size=1, lwd=LINE.SIZE-0.1) +
    geom_text(data = label_data, aes(x = xtop, y=ytop, label = round(loc, 2)),
              size = TABLE.FONT.SIZE*1.5) +
    geom_text(data = label_data, aes(x = xright, y=yright, label = round(commit, 2)),
              size = TABLE.FONT.SIZE*1.5) +
    geom_text(data = label_data, aes(x = xbottom, y=ybottom, label = round(degree, 2)),
              size = TABLE.FONT.SIZE*1.5) +
    geom_text(data = label_data, aes(x = xleft, y=yleft, label = round(eigenvector, 2)),
              size = TABLE.FONT.SIZE*1.5) +
    geom_text(data = label_data, aes(x = xcenter, y=ycenter, label = round(hierarchy, 2)),
              size = TABLE.FONT.SIZE*1.5) + # TABLE.FONT.SIZE-0.5
    scale_fill_gradient2(low = COLOURS.LIST[3], mid = "#FFFFFF",
                         high = COLOURS.LIST[9], limits=c(-1, 1), guide="none") +
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

# Plot the metrics agreement for all tools.
i <- 1
for (project in projects) {
  if (!dir.exists(path.join(opt$res_path, "codeface", project))) {
    next  # Skip if the project was not analysed.
  }

  # Read developer classifications from all tools.
  df_codeface <- data.frame(read_csv(path.join(opt$res_path, "codeface", project,
                                               "developer_classification.csv")))
  df_git2net <- data.frame(read_csv(path.join(opt$res_path, "git2net", project,
                                              "developer_classification.csv")))
  df_grimoire <- data.frame(read_csv(path.join(opt$res_path, "grimoire", project,
                                               "developer_classification.csv")))
  df_kaiaulu <- data.frame(read_csv(path.join(opt$res_path, "kaiaulu", project,
                                              "developer_classification.csv")))
  
  # Plot the pairwise agreement for each metric and tool over the project lifetime.
  p <- agreement_plot(df_codeface, df_git2net, df_grimoire, df_kaiaulu,
                      y_axis=TRUE, project, "", cap=captions[i])
  
  # Save the plot.
  plot_save_path <- str_c("tool_agreement.pdf")
  if (!dir.exists(project)) {
    dir.create(project, recursive = TRUE)
  }
  ggsave(file.path(project, plot_save_path), plot = p,
         width = 0.61*TEXTWIDTH, height = 0.62*TEXTWIDTH, units = "in")
  plot(p)
  
  if (opt$tikz) {
    plot_save_path <- str_c(project, "_tool_agreement", ".tex")
    tikz(file.path("img-tikz", plot_save_path),
         width = 0.61*TEXTWIDTH, height = 0.62*TEXTWIDTH)
    print(p)
    dev.off()
  }
  
  # Create 1-year agreement plots.
  for (j in seq(from=max(df_codeface$range_id), to=1, by=-4)){
    # Make batches of 4 time windows each.
    df_codeface_part <- df_codeface[((df_codeface$range_id<=j) & (df_codeface$range_id>=j-3)),]
    df_git2net_part <- df_git2net[((df_git2net$range_id<=j) & (df_git2net$range_id>=j-3)),]
    df_grimoire_part <- df_grimoire[((df_grimoire$range_id<=j) & (df_grimoire$range_id>=j-3)),]
    df_kaiaulu_part <- df_kaiaulu[((df_kaiaulu$range_id<=j) & (df_kaiaulu$range_id>=j-3)),]
    
    # Plot the pairwise agreement for each metric and tool.
    project_range <- str_c(j, "-", j-3)
    p <- agreement_plot(df_codeface_part, df_git2net_part, df_grimoire_part,
                        df_kaiaulu_part, project, project_range, y_axis=TRUE, cap=captions[i])
    
    # Save the plot.
    plot_save_path <- str_c("tool_agreement_", j, "-", j-3, ".pdf")
    ggsave(file.path(project, plot_save_path), plot = p,
           width = 0.61*TEXTWIDTH, height = 0.62*TEXTWIDTH, units = "in") # width 0.5, height 0.55
    plot(p)
    
    if (opt$tikz) {
      plot_save_path <- str_c(project, "_tool_agreement_", j, "-", j-3, ".tex")
      tikz(file.path("img-tikz", plot_save_path),
           width = 0.61*TEXTWIDTH, height = 0.62*TEXTWIDTH)
      print(p)
      dev.off()
    }
  }
  i <- i+1
}
