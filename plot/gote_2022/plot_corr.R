# Plots the productivity and collaboration metrics correlations.

# Split correlation matrix extended from:
# https://stackoverflow.com/questions/65887187/how-to-display-two-categorical-variables-on-one-tile-of-a-heatmap-triangle-til

# Functions adapted from Gote et al., 2022 (https://doi.org/10.5281/zenodo.5294015)

Sys.setenv(LANG = "en")
Sys.setenv(TZ = "UTC")

library(broom)
library(conflicted)
conflicts_prefer(dplyr::filter)
conflicts_prefer(dplyr::select)
library(dplyr)
library(ggplot2)
library(ggh4x) # devtools::install_github("teunbrand/ggh4x")
library(gridExtra)
library(kableExtra)
library(knitr)
library(patchwork)
library(purrr)
library(psych)
library(scales)
library(yaml)
library(texreg)
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
  make_option(c("--repro_path"), type="character", default=NULL,
              help="Path to the original study's reproduction data set",
              metavar="character"),
  make_option(c("--network_mode"), type="character", default=NULL,
                help="For git2net, the network format (edgelist or adjacency)",
                metavar="character"),
  make_option(c("--tikz"), type="logical", default=FALSE, action="store_true",
              help="Plot the tikz graph")
);

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);

#' Transforms productivity and collaboration metrics in the same way as the 
#' original study.
#'
#' @param df the original data frame.
#' @return the filtered data frame.
#'
log_transform <- function(df) {
  df$commits <- log(df$commits)
  df$function_delta <- log(df$function_delta)
  df$halstead_delta <- log(df$halstead_delta)
  df$team_size <- log(df$team_size)
  df$nodes <- log(df$nodes)
  df$indegree <- log(df$indegree)
  return(df)
}

#' Filters the productivity and collaboration metrics data frame in the same way
#' as the original study.
#'
#' @param df the original data frame.
#' @return the filtered data frame.
#'
filter_df_any <- function(df) {
  df <- df %>%
    filter_if(~is.numeric(.), all_vars(!is.na(.)))  %>%
    filter_if(~is.numeric(.), all_vars(!is.infinite(.)))  %>%
    filter_if(~is.numeric(.), all_vars(. != 0))
  print(df)
  return(df)
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
  x <- as.integer(as.factor((x)))#-1 # Why does it start at 2?
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
  x <- as.integer(as.factor(x)) #-1 # Why does it start at 2?
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

#' Creates the correlation heatmap plot showing Pearson's correlation across all
#' metrics within the respective tool data set.
#'
#' @param df_codeface the metrics data frame when using Codeface.
#' @param df_git2net the metrics data frame when using git2net.
#' @param df_grimoire the metrics data frame when using GrimoireLab.
#' @param df_kaiaulu the metrics data frame when using Kaiaulu.
#' @param cols the column names in each data frame.
#' @param y_axis whether to plot y-axis labels.
#' @return the correlation heatmap.
#'
corr_plot <- function(df_codeface, df_git2net, df_grimoire, df_kaiaulu, cols,
                      y_axis=FALSE) {
  # Rename columns.
  new_names = c('Commits (log)',
                'Functions (log)',
                'HalEff (log)',
                'TS (log)',
                'N (log)',
                'InD (log)',
                'FModR')
  colnames(df_codeface) <- new_names
  colnames(df_git2net) <- new_names
  colnames(df_grimoire) <- new_names
  colnames(df_kaiaulu) <- new_names
  cols <- new_names
  
  # Calculate Pearson correlation for each tool.
  corr_codeface <- cor(df_codeface, method="pearson")
  corr_git2net <- cor(df_git2net, method="pearson")
  corr_grimoire <- cor(df_grimoire, method="pearson")
  corr_kaiaulu <- cor(df_kaiaulu, method="pearson")

  # Make long format dataframes.
  df_corr_codeface <- as.data.frame(corr_codeface) %>% rownames_to_column(var = "metric_1")
  df_corr_codeface <- df_corr_codeface %>% pivot_longer(cols = cols, names_to = "metric_2", values_to = "corr")
  df_corr_git2net <- as.data.frame(corr_git2net) %>% rownames_to_column(var = "metric_1")
  df_corr_git2net <- df_corr_git2net %>% pivot_longer(cols = cols, names_to = "metric_2", values_to = "corr")
  df_corr_grimoire <- as.data.frame(corr_grimoire) %>% rownames_to_column(var = "metric_1")
  df_corr_grimoire <- df_corr_grimoire %>% pivot_longer(cols = cols, names_to = "metric_2", values_to = "corr")
  df_corr_kaiaulu <- as.data.frame(corr_kaiaulu) %>% rownames_to_column(var = "metric_1")
  df_corr_kaiaulu <- df_corr_kaiaulu %>% pivot_longer(cols = cols, names_to = "metric_2", values_to = "corr")

  # Merge the individual data frames.
  df_corr_codeface <- df_corr_codeface %>%
    mutate(param = "codeface")
  df_corr_git2net <- df_corr_git2net %>%
    mutate(param = "git2net")
  df_corr_grimoire <- df_corr_grimoire %>%
    mutate(param = "grimoire")
  df_corr_kaiaulu <- df_corr_kaiaulu %>%
    mutate(param = "kaiaulu")
  corr_dat <- rbind(df_corr_codeface, df_corr_git2net,
                     df_corr_grimoire, df_corr_kaiaulu)

  # Convert the data frame to a wide format with a specific correlation column
  # for each tool.
  corr_dat_wide <- corr_dat %>% pivot_wider(names_from = "param",
                                      values_from = "corr")
  corr_dat_wide <- corr_dat_wide[order(desc(corr_dat_wide$metric_1)),]
  corr_dat_wide$metric_1 <- factor(corr_dat_wide$metric_1, levels = rev(cols))
  corr_dat_wide$metric_2 <- factor(corr_dat_wide$metric_2, levels = rev(cols))

  # Compute the triangle coordinates for the upper and the lower left and right
  # parts.
  triangle_top <- make_triangles(corr_dat_wide$metric_1,
                                 corr_dat_wide$metric_2, point = "top")
  triangle_top <- triangle_top %>% select(xtop = x, ytop = y)

  triangle_right <- make_triangles(corr_dat_wide$metric_1,
                                   corr_dat_wide$metric_2, point = "right")
  triangle_right <- triangle_right %>% select(xright = x, yright = y)

  triangle_bottom <- make_triangles(corr_dat_wide$metric_1,
                                    corr_dat_wide$metric_2, point = "bottom")
  triangle_bottom <- triangle_bottom %>% select(xbottom = x, ybottom = y)

  triangle_left <- make_triangles(corr_dat_wide$metric_1,
                                  corr_dat_wide$metric_2, point = "left")
  triangle_left <- triangle_left %>% select(xleft = x, yleft = y)

  # A triangle is defined by three points (x,y). Thus, we must associate each
  # correlation value with the corresponding three points.
  point_data <- map_df(1:nrow(corr_dat_wide), function(i) corr_dat_wide[rep(i, 3), ])
  triangle_data <- bind_cols(point_data, triangle_top, triangle_right,
                             triangle_bottom, triangle_left)

  # Calculate the label coordinates for each triangle.
  label_top <- make_label_positions(corr_dat_wide$metric_1,
                                    corr_dat_wide$metric_2, point = "top")
  label_top <- label_top %>% select(xtop = x, ytop = y)

  label_right <- make_label_positions(corr_dat_wide$metric_1,
                                      corr_dat_wide$metric_2, point = "right")
  label_right <- label_right %>% select(xright = x, yright = y)

  label_bottom <- make_label_positions(corr_dat_wide$metric_1,
                                       corr_dat_wide$metric_2, point = "bottom")
  label_bottom <- label_bottom %>% select(xbottom = x, ybottom = y)

  label_left <- make_label_positions(corr_dat_wide$metric_1,
                                     corr_dat_wide$metric_2, point = "left")
  label_left <- label_left %>% select(xleft = x, yleft = y)

  label_data <- bind_cols(corr_dat_wide, label_top, label_right, label_bottom,
                          label_left)

  # Configure the actual plot.
  if (y_axis) {
    y_axis_el <- element_text(size = SMALL.SIZE*1.5)
  } else {
    y_axis_el <- element_blank()
  }
  xtiles <- vector()
  ytiles <- vector()
  for (i in 1:length(cols)) {
    xtiles <- c(xtiles, cols)
    ytiles <- c(ytiles, rep(cols[i], length(cols)))
  }
  xtiles <- rep(xtiles, 3)
  ytiles <- rep(ytiles, 3)

  # Adjust RdBu palette.
  #colors <- colorRampPalette(RColorBrewer::brewer.pal(11, "RdBu"))(100)
  
  # Create yellow-to-blue palette (similar to RdBu, but with yellow).
  rd_bu <- RColorBrewer::brewer.pal(11, "RdBu")
  yellow_to_white <- colorRampPalette(c(COLOURS.LIST[2], "#FFF9D0"))(5)
  white_to_blue <- rd_bu[7:11]  # Keeps original RdBu blues
  custom_palette <- c(yellow_to_white, "#FFFFFF", white_to_blue)
  colors <- colorRampPalette(custom_palette)(200)  # smoother gradient
  # 
  label_data$codeface_text <- ifelse(label_data$codeface > 0.5, "white", "black")
  label_data$git2net_text <- ifelse(label_data$git2net > 0.5, "white", "black")
  label_data$grimoire_text <- ifelse(label_data$grimoire > 0.5, "white", "black")
  label_data$kaiaulu_text <- ifelse(label_data$kaiaulu > 0.5, "white", "black")
  
  print(triangle_data)
  
  # Each tile shows:
  # top: codeface
  # right: git2net
  # bottom: grimoire
  # left: kaiaulu
  p <- ggplot(triangle_data) +
    xlim(cols[1:length(cols)]) + # Save space by shifting duplicate features
    ylim(cols[1:(length(cols))]) +
    geom_polygon(aes(x = xtop, y = ytop, fill = codeface,
                     group = interaction(metric_1, metric_2)),
                 lwd=0.05, color = COLOURS.LIST[12]) +
    scale_fill_gradientn(colors = colors, limits = c(-1, 1), guide="none") +
    ggnewscale::new_scale_fill() +
    geom_polygon(aes(x = xright, y = yright, fill = git2net,
                     group = interaction(metric_1, metric_2)),
                 lwd=0.05, color = COLOURS.LIST[12]) +
    scale_fill_gradientn(colors = colors, limits = c(-1, 1), guide="none") +
    ggnewscale::new_scale_fill() +
    geom_polygon(aes(x = xbottom, y = ybottom, fill = grimoire,
                     group = interaction(metric_1, metric_2)),
                 lwd=0.05, color = COLOURS.LIST[12]) +
    scale_fill_gradientn(colors = colors, limits = c(-1, 1), guide="none") +
    ggnewscale::new_scale_fill() +
    geom_polygon(aes(x = xleft, y = yleft, fill = kaiaulu,
                     group = interaction(metric_1, metric_2)),
                 lwd=0.05, color = COLOURS.LIST[12]) +
    scale_fill_gradientn(colors = colors, limits = c(-1, 1), guide="none") +
    ggnewscale::new_scale_fill() +
    geom_tile(aes(x = xtiles, y = ytiles), fill="transparent", colour="black",
              size=1, lwd=LINE.SIZE-0.1) +
    geom_text(data = label_data, aes(x = xtop, y=ytop, 
                                     label = round(codeface, 2), color=codeface_text),
              size = TABLE.FONT.SIZE*1.5) +
    scale_color_identity() +
    geom_text(data = label_data, aes(x = xright, y=yright, 
                                     label = round(git2net, 2), color=git2net_text),
              size = TABLE.FONT.SIZE*1.5) +
    scale_color_identity() +
    geom_text(data = label_data, aes(x = xbottom, y=ybottom, 
                                     label = round(grimoire, 2), color=grimoire_text),
              size = TABLE.FONT.SIZE*1.5) +
    scale_color_identity() +
    geom_text(data = label_data, aes(x = xleft, y=yleft, 
                                     label = round(kaiaulu, 2), color=kaiaulu_text),
              size = TABLE.FONT.SIZE*1.5) + # TABLE.FONT.SIZE-0.5
    scale_color_identity() +
    coord_equal() +
    theme_paper_base() +
    theme(plot.title=element_text(size=SMALL.SIZE*1.5, hjust = 0.5),
          axis.title.x=element_blank(), axis.title.y=element_blank(),
          axis.text = element_text(size = SMALL.SIZE*1.5), # Tick font size
          axis.text.x = element_text(size = SMALL.SIZE*1.5,  # x-axis tick font size
                                     angle=45, hjust=1, vjust=1), # x-axis tick angle
          axis.text.y = y_axis_el,  # x-axis tick font size
          # legend.text = element_text(size = TINY.SIZE), # Legend text font size
          # legend.title = element_text(size = TINY.SIZE, vjust=4), # Legend title font size
          legend.position = "none",
          # legend.key.size = unit(SYM.SIZE, "line") # Legend symbol width
    )

  return(p)
}

#' Creates the correlation heatmap plot showing Pearson's correlation for the
#' reduced data set from the original study
#'
#' @param df the metrics data frame from the original study (reduced version).
#' @param y_axis whether to plot y-axis labels.
#' @return the correlation heatmap.
#'
original_corr_plot <- function(df, y_axis=FALSE) {
  # Rename columns.
  new_names = c('Commits (log)',
                'Functions (log)',
                'HalEff (log)',
                'TS (log)',
                'N (log)',
                'InD (log)',
                'FModR')
  colnames(df) <- new_names
  cols <- new_names
  
  # Calculate Pearson correlation for each tool.
  corr_df <- cor(df, method="pearson")
  
  df_corr <- as.data.frame(corr_df) %>% rownames_to_column(var = "metric_1")
  df_corr <- df_corr %>% pivot_longer(cols = cols, names_to = "metric_2", values_to = "corr")
  df_corr <- df_corr %>%
    mutate(param = "original")
  
  # Convert the data frame to a wide format with a specific correlation column
  # for each tool.
  corr_dat_wide <- df_corr %>% pivot_wider(names_from = "param",
                                           values_from = "corr")
  corr_dat_wide <- corr_dat_wide[order(desc(corr_dat_wide$metric_1)),]
  corr_dat_wide$metric_1 <- factor(corr_dat_wide$metric_1, levels = rev(cols))
  corr_dat_wide$metric_2 <- factor(corr_dat_wide$metric_2, levels = rev(cols))
  
  # Configure the actual plot.
  if (y_axis) {
    y_axis_el <- element_text(size = SMALL.SIZE*1.5)
  } else {
    y_axis_el <- element_blank()
  }
  print(corr_dat_wide)
  
  # Create yellow-to-blue palette.
  rd_bu <- RColorBrewer::brewer.pal(11, "RdBu")
  yellow_to_white <- colorRampPalette(c(COLOURS.LIST[2], "#FFF9D0"))(5)
  white_to_blue <- rd_bu[7:11]  # Keeps original RdBu blues
  custom_palette <- c(yellow_to_white, "#FFFFFF", white_to_blue)
  colors <- colorRampPalette(custom_palette)(200)  # smoother gradient
  
  corr_dat_wide$text <- ifelse(corr_dat_wide$original > 0.5, "white", "black")
  print(corr_dat_wide)
  
  p <- ggplot(corr_dat_wide, aes(x = metric_1, y = metric_2, fill = original)) +
    xlim(cols[1:length(cols)]) + # Save space by shifting duplicate features
    ylim(cols[1:(length(cols))]) +
    geom_tile(colour="black",
              size=1, lwd=LINE.SIZE-0.1) +
    scale_fill_gradientn(colors = colors, limits = c(-1, 1), guide="none") +
    geom_text(aes(label = round(original, 2), color = I(text)),
              size = TABLE.FONT.SIZE*1.5) +
    coord_equal() +
    theme_paper_base() +
    theme(plot.title=element_text(size=SMALL.SIZE*1.5, hjust = 0.5),
          axis.title.x=element_blank(), axis.title.y=element_blank(),
          axis.text = element_text(size = SMALL.SIZE*1.5), # Tick font size
          axis.text.x = element_blank(),
          axis.ticks.x = element_blank(),
          axis.text.y = y_axis_el  # x-axis tick font size
    )
  
  return(p)
}

#' Builds the regression table for LaTeX.
#'
#' @param models the regression models to report.
#' @param metrics the metrics names.
#' @return the table matrix.
#'
reg_table_latex <- function(models, metrics) {
  # Add significance stars (from p-value).
  get_stars <- function(p) {
    # if (p < 0.001) "***"
    # else if (p < 0.01) "**"
    # else if (p < 0.05) "*"
    # else ""
    ""
  }
  
  # Extract and format coefficients.
  coefs <- map(models, ~ {
    tidy_df <- broom::tidy(.)
    
    # Bonferroni adjusted p-values.
    tidy_df <- tidy_df %>%
      mutate(p.adjusted = p.adjust(p.value, method = "bonferroni"))
    
    tidy_df %>%
      mutate(
        estimate = sprintf("%.2f", estimate),
        std.error = sprintf("(%.2f)", std.error),
        stars = map_chr(p.adjusted, get_stars),
        coef_str = paste0("$", estimate, "^{", stars, "}$"),
        se_str = paste0("$", std.error, "$")
      )
  })
  
  # Align terms across models.
  terms <- union(coefs[[1]]$term, coefs[[2]]$term) %>% union(coefs[[3]]$term)
  
  make_row <- function(var, col) {
    c(
      coef = coefs[[col]] %>% filter(term == var) %>% pull(coef_str) %>% first() %||% "",
      se    = coefs[[col]] %>% filter(term == var) %>% pull(se_str) %>% first() %||% ""
    )
  }
  
  # Build the table rows.
  rows <- map(terms, function(term) {
    if (term == "(Intercept)") {
      display_term = "(IC)"
    } else if (term == "I(TS^2)") {
      display_term = "TS$^{2}$"
    } else {
      display_term = term
    }
    row1 <- c(display_term,
              make_row(term, 1)[1],
              make_row(term, 2)[1],
              make_row(term, 3)[1])
    row2 <- c("",
              make_row(term, 1)[2],
              make_row(term, 2)[2],
              make_row(term, 3)[2])
    list(row1, row2)
  }) %>% flatten()
  
  # Add stats.
  add_stats <- function(stat) {
    c(stat,
      sprintf("%.2f", glance(models[[1]])[[stat]]),
      sprintf("%.2f", glance(models[[2]])[[stat]]),
      sprintf("%.2f", glance(models[[3]])[[stat]]))
  }
  rows <- append(rows, list(
    c("R$^{2}$", map_chr(models, ~ sprintf("%.2f", summary(.)$r.squared))),
    c("Adj. R$^{2}$", map_chr(models, ~ sprintf("%.2f", summary(.)$adj.r.squared)))
  ))
  
  # Create final data frame.
  df <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
  colnames(df) <- c(c("Term"), metrics)
  return(df)
}

#' Builds and reports the linear regression model.
#'
#' @param data the tool data frame.
#' @param save_path the LaTeX table output path.
#'
lin_reg <- function(data, save_path) {
  f1a = 'Commits ~ TS'
  f2a = 'Functions ~ TS'
  f3a = 'HalEff ~ TS'
  
  fit1a <- lm(formula=f1a, data=data)
  fit2a <- lm(formula=f2a, data=data)
  fit3a <- lm(formula=f3a, data=data)
  
  productivity_metrics <- c('Commits', 'Functions', 'HalEff')
  print(screenreg(list(fit1a, fit2a, fit3a),
                  custom.model.names = productivity_metrics))
  
  # The following code uses kable(extra) to generate a LaTeX booktabs table
  # from the regression stats and was mostly generated by ChatGPT.
  models <- list(fit1a, fit2a, fit3a)
  names(models) <- productivity_metrics
  
  # Create dataframe for LaTex.
  df <- reg_table_latex(models, productivity_metrics)

  # Add colored bars to the background of table cells according to their value
  for (metric in productivity_metrics) {
    df[3:4, metric] <- gsub("\\$(-?[0-9.]+)(\\^\\{[^}]*\\})?\\$", "\\\\colorcell{\\1}{\\1\\2}", df[3:4, metric])
  }
  
  # Capture LaTeX and save to file.
  latex_code <- capture.output(
    kable(df, format = "latex", booktabs = TRUE, linesep = "", 
          escape = FALSE, align="lccc") %>% 
      row_spec(4, hline_after = TRUE))
  writeLines(latex_code, save_path)
}

#' Builds and reports the quadratic regression model.
#'
#' @param data the tool data frame.
#' @param save_path the LaTeX table output path.
#'
poly_reg <- function(data, save_path) {
  f1b = 'Commits ~ TS + I(TS^2)'
  f2b = 'Functions ~ TS + I(TS^2)'
  f3b = 'HalEff ~ TS + I(TS^2)'
  
  fit1b <- lm(formula=f1b, data=data)
  fit2b <- lm(formula=f2b, data=data)
  fit3b <- lm(formula=f3b, data=data)
  
  productivity_metrics <- c('Commits', 'Functions', 'HalEff')
  print(screenreg(list(fit1b, fit2b, fit3b),
                  custom.model.names = productivity_metrics))
  
  # The following code uses kable(extra) to generate a LaTeX booktabs table
  # from the regression stats and was mostly generated by ChatGPT.
  models <- list(fit1b, fit2b, fit3b)
  names(models) <- productivity_metrics
  
  # Create dataframe for LaTex.
  df <- reg_table_latex(models, productivity_metrics)
  
  # Add colored bars to the background of table cells according to their value
  for (metric in productivity_metrics) {
    df[3:4, metric] <- gsub("\\$(-?[0-9.]+)(\\^\\{[^}]*\\})?\\$", "\\\\colorcell{\\1}{\\1\\2}", df[3:4, metric])
    df[5:6, metric] <- gsub("\\$(-?[0-9.]+)(\\^\\{[^}]*\\})?\\$", "\\\\colorcell{\\1}{\\1\\2}", df[5:6, metric])
  }
  
  # Capture LaTeX and save to file.
  latex_code <- capture.output(
    kable(df, format = "latex", booktabs = TRUE, linesep = "", 
          escape = FALSE, align="lccc") %>% 
      row_spec(6, hline_after = TRUE))
  writeLines(latex_code, save_path)
}

#' Builds and reports the linear regression model with control variables.
#'
#' @param data the tool data frame.
#' @param save_path the LaTeX table output path.
#'
lin_reg_controls <- function(data, save_path) {
  f1c = 'Commits ~ TS + InD + FModR'
  f2c = 'Functions ~ TS + InD + FModR'
  f3c = 'HalEff ~ TS + InD + FModR'
  
  fit1c <- lm(formula=f1c, data=data)
  fit2c <- lm(formula=f2c, data=data)
  fit3c <- lm(formula=f3c, data=data)
  
  productivity_metrics <- c('Commits', 'Functions', 'HalEff')
  print(screenreg(list(fit1c, fit2c, fit3c),
                  custom.model.names = productivity_metrics))
  
  # The following code uses kable(extra) to generate a LaTeX booktabs table
  # from the regression stats and was mostly generated by ChatGPT.
  models <- list(fit1c, fit2c, fit3c)
  names(models) <- productivity_metrics
  
  # Create dataframe for LaTex.
  df <- reg_table_latex(models, productivity_metrics)
  
  # Add colored bars to the background of table cells according to their value
  for (metric in productivity_metrics) {
    df[3:4, metric] <- gsub("\\$(-?[0-9.]+)(\\^\\{[^}]*\\})?\\$", "\\\\colorcell{\\1}{\\1\\2}", df[3:4, metric])
    df[5:6, metric] <- gsub("\\$(-?[0-9.]+)(\\^\\{[^}]*\\})?\\$", "\\\\colorcell{\\1}{\\1\\2}", df[5:6, metric])
    df[7:8, metric] <- gsub("\\$(-?[0-9.]+)(\\^\\{[^}]*\\})?\\$", "\\\\colorcell{\\1}{\\1\\2}", df[7:8, metric])
  }
  
  # Capture LaTeX and save to file.
  latex_code <- capture.output(
    kable(df, format = "latex", booktabs = TRUE, linesep = "", 
          escape = FALSE, align="lccc") %>% 
      row_spec(8, hline_after = TRUE))
  writeLines(latex_code, save_path)
}

#' Builds and reports the quadratic regression model with control variables.
#'
#' @param data the tool data frame.
#' @param save_path the LaTeX table output path.
#'
poly_reg_controls <- function(data, save_path) {
  f1d = 'Commits ~ TS + I(TS^2) + InD + FModR'
  f2d = 'Functions ~ TS + I(TS^2) + InD + FModR'
  f3d = 'HalEff ~ TS + I(TS^2) + InD + FModR'
  
  fit1d <- lm(formula=f1d, data=data)
  fit2d <- lm(formula=f2d, data=data)
  fit3d <- lm(formula=f3d, data=data)
  
  productivity_metrics <- c('Commits', 'Functions', 'HalEff')
  print(screenreg(list(fit1d, fit2d, fit3d),
                  custom.model.names = productivity_metrics))
  
  # The following code uses kable(extra) to generate a LaTeX booktabs table
  # from the regression stats and was mostly generated by ChatGPT.
  models <- list(fit1d, fit2d, fit3d)
  names(models) <- productivity_metrics
  
  # Create dataframe for LaTex.
  df <- reg_table_latex(models, productivity_metrics)
  
  # Add colored bars to the background of table cells according to their value
  for (metric in productivity_metrics) {
    df[3:4, metric] <- gsub("\\$(-?[0-9.]+)(\\^\\{[^}]*\\})?\\$", "\\\\colorcell{\\1}{\\1\\2}", df[3:4, metric])
    df[5:6, metric] <- gsub("\\$(-?[0-9.]+)(\\^\\{[^}]*\\})?\\$", "\\\\colorcell{\\1}{\\1\\2}", df[5:6, metric])
    df[7:8, metric] <- gsub("\\$(-?[0-9.]+)(\\^\\{[^}]*\\})?\\$", "\\\\colorcell{\\1}{\\1\\2}", df[7:8, metric])
    df[9:10, metric] <- gsub("\\$(-?[0-9.]+)(\\^\\{[^}]*\\})?\\$", "\\\\colorcell{\\1}{\\1\\2}", df[9:10, metric])
  }
  
  # Capture LaTeX and save to file.
  latex_code <- capture.output(
    kable(df, format = "latex", booktabs = TRUE, linesep = "", 
          escape = FALSE, align="lccc") %>% 
      row_spec(10, hline_after = TRUE))
  writeLines(latex_code, save_path)
}

#' Creates the linear and quadratic regression model plot for multiple
#' metrics and tools.
#'
#' @param df_original the metrics data frame from the original study (reduced version).
#' @param df_codeface the metrics data frame when using Codeface.
#' @param df_git2net the metrics data frame when using git2net.
#' @param df_grimoire the metrics data frame when using GrimoireLab.
#' @param df_kaiaulu the metrics data frame when using Kaiaulu.
#' @param metrics the metrics to correlate for each tool. 
#' @return the regression model plot.
#'
reg_plot_multiple <- function(df_original, df_codeface, df_git2net, 
                              df_grimoire, df_kaiaulu, metrics) {
  
  # Combine individual data frames to joint long data frame.
  df <- data.frame()
  for (m in metrics) {
    df_original_tmp <- df_original[, c("TS", m)]
    df_codeface_tmp <- df_codeface[, c("TS", m)]
    df_git2net_tmp <- df_git2net[, c("TS", m)]
    df_grimoire_tmp <- df_grimoire[, c("TS", m)]
    df_kaiaulu_tmp <- df_kaiaulu[, c("TS", m)]
    colnames(df_original_tmp)[colnames(df_original_tmp) == m] <- "value"
    colnames(df_codeface_tmp)[colnames(df_codeface_tmp) == m] <- "value"
    colnames(df_git2net_tmp)[colnames(df_git2net_tmp) == m] <- "value"
    colnames(df_grimoire_tmp)[colnames(df_grimoire_tmp) == m] <- "value"
    colnames(df_kaiaulu_tmp)[colnames(df_kaiaulu_tmp) == m] <- "value"

    df_original_tmp <- df_original_tmp %>% mutate(tool = "Original")
    df_original_tmp <- df_original_tmp %>% mutate(metric = m)
    df_codeface_tmp <- df_codeface_tmp %>% mutate(tool = "Codeface")
    df_codeface_tmp <- df_codeface_tmp %>% mutate(metric = m)
    df_git2net_tmp <- df_git2net_tmp %>% mutate(tool = "git2net")
    df_git2net_tmp <- df_git2net_tmp %>% mutate(metric = m)
    df_grimoire_tmp <- df_grimoire_tmp %>% mutate(tool = "GrimoireLab")
    df_grimoire_tmp <- df_grimoire_tmp %>% mutate(metric = m)
    df_kaiaulu_tmp <- df_kaiaulu_tmp %>% mutate(tool = "Kaiaulu")
    df_kaiaulu_tmp <- df_kaiaulu_tmp %>% mutate(metric = m)
    
    df <- rbind(df, df_original_tmp, df_codeface_tmp, df_git2net_tmp, 
                df_grimoire_tmp, df_kaiaulu_tmp)
  }
  df$tool <- factor(df$tool, levels = c("Original", 
                                        setdiff(unique(df$tool)[order(tolower(unique(df$tool)))], 
                                                "Original")))
  
  # Build linear and quadratic regression models.
  linear_formula <- 'y ~ x'
  quadratic_formula <- 'y ~ x + I(x^2)'
  
  p <- ggplot(df, aes(x = exp(TS), y = exp(value))) +
    labs(x = "Team Size", y = "Productivity / Team Member") +
    geom_point(size  = BIG.POINT.SIZE*1.5, stroke = 0, shape=19, alpha = .25, color = COLOURS.LIST[8])+
    stat_smooth(method = "lm", formula = linear_formula, size = LINE.SIZE, fill = COLOURS.LIST[3], alpha = 0.12, color = COLOURS.LIST[6])+
    stat_smooth(method = "lm", formula = quadratic_formula, size = LINE.SIZE, fill = COLOURS.LIST[3], alpha = 0.12, color = COLOURS.LIST[2]) +
    facet_grid2(tool ~ metric, scales = "free", independent = "y") + 
    annotation_logticks(linewidth = LINE.SIZE.THIN/2)+
    scale_x_log10()+
    scale_y_log10()+
    #facet_wrap(~ tool, nrow=2, ncol=2) +
    theme_paper_base() +
    theme(axis.text = element_text(size = SMALL.SIZE*1.3),
          axis.text.x = element_text(size = SMALL.SIZE*1.3),
          axis.text.y = element_text(size = SMALL.SIZE*1.3),
          axis.title.x = element_text(size = SMALL.SIZE*1.6),
          axis.title.y = element_text(size = SMALL.SIZE*1.6),
          legend.text = element_text(size = SMALL.SIZE*1.5),
          legend.title = element_text(size = SMALL.SIZE*1.5),
          legend.key.size = unit(SYM.SIZE, "line"), # Legend symbol width
          legend.position = "top",
          strip.text = element_text(size = SMALL.SIZE*1.5)) # Facet title size
  
  return(p)
}

#' Evaluates result stability (H_aR) across tools using bootstrap CIs.
#'
#' For each productivity metric m_p and collaboration metric m_c, computes the
#' Pearson correlation rho_{m_p,m_c,t}; for each m_p, the linear regression
#' coefficient beta_{m_p,TS,t} from lm(m_p ~ TS). For every quantity, 95%
#' bootstrap CIs are built from B resamples of the (project, time window)
#' observations of each tool independently. A quantity is stable if the
#' cross-tool deviation of BOTH CI bounds stays within the respective threshold.
#'
#' @param tool_dfs named list of tool data frames (renamed, log-transformed).
#' @param prod_metrics productivity metrics M_prod.
#' @param collab_metrics collaboration metrics M_collab.
#' @param delta_rho stability threshold for correlations.
#' @param delta_beta stability threshold for regression coefficients.
#' @param B number of bootstrap resamples.
#' @param save_path the LaTeX table output path.
#' @param csv_path the CSV output path.
#' @return a data frame with per-quantity CI bound deviations and stability flags.
#'
result_stability <- function(tool_dfs, prod_metrics, collab_metrics,
                             delta_rho = 0.1, delta_beta = 0.1, B = 10000,
                             save_path = NULL, csv_path = NULL) {
  set.seed(42)
  
  # Bootstrap 95% CI of a statistic for one tool (resample observations).
  boot_ci <- function(df, stat_fn) {
    n <- nrow(df)
    est <- replicate(B, {
      idx <- sample.int(n, n, replace = TRUE)
      stat_fn(df[idx, , drop = FALSE])
    })
    quantile(est, c(0.025, 0.975), names = FALSE, na.rm = TRUE)
  }
  
  rho_fn  <- function(mp, mc) function(d) cor(d[[mp]], d[[mc]], method = "pearson")
  beta_fn <- function(mp) function(d) coef(lm(reformulate("TS", mp), data = d))[["TS"]]
  
  # Enumerate quantities: rho for each (mp, mc) and beta for each mp.
  quantities <- c(
    unlist(lapply(prod_metrics, function(mp)
      lapply(collab_metrics, function(mc)
        list(label = sprintf("$\\rho_{\\text{%s},\\text{%s}}$", mp, mc),
             key = sprintf("rho(%s, %s)", mp, mc),
             fn = rho_fn(mp, mc), delta = delta_rho))),
      recursive = FALSE),
    lapply(prod_metrics, function(mp)
      list(label = sprintf("$\\beta_{\\text{%s},\\text{TS}}$", mp),
           key = sprintf("beta(%s, TS)", mp),
           fn = beta_fn(mp), delta = delta_beta))
  )
  
  # Per quantity: calculate cross-tool deviation of each CI bound.
  metrics   <- vapply(quantities, function(q) q$label, character(1))
  deltas    <- vapply(quantities, function(q) q$delta, numeric(1))
  keys      <- vapply(quantities, function(q) q$key, character(1))
  dev_lower <- numeric(length(quantities))
  dev_upper <- numeric(length(quantities))
  
  # Per metric and tool boundaries for manual verification
  bounds_long <- list()
  
  # Evaluate tool CIs.
  for (i in seq_along(quantities)) {
    cis <- sapply(tool_dfs, function(df) boot_ci(df, quantities[[i]]$fn))
    # LaTeX table aggregation
    dev_lower[i] <- max(cis[1, ]) - min(cis[1, ])
    dev_upper[i] <- max(cis[2, ]) - min(cis[2, ])
    # CSV details
    bounds_long[[i]] <- data.frame(
      Quantity = quantities[[i]]$key,
      Tool     = names(tool_dfs),
      Lower    = round(cis[1, ], 4),
      Upper    = round(cis[2, ], 4),
      row.names = NULL, stringsAsFactors = FALSE
    )
  }
  
  # Save CSV table for manual verification.
  if (!is.null(csv_path)) {
    bounds_path <- sub("\\.csv$", "_bounds.csv", csv_path)
    write_csv(do.call(rbind, bounds_long), bounds_path)
  }
  
  # Save LaTeX table.
  fmt_cell <- function(dev, delta) {
    txt <- sprintf("%.2f", dev)
    ifelse(dev > delta, paste0("\\cellcolor{lfd-lilac!60}{", txt, "}"), txt)
  }
  
  # Transposed table: one row per quantity, columns for the two CI bounds.
  res <- data.frame(
    metrics,
    mapply(fmt_cell, dev_lower, deltas),
    mapply(fmt_cell, dev_upper, deltas),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  colnames(res) <- c("$\\max\\limits_{t \\in T} - \\min\\limits_{t \\in T}$",
                     "$\\text{CI}_{\\text{lo}}$", "$\\text{CI}_{\\text{hi}}$")
  
  if (!is.null(save_path)) {
    tabular <- capture.output(
      kable(res, format = "latex", booktabs = TRUE, linesep = "",
            escape = FALSE, align = "lcc"))
    latex_code <- c("{\\scriptsize", tabular, "}")

    writeLines(latex_code, save_path)
  }
}

#' Evaluates conclusion stability (H_aC) across tools.
#'
#' Following Gote et al., a tool supports the Brooks' law verdict (V_t = 1) if
#' all correlations rho_{m_p,TS,t} and linear regression coefficients
#' beta_{m_p,TS,t} between each productivity metric and team size are negative.
#' The conclusion is stable iff all tools agree (V_t = 1 for all t).
#'
#' @param tool_dfs named list of tool data frames (renamed, log-transformed).
#' @param prod_metrics productivity metrics M_prod.
#' @param csv_path optional CSV output path for the per-tool values.
#' @return TRUE if the conclusion is stable across tools, else FALSE.
#'
conclusion_stability <- function(tool_dfs, prod_metrics, 
                                 save_path = NULL, csv_path = NULL) {
  rows <- list()
  for (tool in names(tool_dfs)) {
    d <- tool_dfs[[tool]]
    for (mp in prod_metrics) {
      rho  <- cor(d[[mp]], d[["TS"]], method = "pearson")
      beta <- coef(lm(reformulate("TS", mp), data = d))[["TS"]]
      rows[[length(rows) + 1]] <- data.frame(
        Tool = tool, Metric = mp,
        rho = round(rho, 4), beta = round(beta, 4),
        row.names = NULL, stringsAsFactors = FALSE
      )
    }
  }
  df <- do.call(rbind, rows)
  
  if (!is.null(csv_path)) {
    write_csv(df, csv_path)
  }
  
  # Save LaTeX table.
  if (!is.null(save_path)) {
    # Highlight a cell that breaks the verdict (non-negative value).
    fmt_cell <- function(v) {
      ifelse(v < 0, "$<0$", "\\cellcolor{lfd-lilac!60}{$\\geq 0$}")
    }
    
    # Transposed table: one row per metric, one column per tool.
    tools <- names(tool_dfs)
    metric_labels <- character(0)
    cells <- list()  # one vector per tool, in metric-row order
    for (tool in tools) cells[[tool]] <- character(0)
    
    add_row <- function(label, values) {
      metric_labels <<- c(metric_labels, label)
      for (tool in tools)
        cells[[tool]] <<- c(cells[[tool]], values[[tool]])
    }
    
    for (mp in prod_metrics) {
      sub <- df[df$Metric == mp, ]
      sub <- sub[match(tools, sub$Tool), ]
      rho_vals  <- setNames(fmt_cell(sub$rho),  tools)
      beta_vals <- setNames(fmt_cell(sub$beta), tools)
      add_row(sprintf("$\\rho_{\\text{%s},\\text{TS}}$", mp),  rho_vals)
      add_row(sprintf("$\\beta_{\\text{%s},\\text{TS}}$", mp), beta_vals)
    }
    
    # Per-tool verdict V_t = 1 iff all rho and beta negative.
    vt <- tapply(df$rho < 0 & df$beta < 0, df$Tool, all)[tools]
    add_row("$V_t$", setNames(ifelse(vt, "1", "0"), tools))
    
    # Assemble: metric-label column + one column per tool (rotated header).
    tbl <- data.frame(Metric = metric_labels,
                      check.names = FALSE, stringsAsFactors = FALSE)
    disp <- function(t) ifelse(t == "GrimoireLab", "Grimoire", t)
    for (tool in tools)
      tbl[[sprintf("\\rotatebox{90}{%s}", disp(tool))]] <- cells[[tool]]
    colnames(tbl)[1] <- ""
    
    tabular <- capture.output(
      kable(tbl, format = "latex", booktabs = TRUE, linesep = "",
            escape = FALSE, align = c("l", rep("c", ncol(tbl) - 1))) %>%
        row_spec(length(metric_labels) - 1, hline_after = TRUE))
    latex_code <- c("{\\scriptsize", tabular, "}")
    writeLines(latex_code, save_path)
  }
}


# Read reduced original reproducibility data set.
df_original_full <- data.frame(read_csv(opt$repro_path))

# Select relevant metrics.
df_original_full <- df_original_full %>%
  rename(commits = Commits,
         function_delta = Functions,
         halstead_delta = HalEff,
         team_size = TS,
         nodes = N,
         indegree = InD,
         fmodr = FModR)

# Read replicated productivity data.
df_codeface_full <- data.frame(read_csv(path.join(opt$res_path, "codeface",
                                             "productivity.csv")))
df_grimoire_full <- data.frame(read_csv(path.join(opt$res_path, "grimoire",
                                             "productivity.csv")))
df_kaiaulu_full <- data.frame(read_csv(path.join(opt$res_path, "kaiaulu", 
                                            "productivity.csv")))
if (opt$network_mode == "adjacency") {
  df_git2net_full <- data.frame(read_csv(path.join(opt$res_path, "git2net",
                                                   "productivity.csv")))
} else {
  df_git2net_full <- data.frame(read_csv(path.join(opt$res_path, "git2net",
                                                   "productivity_edgelist.csv")))
}

# Select relevant metrics.
cols <- c("commits", "function_delta", "halstead_delta",
          "team_size", "nodes", "indegree", "fmodr")

df_original_full <- df_original_full[cols]
df_codeface_full <- df_codeface_full[cols]
df_git2net_full <- df_git2net_full[cols]
df_grimoire_full <- df_grimoire_full[cols]
df_kaiaulu_full <- df_kaiaulu_full[cols]

# Filter out missing values.
df_original <- filter_df_any(df_original_full)
df_codeface <- filter_df_any(df_codeface_full)
df_git2net <- filter_df_any(df_git2net_full)
df_grimoire <- filter_df_any(df_grimoire_full)
df_kaiaulu <- filter_df_any(df_kaiaulu_full)

# Log transform metrics.
df_original <- log_transform(df_original)
df_codeface <- log_transform(df_codeface)
df_git2net <- log_transform(df_git2net)
df_grimoire <- log_transform(df_grimoire)
df_kaiaulu <-log_transform(df_kaiaulu)

# Plot the original pairwise correlation for each metric.
p <- original_corr_plot(df_original, y_axis=TRUE)

plot_save_path <- str_c("corr_original.pdf")
ggsave(plot_save_path, plot = p,
       width = TEXTWIDTH, height = TEXTWIDTH, units = "in")
plot(p)
if (opt$tikz) {
  plot_save_path <- str_c("corr_original", ".tex")
  tikz(file.path("img-tikz", plot_save_path),
       width = TEXTWIDTH, height = TEXTWIDTH)
  print(p)
  dev.off()
}

# Plot the replicated pairwise correlation for each metric and tool.
p <- corr_plot(df_codeface, df_git2net, df_grimoire, df_kaiaulu, cols, y_axis=TRUE)


plot_save_path <- str_c("corr_", opt$network_mode, ".pdf")
ggsave(plot_save_path, plot = p,
       width = TEXTWIDTH, height = TEXTWIDTH, units = "in")
plot(p)
if (opt$tikz) {
  plot_save_path <- str_c("corr_", opt$network_mode, ".tex")
  tikz(file.path("img-tikz", plot_save_path),
       width = TEXTWIDTH, height = TEXTWIDTH)
  print(p)
  dev.off()
}

# Build regression models.
new_names = c('Commits',
              'Functions',
              'HalEff',
              'TS',
              'N',
              'InD',
              'FModR')
colnames(df_original) <- new_names
colnames(df_codeface) <- new_names
colnames(df_git2net) <- new_names
colnames(df_grimoire) <- new_names
colnames(df_kaiaulu) <- new_names
cols <- new_names

print("Linear relationship")
lin_reg(df_original, "lin_reg_original.tex")
lin_reg(df_codeface, "lin_reg_codeface.tex")
lin_reg(df_git2net, str_c("lin_reg_git2net_", opt$network_mode, ".tex"))
lin_reg(df_grimoire, "lin_reg_grimoire.tex")
lin_reg(df_kaiaulu, "lin_reg_kaiaulu.tex")

print("Quadratic relationship")
poly_reg(df_original, "poly_reg_original.tex")
poly_reg(df_codeface, "poly_reg_codeface.tex")
poly_reg(df_git2net, str_c("poly_reg_git2net_", opt$network_mode, ".tex"))
poly_reg(df_grimoire, "poly_reg_grimoire.tex")
poly_reg(df_kaiaulu, "poly_reg_kaiaulu.tex")

print("Linear relationship with controls")
lin_reg_controls(df_original, "lin_reg_controls_original.tex")
lin_reg_controls(df_codeface, "lin_reg_controls_codeface.tex")
lin_reg(df_git2net, str_c("lin_reg_git2net_controls_", opt$network_mode, ".tex"))
lin_reg_controls(df_grimoire, "lin_reg_controls_grimoire.tex")
lin_reg_controls(df_kaiaulu, "lin_reg_controls_kaiaulu.tex")

print("Quadratic relationship with controls")
poly_reg_controls(df_original, "poly_reg_controls_original.tex")
poly_reg_controls(df_codeface, "poly_reg_controls_codeface.tex")
poly_reg_controls(df_git2net, str_c("poly_reg_git2net_controls_", opt$network_mode, ".tex"))
poly_reg_controls(df_grimoire, "poly_reg_controls_grimoire.tex")
poly_reg_controls(df_kaiaulu, "poly_reg_controls_kaiaulu.tex")

# Plot linear and quadratic regression model (without controls)
# for productivity depending on team size.
p <- reg_plot_multiple(df_original, df_codeface, df_git2net,
                       df_grimoire, df_kaiaulu,
                       c("Commits", "Functions", "HalEff"))

plot_save_path <- str_c("productivity_team_size.pdf")
ggsave(plot_save_path, plot = p,
       width = TEXTWIDTH, height = TEXTWIDTH, units = "in")
plot(p)

if (opt$tikz) {
  plot_save_path <- str_c("productivity_team_size", ".tex")
  tikz(file.path("img-tikz", plot_save_path),
       width = TEXTWIDTH, height = TEXTWIDTH)
  print(p)
  dev.off()
}


# Evaluate result stability (H_aR) across tools.
tool_dfs <- list(Codeface = df_codeface, git2net = df_git2net,
                 GrimoireLab = df_grimoire, Kaiaulu = df_kaiaulu)
result_stability(tool_dfs,
                 prod_metrics   = c("Commits", "Functions", "HalEff"),
                 collab_metrics = c("N", "InD", "FModR"),
                 save_path = str_c("result_stability_", opt$network_mode, ".tex"),
                 csv_path  = str_c("result_stability_", opt$network_mode, ".csv"))

# Evaluate conclusion stability (H_aC) across tools.
conclusion_stability(tool_dfs,
                     prod_metrics = c("Commits", "Functions", "HalEff"),
                     save_path = str_c("conclusion_stability_", opt$network_mode, ".tex"),
                     csv_path = str_c("conclusion_stability_", opt$network_mode, ".csv"))