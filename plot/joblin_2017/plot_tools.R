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
library(kableExtra)
library(knitr)
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

#' Evaluates Joblin result stability (H_cR) across tool pairs using bootstrap CIs.
#'
#' For each metric, project, time window, and tool pair, computes Cohen's kappa
#' between the two tools' developer classifications on the set of developers
#' identified by all four tools, and a 95% bootstrap CI (B resamples of
#' developers).
#'
#' @param res_path path to the results directory (per-tool subfolders).
#' @param projects project folder names.
#' @param captions display names, parallel to projects.
#' @param metrics classification columns to compare.
#' @param delta substantial-agreement threshold.
#' @param B bootstrap resamples.
#' @param save_path LaTeX table output path (worst case per metric).
#' @param csv_path CSV output path (all tuples, for verification).
#'
result_stability_joblin <- function(res_path, projects, captions,
                                    metrics = c("loc_count_class", "commit_count_class",
                                                "degree_class", "eigenvector_class",
                                                "hierarchy_class"),
                                    delta = 0.61, B = 10000,
                                    save_path = NULL, csv_path = NULL) {
  set.seed(42)
  tools <- c("codeface", "git2net", "grimoire", "kaiaulu")
  tool_disp <- c(codeface = "Codeface", git2net = "git2net",
                 grimoire = "GrimoireLab", kaiaulu = "Kaiaulu")
  metric_disp <- c(loc_count_class = "LOC", commit_count_class = "Commits",
                   degree_class = "Node degree", eigenvector_class = "Eigenvector",
                   hierarchy_class = "Hierarchy")
  
  # Helper function for pairwise Cohen's kappa calculation.
  kappa_pair <- function(c1, c2) {
    if (length(c1) == 0) return(0)
    if (all(c1 == c2) && length(unique(c1)) == 1) return(1)
    tryCatch(psych::cohen.kappa(cbind(c1, c2))$kappa,
             error = function(e) NA_real_, warning = function(w) NA_real_)
  }
  
  rows <- list()
  for (pi in seq_along(projects)) {
    project <- projects[pi]
    print(paste0("Calculating bootstrap CIs for project ", project))
    if (!dir.exists(file.path(res_path, "codeface", project))) next
    
    # Read and unify the four tools' classifications.
    dfs <- lapply(tools, function(t) {
      d <- data.frame(read_csv(file.path(res_path, t, project,
                                         "developer_classification.csv"),
                               show_col_types = FALSE))
      d$developer <- sub("\\s*<.*", "", d$developer)
      d <- d[, c("range_id", "developer", metrics)]
      # tag metric columns with the tool
      names(d)[names(d) %in% metrics] <- paste0(metrics, "_", t)
      d
    })
    names(dfs) <- tools
    
    # Get commonly identified developers.
    common <- Reduce(function(a, b) inner_join(a, b, by = c("range_id", "developer")), dfs)
    
    # Calculate kappa bootstrap CIs.
    windows <- sort(unique(common$range_id))
    print(str(windows))
    for (w in windows) {
      print(str(w))
      cw <- common[common$range_id == w, ]
      if (nrow(cw) == 0) next
      for (m in metrics) {
        for (i in 1:(length(tools) - 1)) for (j in (i + 1):length(tools)) {
          ta <- tools[i]; tb <- tools[j]
          v1 <- cw[[paste0(m, "_", ta)]]
          v2 <- cw[[paste0(m, "_", tb)]]
          n <- length(v1)
          
          k_point <- kappa_pair(v1, v2)
          if (n >= 2) {
            boot <- replicate(B, {
              idx <- sample.int(n, n, replace = TRUE)
              kappa_pair(v1[idx], v2[idx])
            })
            ci <- quantile(boot, c(0.025, 0.975), names = FALSE, na.rm = TRUE)
          } else {
            ci <- c(NA_real_, NA_real_)
          }
          
          rows[[length(rows) + 1]] <- data.frame(
            metric = metric_disp[[m]], project = captions[pi], window = w,
            tool_a = tool_disp[[ta]], tool_b = tool_disp[[tb]],
            n = n, kappa = round(k_point, 4),
            lo = round(ci[1], 4), hi = round(ci[2], 4),
            row.names = NULL, stringsAsFactors = FALSE
          )
        }
      }
    }
  }
  res <- do.call(rbind, rows)
  if (!is.null(csv_path)) write_csv(res, csv_path)
}

#' Aggregates Joblin table for the paper.
#'
#' We present the fraction of windows fulfilling the substantial agreement
#' lower bound for different jointly identified developer thresholds (as low 
#' counts lead to degenerate kappa values).
#'
#' @param res the output result table with individual values.
#' @param thresholds the thresholds for the minimum required developers.
#' @param delta the agreement threshold, 0.61 indicating substantial agreement.
#' @param save_path LaTeX table output path.
#'
build_result_stability_table <- function(res,
                                         thresholds = c(2, 10, 20, 40),
                                         delta = 0.61,
                                         save_path = NULL) {
  
  count_metrics   <- c("LOC", "Commits")
  network_metrics <- c("Node degree", "Eigenvector", "Hierarchy")
  metric_order    <- c(count_metrics, network_metrics)
  
  # Per metric, per threshold: fraction of assessable windows whose LOWER CI
  # bound reaches substantial agreement (lo >= delta). NA lo (n = 1) excluded.
  frac <- function(m, thr) {
    sub <- res[res$metric == m & !is.na(res$lo) & res$n >= thr, ]
    if (nrow(sub) == 0) return(NA_real_)
    mean(sub$lo >= delta)
  }
  
  cell <- function(m, thr) {
    f <- frac(m, thr)
    if (is.na(f)) "--" else sprintf("%.2f", f)
  }
  
  # Build LaTeX body: grouped by metric type with a header row + midrule.
  hdr <- paste0("\\textbf{Metric} & ",
                paste(sprintf("\\textbf{$n_{\\text{dev}} \\geq %d$}", thresholds),
                      collapse = " & "), "\\\\")
  metric_row <- function(m) paste0(m, " & ",
                                   paste(vapply(thresholds, function(t) cell(m, t), character(1)),
                                         collapse = " & "), "\\\\")
  
  body <- c(
    "\\multicolumn{" , NULL) # placeholder, built below
  ncol <- length(thresholds) + 1
  lines <- c(
    "{\\scriptsize",
    sprintf("\\begin{tabular}{l%s}", paste(rep("c", length(thresholds)), collapse = "")),
    "\\toprule",
    hdr,
    "\\midrule",
    sprintf("\\multicolumn{%d}{l}{\\emph{Count-based}}\\\\", ncol),
    vapply(count_metrics, metric_row, character(1)),
    "\\midrule",
    sprintf("\\multicolumn{%d}{l}{\\emph{Network-based}}\\\\", ncol),
    vapply(network_metrics, metric_row, character(1)),
    "\\bottomrule",
    "\\end{tabular}",
    "}"
  )
  
  if (!is.null(save_path)) writeLines(lines, save_path)
}

#' Evaluates Joblin conclusion stability (H_cC).
#'
#' For each tool, computes the within-tool pairwise Cohen's kappa between every
#' count-based and network-based metric, per project and time window, on that
#' tool's own developers. A tool supports the verdict (V_t = 1) if kappa exceeds
#' random chance for the majority of (m_c, m_n, p, w) combinations.
#' Conclusions are stable if all tools yield V_t = 1.
#'
#' @param res_path path to the results directory (per-tool subfolders).
#' @param projects project folder names.
#' @param captions display names, parallel to projects.
#' @param count_metrics count-based classification columns.
#' @param network_metrics network-based classification columns.
#' @param delta_c chance-agreement threshold (0).
#' @param save_path LaTeX table output path (per-tool verdict summary).
#' @param csv_path CSV output path (all combinations, for verification).
#'
conclusion_stability_joblin <- function(res_path, projects, captions,
                                        count_metrics = c("loc_count_class",
                                                          "commit_count_class"),
                                        network_metrics = c("degree_class",
                                                            "eigenvector_class",
                                                            "hierarchy_class"),
                                        delta_c = 0,
                                        save_path = NULL, csv_path = NULL) {
  tools <- c("codeface", "git2net", "grimoire", "kaiaulu")
  tool_disp <- c(codeface = "Codeface", git2net = "git2net",
                 grimoire = "GrimoireLab", kaiaulu = "Kaiaulu")
  all_metrics <- c(count_metrics, network_metrics)
  
  # Point Cohen's kappa between two class vectors (within one tool).
  point_kappa <- function(c1, c2) {
    if (length(c1) < 2) return(NA_real_)
    if (all(c1 == c2) && length(unique(c1)) == 1) return(1)
    tryCatch(psych::cohen.kappa(cbind(c1, c2))$kappa,
             error = function(e) NA_real_, warning = function(w) NA_real_)
  }
  
  rows <- list()
  for (pi in seq_along(projects)) {
    project <- projects[pi]
    if (!dir.exists(file.path(res_path, "codeface", project))) next
    
    for (t in tools) {
      f <- file.path(res_path, t, project, "developer_classification.csv")
      if (!file.exists(f)) next
      d <- data.frame(read_csv(f, show_col_types = FALSE))
      
      for (w in sort(unique(d$range_id))) {
        dw <- d[d$range_id == w, ]
        if (nrow(dw) < 2) next
        for (mc in count_metrics) for (mn in network_metrics) {
          k <- point_kappa(dw[[mc]], dw[[mn]])
          rows[[length(rows) + 1]] <- data.frame(
            tool = tool_disp[[t]], project = captions[pi], window = w,
            metric_count = mc, metric_net = mn,
            n = nrow(dw), kappa = round(k, 4),
            row.names = NULL, stringsAsFactors = FALSE
          )
        }
      }
    }
  }
  res <- do.call(rbind, rows)
  if (!is.null(csv_path)) write_csv(res, csv_path)
  
  # Per-tool verdict: majority of assessable combinations with kappa > delta_c.
  verdict <- do.call(rbind, lapply(unique(res$tool), function(tt) {
    sub <- res[res$tool == tt & !is.na(res$kappa), ]
    k_total <- nrow(sub)                      # assessed combinations
    k_above <- sum(sub$kappa > delta_c)       # exceeding chance
    majority <- ceiling(k_total / 2)
    data.frame(tool = tt, assessed = k_total, above_chance = k_above,
               majority = majority, V_t = as.integer(k_above >= majority),
               row.names = NULL, stringsAsFactors = FALSE)
  }))
  
  # Save LaTeX table (tools as columns, V_t as bottom row).
  if (!is.null(save_path)) {
    tools_disp <- str_c("\\textbf{", verdict$tool, "}")
    
    
    tbl <- data.frame(
      Quantity = c("$k$",
                   "$\\lceil k/2 \\rceil$",
                   "$\\kappa > \\delta_{\\kappa,\\text{C}}$",
                   "$(\\kappa > \\delta_{\\kappa,\\text{C}})/k$",
                   "$V_t$"),
      check.names = FALSE, stringsAsFactors = FALSE
    )
    for (i in seq_along(tools_disp)) {
      colname <- tools_disp[i]
      tbl[[colname]] <- c(
        formatC(verdict$assessed[i], format = "d", big.mark = ","),
        formatC(verdict$majority[i], format = "d", big.mark = ","),
        formatC(verdict$above_chance[i], format = "d", big.mark = ","),
        formatC(verdict$above_chance[i] / verdict$assessed[i], format = "f", digits = 2),
        formatC(verdict$V_t[i], format = "d", big.mark = ",")
      )
    }
    colnames(tbl)[1] <- ""
    
    tabular <- capture.output(
      kable(tbl, format = "latex", booktabs = TRUE, linesep = "",
            escape = FALSE, align = c("l", rep("c", length(tools_disp)))) %>%
        row_spec(4, hline_after = TRUE))
    latex_code <- c("{\\scriptsize", tabular, "}")
    writeLines(latex_code, save_path)
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

# Evaluate result stability.
result_stability_joblin(opt$res_path, projects, captions,
                        save_path = "joblin_result_stability.tex",
                        csv_path  = "joblin_result_stability.csv")

# For cross-check.
res <- read_csv("joblin_result_stability.csv")
res %>% dplyr::filter(!is.na(hi)) %>%
  mutate(degenerate = hi <= 0.001) %>%
  group_by(degenerate) %>%
  summarise(median_n = median(n), max_n = max(n), count = n())

build_result_stability_table(res,
                             thresholds = c(2, 10, 20, 60),
                             save_path  = "joblin_result_stability.tex")

conclusion_stability_joblin(opt$res_path, projects, captions,
                            save_path = "joblin_conclusion_stability.tex",
                            csv_path  = "joblin_conclusion_stability.csv")