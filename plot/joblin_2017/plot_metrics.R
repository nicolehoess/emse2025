# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

# Replicates the plots from Joblin et al., 2017 and compares classifications 
# agreement across metrics for each individual tool data set.

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


#' Formats metrics names in the given data frame.
#'
#' @param df the data frame with original names.
#' @return the data frame with formatted names.
#'
map_names <- function(df) {
  column_map <- data.frame("old" = c("loc_count_class",
                                     "commit_count_class",
                                     "degree_class",
                                     "eigenvector_class",
                                     "hierarchy_class"),
                           "new" =  c("LOC",
                                      "Commits",
                                      "Degree",
                                      "EigenCent",
                                      "Hierarchy")
  )
  names(df) <- column_map$new[match(names(df), column_map$old)]
  return(df)
}


#' Calculates Cohen's kappa for two metrics.
#'
#' @param df the data frame with original names.
#' @param classes_1 classifications according to first metric.
#' @param classes_2 classifications according to second metric.
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

#' Calculates pairwise Cohen's kappa for all metrics in the data frame.
#'
#' @param df the data frame with classifications.
#' @param cols the metrics columns to compare pairwise.
#' @return pairwise Cohen's kappa.
#'
calculate_kappa <- function(df, cols) {
  df_kappa <- data.frame()
  for (metric_1 in cols) {
    for (metric_2 in cols) {
      row <- data.frame(metric_1=NA, metric_2=NA, kappa=NA)
      row$metric_1 <- metric_1
      row$metric_2 <- metric_2
      row$kappa <- compare_classification(df, metric_1, metric_2)
      df_kappa <- rbind(df_kappa, row)
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

#' Creates the triangle coordinates for the metrics comparison plot.
#'
#' @param x the original x coordinate.
#' @param y the original y coordinate.
#' @param point the triangle position in each tile.
#' @return the triangle coordinates.
#'
make_triangles <- function(x, y, point) {
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
  }
  return(data.frame(x = unlist(newx), y = unlist(newy)))
}

#' Creates the triangle label coordinates for the metrics comparison plot.
#'
#' @param x the original x coordinate.
#' @param y the original y coordinate.
#' @param point the corresponding triangle position in each tile.
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
      c(x-0.28)
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
      c(x+0.28)
    }, simplify = FALSE)
    newy <- sapply(y, function(y) {
      c(y)
    }, simplify = FALSE)
  }
  data.frame(x = unlist(newx), y = unlist(newy))
}

#' Creates the metrics agreement plot showing pairwise Cohen's kappa for all
#' metrics within the respective tool data set.
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
                           y_axis=FALSE, cap="") {
  # Format data frames to ensure that metrics are in the same order as in the
  # original plot.
  cols <- c("Hierarchy",  "EigenCent", "Degree", "LOC", "Commits")
  df_codeface <- map_names(df_codeface)
  df_codeface <- df_codeface[cols]
  df_git2net <- map_names(df_git2net)
  df_git2net <- df_git2net[cols]
  df_grimoire <- map_names(df_grimoire)
  df_grimoire <- df_grimoire[cols]
  df_kaiaulu <- map_names(df_kaiaulu)
  df_kaiaulu <- df_kaiaulu[cols]

  # Calculate Cohen's Kappa for each tool's classifications.
  df_kappa_codeface <- calculate_kappa(df_codeface, cols)
  df_kappa_git2net <- calculate_kappa(df_git2net, cols)
  df_kappa_grimoire <- calculate_kappa(df_grimoire, cols)
  df_kappa_kaiaulu <- calculate_kappa(df_kaiaulu, cols)

  # Merge the individual agreement data frames.
  df_kappa_codeface <- df_kappa_codeface %>%
    mutate(param = "codeface")
  df_kappa_git2net <- df_kappa_git2net %>%
    mutate(param = "git2net")
  df_kappa_grimoire <- df_kappa_grimoire %>%
    mutate(param = "grimoire")
  df_kappa_kaiaulu <- df_kappa_kaiaulu %>%
    mutate(param = "kaiaulu")
  kappa_dat <- rbind(df_kappa_codeface, df_kappa_git2net,
                     df_kappa_grimoire, df_kappa_kaiaulu)

  # Convert the data frame to a wide format with a specific agreement column
  # for each tool.
  kappa_dat_wide <- kappa_dat %>% pivot_wider(names_from = "param",
                                      values_from = "kappa")
  kappa_dat_wide <- kappa_dat_wide[order(desc(kappa_dat_wide$metric_1)),]
  kappa_dat_wide$metric_1 <- factor(kappa_dat_wide$metric_1, levels = rev(cols))
  kappa_dat_wide$metric_2 <- factor(kappa_dat_wide$metric_2, levels = rev(cols))

  # Compute the triangle coordinates for the upper and the lower left and right
  # parts.
  triangle_top <- make_triangles(kappa_dat_wide$metric_1,
                                 kappa_dat_wide$metric_2, point = "top")
  triangle_top <- triangle_top %>% select(xtop = x, ytop = y)

  triangle_right <- make_triangles(kappa_dat_wide$metric_1,
                                   kappa_dat_wide$metric_2, point = "right")
  triangle_right <- triangle_right %>% select(xright = x, yright = y)

  triangle_bottom <- make_triangles(kappa_dat_wide$metric_1,
                                    kappa_dat_wide$metric_2, point = "bottom")
  triangle_bottom <- triangle_bottom %>% select(xbottom = x, ybottom = y)

  triangle_left <- make_triangles(kappa_dat_wide$metric_1,
                                  kappa_dat_wide$metric_2, point = "left")
  triangle_left <- triangle_left %>% select(xleft = x, yleft = y)

  # A triangle is defined by three points (x,y). Thus, we must associate each
  # correlation value with the corresponding three points.
  point_data <- map_df(1:nrow(kappa_dat_wide), function(i) kappa_dat_wide[rep(i, 3), ])
  triangle_data <- bind_cols(point_data, triangle_top, triangle_right,
                             triangle_bottom, triangle_left)

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

  label_data <- bind_cols(kappa_dat_wide, label_top, label_right, label_bottom,
                          label_left)

  # Configure the actual plot.
  if (y_axis) {
    y_axis_el <- element_text(size = SMALL.SIZE*1.5)
  } else {
    y_axis_el <- element_blank()
  }
  xtiles <- vector()
  ytiles <- vector()
  for (i in 2:length(cols)) {
    xtiles <- c(xtiles, cols[i:length(cols)])
    ytiles <- c(ytiles, rep(cols[i-1], length(cols)-i+1))
  }
  xtiles <- rep(xtiles, 3)
  ytiles <- rep(ytiles, 3)

  # Each tile shows:
  # top: codeface
  # right: git2net
  # bottom: grimoire
  # left: kaiaulu
  p <- ggplot(triangle_data) +
    labs(title=cap) +
    xlim(cols[2:length(cols)]) + # Save space by shifting duplicate features
    ylim(cols[1:(length(cols)-1)]) +
    geom_polygon(aes(x = xtop, y = ytop, fill = codeface,
                     group = interaction(metric_1, metric_2)),
                 lwd=0.05, color = COLOURS.LIST[10]) +
    scale_fill_gradient2(low = COLOURS.LIST[3],  mid = "#FFFFFF",
                         high = COLOURS.LIST[2], limits=c(-1, 1), guide="none") +
    ggnewscale::new_scale_fill() +
    geom_polygon(aes(x = xright, y = yright, fill = git2net,
                     group = interaction(metric_1, metric_2)),
                 lwd=0.05, color = COLOURS.LIST[10]) +
    scale_fill_gradient2(low = COLOURS.LIST[3],  mid = "#FFFFFF",
                         high = COLOURS.LIST[4], limits=c(-1, 1), guide="none") +
    ggnewscale::new_scale_fill() +
    geom_polygon(aes(x = xbottom, y = ybottom, fill = grimoire,
                     group = interaction(metric_1, metric_2)),
                 lwd=0.05, color = COLOURS.LIST[10]) +
    scale_fill_gradient2(low = COLOURS.LIST[3], mid = "#FFFFFF",
                         high = COLOURS.LIST[8], limits=c(-1, 1), guide="none") +
    ggnewscale::new_scale_fill() +
    geom_polygon(aes(x = xleft, y = yleft, fill = kaiaulu,
                     group = interaction(metric_1, metric_2)),
                 lwd=0.05, color = COLOURS.LIST[9]) +
    geom_tile(aes(x = xtiles, y = ytiles), fill="transparent", colour="black",
              size=1, lwd=LINE.SIZE-0.1) +
    geom_text(data = label_data, aes(x = xtop, y=ytop, label = round(codeface, 2)),
              size = TABLE.FONT.SIZE*1.5) +
    geom_text(data = label_data, aes(x = xright, y=yright, label = round(git2net, 2)),
              size = TABLE.FONT.SIZE*1.5) +
    geom_text(data = label_data, aes(x = xbottom, y=ybottom, label = round(grimoire, 2)),
              size = TABLE.FONT.SIZE*1.5) +
    geom_text(data = label_data, aes(x = xleft, y=yleft, label = round(kaiaulu, 2)),
              size = TABLE.FONT.SIZE*1.5) + # TABLE.FONT.SIZE-0.5
    scale_fill_gradient2(low = COLOURS.LIST[3], mid = "#FFFFFF",
                         high = COLOURS.LIST[9], limits=c(-1, 1), guide="none") +
    coord_equal() +
    theme_paper_base() +
    theme(plot.title=element_text(size=SMALL.SIZE*1.5, hjust = 0.5),
          axis.title.x=element_blank(), axis.title.y=element_blank(),
          axis.text = element_text(size = SMALL.SIZE*1.5), # tick font size
          axis.text.x = element_text(size = SMALL.SIZE*1.5,  # x-axis tick font size
                                     angle=45, hjust=1, vjust=1), # x-axis tick angle
          axis.text.y = y_axis_el  # x-axis tick font size
    )

  return(p)
}

#' Creates the role stability plot.
#'
#' @param df_codeface the network metrics when using Codeface.
#' @param df_git2net the network metrics when using git2net.
#' @param df_grimoire the network metrics when using GrimoireLab.
#' @param df_kaiaulu the network metrics when using Kaiaulu.
#' @param ranges the time window labels.
#' @param project the name of the subject project.
#' @return the role stability facet plot.
#'
stability_plot <- function(df_codeface, df_git2net, df_grimoire, df_kaiaulu, ranges, project) {
  # Format data frames to ensure that metrics are in the same order as in the
  # original plot.
  cols <- c("range_id", "clustering_coefficient", "degree", "hierarchy_class")
  df_codeface <- df_codeface[cols]
  df_codeface <- df_codeface %>% mutate(tool="Codeface")
  df_git2net <- df_git2net[cols]
  df_git2net <- df_git2net %>% mutate(tool="git2net")
  df_grimoire <- df_grimoire[cols]
  df_grimoire <- df_grimoire %>% mutate(tool="GrimoireLab")
  df_kaiaulu <- df_kaiaulu[cols]
  df_kaiaulu <- df_kaiaulu %>% mutate(tool="Kaiaulu")
  df <- do.call("rbind", list(df_codeface, df_git2net, df_grimoire, df_kaiaulu))
  df$tool <- factor(df$tool, levels = unique(df$tool)[order(tolower(unique(df$tool)))])


  # The original study plot ignored all data points where either clustering
  # coefficient or node degree were missing or zero.
  df <- df[!is.na(df$clustering_coefficient), ]
  df <- df[!(df$clustering_coefficient == 0), ]
  df <- df[!is.na(df$degree), ]
  df <- df[!(df$degree == 0), ]

  legend_pos <- "none"
  if (project == "qemu") {
    legend_pos <- "top"
  }

  if(nrow(df) > 0) {
    p <- ggplot(df, aes(x = degree, y = clustering_coefficient)) +
         labs(x = "Node Degree", y = "Clustering Coefficient") +
         geom_smooth(aes(group=1), method = "lm", size=LINE.SIZE.THIN, fill=COLOURS.LIST[c(11)]) +
         geom_point(aes(color = hierarchy_class, shape = hierarchy_class)) +
         scale_x_log10() +
         scale_y_log10() +
         scale_shape_manual(values = c("peripheral" = 17, "core" = 16), labels=c("Core", "Peripheral")) +
         labs(color = "Role", shape="Role") +
         scale_colour_manual(values=COLOURS.LIST[c(8,2)], labels=c("Core", "Peripheral")) +
         facet_grid2(tool ~ ranges[range_id+1]) +
         #scale_x_continuous(breaks = pretty(df$Time, n = 5)) +
         theme_paper_base() +
         theme(axis.text = element_text(size = SMALL.SIZE*1.6),
               axis.text.x = element_text(size = SMALL.SIZE*1.6),
               axis.text.y = element_text(size = SMALL.SIZE*1.6),
               axis.title.x = element_text(size = SMALL.SIZE*1.6),
               axis.title.y = element_text(size = SMALL.SIZE*1.6),
               legend.text = element_text(size = SMALL.SIZE*1.5),
               legend.title = element_text(size = SMALL.SIZE*1.5),
               legend.key.size = unit(SYM.SIZE, "line"), # Legend symbol width
               legend.position = legend_pos,
               strip.text = element_text(size = SMALL.SIZE*1.5)) # Facet title size
    return(p)
  } else {
    return(NULL)
  }
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
                      y_axis=TRUE, cap=captions[i])

  # Save the plot.
  plot_save_path <- str_c("agreement.pdf")
  if (!dir.exists(project)) {
    dir.create(project, recursive = TRUE)
  }
  ggsave(file.path(project, plot_save_path), plot = p,
         width = 0.61*TEXTWIDTH, height = 0.62*TEXTWIDTH, units = "in")
  plot(p)

  if (opt$tikz) {
    plot_save_path <- str_c(project, "_agreement", ".tex")
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
    p <- agreement_plot(df_codeface_part, df_git2net_part, df_grimoire_part,
                        df_kaiaulu_part, y_axis=TRUE, cap=captions[i])

    # Save the plot.
    plot_save_path <- str_c("agreement_", j, "-", j-3, ".pdf")
    ggsave(file.path(project, plot_save_path), plot = p,
           width = 0.61*TEXTWIDTH, height = 0.62*TEXTWIDTH, units = "in") # width 0.5, height 0.55
    plot(p)

    if (opt$tikz) {
      plot_save_path <- str_c(project, "_agreement_", j, "-", j-3, ".tex")
      tikz(file.path("img-tikz", plot_save_path),
           width = 0.61*TEXTWIDTH, height = 0.62*TEXTWIDTH)
      print(p)
      dev.off()
    }
  }
  i <- i+1
}

# Plot the developer role stability.
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

  # Create 1-year stability plots (4 ranges).
  for (j in seq(from=max(df_codeface$range_id), to=1, by=-4)){
    # Make batches of 4 time windows each.
    df_codeface_part <- df_codeface[((df_codeface$range_id<=j) & (df_codeface$range_id>=j-3)),]
    df_git2net_part <- df_git2net[((df_git2net$range_id<=j) & (df_git2net$range_id>=j-3)),]
    df_grimoire_part <- df_grimoire[((df_grimoire$range_id<=j) & (df_grimoire$range_id>=j-3)),]
    df_kaiaulu_part <- df_kaiaulu[((df_kaiaulu$range_id<=j) & (df_kaiaulu$range_id>=j-3)),]

    conf <- yaml::read_yaml(path.join(opt$conf_path, str_c("joblin_", project, ".yml")))
    ranges <- conf[["ranges"]]
    ranges <- sub("\\s.*$", "", ranges)

    # Plot developer stability per 3-month window and tool.
    p <- stability_plot(df_codeface_part, df_git2net_part, df_grimoire_part,
                        df_kaiaulu_part, ranges, project)

    if (!is.null(p)) {
      # Save the plot.
      plot_save_path <- str_c("stability_", j, "-", j-3, ".pdf")
      ggsave(file.path(project, plot_save_path), plot = p,
             width = 1*TEXTWIDTH, height = 0.8*TEXTWIDTH, units = "in") # 0.8 width
      plot(p)

      if (opt$tikz) {
        plot_save_path <- str_c(project, "_stability_", j, "-", j-3, ".tex")
        tikz(file.path("img-tikz", plot_save_path),
             width = 1*TEXTWIDTH, height = 0.8*TEXTWIDTH)
        print(p)
        dev.off()
      }
    }
  }
  i <- i+1
}
