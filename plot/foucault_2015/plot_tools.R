# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

# Compares the replication of Foucault et al., 2015 across tools.

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
  make_option(c("--tikz"), type="logical", default=FALSE, action="store_true",
              help="Plot the tikz graph")
);

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);

load_evol_data <- function(base_path, tool, projects) {
  df_list <- lapply(projects, function(p) {
    file_path <- file.path(base_path, paste0(tool, "_evol-", p, ".csv"))
    if (!file.exists(file_path)) {
      return(NULL)
    }
    df <- read.csv(file_path, 
                   stringsAsFactors = FALSE)
    df$tool <- tool
    df$project <- p
    df
  })
  df_list <- df_list[!sapply(df_list, is.null)]
  df <- do.call(rbind, df_list)
  return(df)
}

load_metrics_data <- function(base_path, tool, filter = FALSE) {
  if (filter == TRUE) {
    df <- read.csv(file.path(base_path, paste0(tool, "_metrics_6m_filtered.csv")), 
                   stringsAsFactors = FALSE)
  } else {
    df <- read.csv(file.path(base_path, paste0(tool, "_metrics_6m.csv")), 
                   stringsAsFactors = FALSE)
  }
  
  df$tool <- tool
  return(df)
}

load_corr_data <- function(base_path, tool, filter = FALSE) {
  if (filter == TRUE) {
    df <- read.csv(file.path(base_path, paste0(tool, "_corr_data_filtered.csv")), 
                   stringsAsFactors = FALSE)
  } else {
    df <- read.csv(file.path(base_path, paste0(tool, "_corr_data.csv")), 
                   stringsAsFactors = FALSE)
  }
  
  df$tool <- tool
  return(df)
}

#' Formats the project names across studies (original and replication).
#' 
#' @param df the data frame with original project names.
#' @return the data frame with formatted project names.
#'
recode_projects_tools <- function(df) {
  df <- df %>%
    mutate(project = recode(project,
                            "angular_js" = "AngularJS",
                            "Angular.JS" = "AngularJS",
                            "ansible" = "Ansible",
                            "jenkins" = "Jenkins",
                            "jquery" = "JQuery",
                            "rails" = "Rails",
                            "https://github.com/angular/angular.js.git" = "AngularJS",
                            "https://github.com/ansible/ansible.git" = "Ansible",
                            "https://github.com/jenkinsci/jenkins.git" = "Jenkins",
                            "https://github.com/matthieu-foucault/jquery.git" = "JQuery",
                            "https://github.com/rails/rails.git" = "Rails"),
           tool = recode(tool,
                         "original" = "Original",
                         "codeface" = "Codeface",
                         "grimoire" = "GrimoireLab",
                         "kaiaulu" = "Kaiaulu"))
  return(df)
}

#' Creates the time series plot showing developer turnover per tool.
#' 
#' @param df the data frame with the activity data for all tools.
#' @return the time series plot.
#'
plot_evol <- function(df) {
  df_long <- pivot_longer(df,
                          cols = c(Stayers, Newcomers, Leavers, Total),
                          names_to = "Group",
                          values_to = "value")
  
  df_long$tool <- factor(df_long$tool, levels = c("Original", 
                                                  setdiff(unique(df_long$tool)[order(tolower(unique(df_long$tool)))], 
                                                          "Original")))
  df_long$project <- factor(df_long$project, levels = unique(df$project[order(tolower(df$project))]))
  
  p <- ggplot(df_long, aes(x = time, y = value, color = Group, group=Group)) +
    labs(x = "Time", y = "Group Size") +
    geom_line(linewidth = LINE.SIZE+0.3, linetype="solid", alpha=0.6) +
    scale_x_date(date_labels = "%Y", date_breaks = "1 year") +
    scale_colour_manual(values=COLOURS.LIST[c(2,6,8,3)]) +
    facet_grid2(tool ~ project, scales = "free", independent = "y") + 
    theme_paper_base() +
    theme(axis.text = element_text(size = SMALL.SIZE*1.3),
          axis.text.x = element_text(angle = 45, hjust = 1, size = SMALL.SIZE*1.3),
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

#' Creates the heatmap plot showing contributor types activity rate and bug 
#' fixes per module for the original study and all replications.
#' 
#' @param df the data frame with the module pattern data for all tools.
#' @param module_name whether to plot the module name labels.
#' @return the module patterns heatmap plot.
#'
plot_patterns <- function(df, module_name) {
  df_long <- pivot_longer(df,
                          cols = c(BugFixes, ENA, ELA, INA, ILA, StA, A),
                          names_to = "Group",
                          values_to = "value")
  
  # Log transform values as done in the original heatmap.
  df_long$value <- log(df_long$value + 0.01)

  # Collect union of all modules per project.
  all_modules <- df_long %>%
    group_by(project) %>%
    summarise(modules = list(unique(module)), .groups = "drop") %>%
    deframe()
  
  # Get ordering from original study and total activity.
  ref_order <- df_long %>%
    filter(tool == "Original", Group == "A") %>%
    group_by(project) %>%
    arrange(value) %>%
    summarise(order = list(rev(module)), .groups = "drop") %>%
    deframe()
  
  module_levels <- lapply(names(all_modules), function(p) {
    if (!is.null(ref_order[[p]])) {
      # Ensure reference order but include all modules from union.
      ordered <- unique(c(ref_order[[p]], all_modules[[p]]))
      ordered
    } else {
      all_modules[[p]]
    }
  })
  names(module_levels) <- names(all_modules)
  
  # Apply factor levels per project.
  df_long <- df_long %>%
    group_by(project) %>%
    mutate(module = factor(module, levels = module_levels[[unique(project)]])) %>%
    ungroup()
  
  # # Debugging/for manual verification.
  # df_proj <- df_long %>% filter(project == "Ansible")
  # original_modules <- df_proj %>%
  #   filter(tool == "Original") %>%
  #   pull(module) %>%
  #   as.character() %>%
  #   unique()
  # git2net_modules <- df_proj %>%
  #   filter(tool == "Codeface") %>%
  #   pull(module) %>%
  #   as.character() %>%
  #   unique()
  # diff_modules <- setdiff(original_modules, git2net_modules) %>% c(setdiff(git2net_modules, original_modules))
  # for (d in diff_modules) {
  #   print(d)
  # }
  
  # Determine facet order.
  df_long$tool <- factor(df_long$tool, levels = c("Original", 
                                                  setdiff(unique(df_long$tool)[order(tolower(unique(df_long$tool)))], 
                                                          "Original")))
  df_long$project <- factor(df_long$project, levels = unique(df$project[order(tolower(df$project))]))
  
  df_long <- df_long %>%
    mutate(Group = recode(Group, "A" = "Total A"))
  df_long$Group <- factor(df_long$Group, levels = c("Total A", "INA", "ENA", 
                                                    "ILA", "ELA", "StA", "BugFixes"))
  
  # Colour gradient similar to the original study.
  gradient_colors <- colorRampPalette(c("#DEEBF7", COLOURS.LIST[6], "#08306B"))(1000)
  
  # Not all combinations are present in the dataframe. We want to plot the
  # missing ones as empty tiles.
  projects <- unique(df_long$project)
  tools <- unique(df_long$tool)
  groups <- unique(df_long$Group)

  df_filled <- data.frame()

  for (proj in projects) {
    modules_proj <- df_long %>%
      filter(project == proj) %>%
      pull(module) %>%
      unique()

    combos <- expand.grid(
      tool = tools,
      project = proj,
      module = modules_proj,
      Group = groups,
      stringsAsFactors = FALSE
    )

    # Join with actual data to fill values, missing ones become NA.
    df_proj_filled <- combos %>%
      left_join(df_long, by = c("tool", "project", "module", "Group"))

    df_filled <- bind_rows(df_filled, df_proj_filled)
  }
  df_long <- df_filled
  
  print(head(df_long, 5))
  
  # # Tool color version.
  # df_long <- df_long %>%
  #   mutate(fill_color = case_when(
  #     tool == "Original" ~ {
  #       pal <- colorRampPalette(c("#DEDEDE", COLOURS.LIST[10], "#555555"))(1000)
  #       scales::col_numeric(pal, domain = range(value, na.rm = TRUE),
  #                           na.color = "white")(value)
  #     },
  #     tool == "Codeface" ~ {
  #       pal <- colorRampPalette(c("#FFF7BC", COLOURS.LIST[2], "#8C6D31"))(1000)
  #       scales::col_numeric(pal, domain = range(value, na.rm = TRUE),
  #                           na.color = "white")(value)
  #     },
  #     tool == "git2net" ~ {
  #       pal <- colorRampPalette(c("#B8F1E0", COLOURS.LIST[4], "#004D35"))(1000)
  #       scales::col_numeric(pal, domain = range(value, na.rm = TRUE),
  #                           na.color = "white")(value)
  #     },
  #     tool == "GrimoireLab" ~ {
  #       pal <- colorRampPalette(c("#F3EAF8", COLOURS.LIST[8], "#5D3A66"))(1000)
  #       scales::col_numeric(pal, domain = range(value, na.rm = TRUE),
  #                           na.color = "white")(value)
  #     },
  #     tool == "Kaiaulu" ~ {
  #       pal <- colorRampPalette(c("#DEEBF7", COLOURS.LIST[6], "#08306B"))(1000)
  #       scales::col_numeric(pal, domain = range(value, na.rm = TRUE),
  #                           na.color = "white")(value)
  #     }
  #   ))
  
  if (module_name == FALSE) {
    y_modules = element_blank()
  } else {
    y_modules = element_text(size = TABLE.FONT.SIZE)
  }
  
  p <- ggplot(df_long, aes(x = Group, y = module, fill = value)) +
  #p <- ggplot(df_long, aes(x = Group, y = module, fill = fill_color)) +
    labs(x = "", y = "Module") +
    geom_tile() +
    scale_fill_gradientn(colours = gradient_colors, na.value="lightgray") +
    ##facet_grid2(project ~ tool, scales = "free", independent = "y") +
    facet_grid2(project ~ tool, scales = "free_y", space = "free_y") +
    #scale_fill_identity(na.value = "white") +
    theme_paper_base() +
    theme(axis.text = element_text(size = SMALL.SIZE*1.3),
          axis.text.x = element_text(angle = 45, hjust = 1, size = SMALL.SIZE*1.3),
          axis.text.y = y_modules,
          axis.title.x = element_text(size = SMALL.SIZE*1.6),
          axis.title.y = element_text(size = SMALL.SIZE*1.6),
          legend.text = element_text(size = SMALL.SIZE*1.5),
          legend.title = element_text(size = SMALL.SIZE*1.5),
          legend.key.size = unit(SYM.SIZE, "line"), # Legend symbol width
          legend.position = "none",
          strip.text = element_text(size = SMALL.SIZE*1.5)) # Facet title size
  return(p)
}

#' Creates the LaTeX table with confidence intervals for Spearman's correlation
#' coefficients for all turnover metrics and bug density.
#' 
#' @param df the data frame with the confidence intervals for all metrics and tools.
#' @param save_path the path to store the LaTeX table.
#'
corr_table <- function(df, save_path) {
  # Format digits.
  df <- df %>%
    mutate_if(is.numeric, round, digits=2)
  
  # Convert dataframe to wide format.
  df <- df[c("project", "tool", "metric", "lo_95", "hi_95")]
  df <- df %>%
    pivot_wider(
      id_cols = c(project, tool),
      names_from = metric,
      values_from = c(lo_95, hi_95)
    )
  
  # Make sure all combinations are shown.
  df <- df %>%
    complete(project, tool)
  
  combine_columns <- function(row) {
    #comb <- paste0("[", paste(row, collapse = ", "), "]")
    formatted <- sprintf("%.2f", row)
    abs_width <- max(nchar(gsub("^-", "", formatted)))
    
    # Add padding.
    formatted <- sapply(formatted, function(x) {
      if (startsWith(x, "-")) {
        x
      } else {
        sprintf(paste0("% ", abs_width + 1, "s"), x)
      }
    })
    comb <- paste0("[", paste(formatted, collapse = ", "), " ]")
    
    # Color cell if significant.
    ifelse(sign(row[1]) == sign(row[2]), paste0("\\cellcolor{lfd-yellow}{", comb, "}"), comb)
  }
  
  df <- df %>%
    mutate(
      INA = apply(select(., ends_with("_INA")), 1, combine_columns),
      ILA = apply(select(., ends_with("_ILA")), 1, combine_columns),
      ENA = apply(select(., ends_with("_ENA")), 1, combine_columns),
      ELA = apply(select(., ends_with("_ELA")), 1, combine_columns),
      StA = apply(select(., ends_with("_StA")), 1, combine_columns),
      A = apply(select(., ends_with("_A")), 1, combine_columns),
    )
  
  df <- df[c("project", "tool", "INA", "ILA", "ENA", "ELA", "StA", "A")]
  
  # Order data.
  df$project <- factor(df$project, levels = unique(df$project[order(tolower(df$project))]))
  df$tool <- factor(df$tool, levels = c("Original",
                                        setdiff(unique(df$tool)[order(tolower(unique(df$tool)))],
                                                "Original")))
  df <- df[order(df$project, df$tool), ]
  
  # Rename some columns.
  df <- df %>%
    rename(
      "Project" = project,
      "Tool" = tool,
      "Total A" = A
    )
  
  # Remove project names for 2nd+ row.
  levels(df$Project) <- c(levels(df$Project), "")
  df[2:5, c("Project")] <- ""
  df[7:10, c("Project")] <- ""
  df[12:15, c("Project")] <- ""
  df[17:20, c("Project")] <- ""
  df[22:25, c("Project")] <- ""
  print(df, n = Inf, width = Inf)
  
  cap <- paste("Spearman correlation coefficients between turnover metrics and
         bug density (bug-fixing commits normalised by code size) per module and 
         subject project.
         Confidence intervals are computed per tool data set using bootstrap.
         Turnover metrics include internal newcomers activity (INA),
         internal leavers activity (ILA), external newcomers activity (ENA), 
         external leavers activity (ELA), stayers activity (StA) and total 
         activity of all developers (A). \\label{tab:corr-table}", sep = "")
  
  df_out <- kable(df, format = "latex", booktabs = TRUE, 
                  align = c("c", "l", "c", "c", "c", "c", "c", "c"), 
                  linesep = "", caption = cap, escape = FALSE) %>%
    row_spec(0, bold=TRUE) %>% 
    row_spec(5, hline_after = TRUE) %>%
    row_spec(10, hline_after = TRUE) %>%
    row_spec(15, hline_after = TRUE) %>%
    row_spec(20, hline_after = TRUE) %>%
    kable_styling(latex_options = "scale_down")
  
  # Workaround: fix minor formatting issues
  df_out <- gsub("midrule\\\\\\\\", "midrule", df_out)
  df_out <- gsub("NA", "--", df_out)
  df_out <- gsub("I--", "INA", df_out)
  df_out <- gsub("E--", "ENA", df_out)
  
  writeLines(df_out, save_path)
}

#' Evaluate result stability (H_bR) across replication tools.
#'
#' For each (project, turnover metric), computes the cross-tool deviation of the
#' lower and upper 95% CI bounds (max_t - min_t) over the four replication tools,
#' using the precomputed bootstrap CIs. A cell requires all four tools to have a
#' CI; otherwise it is excluded ("--"). A cell is stable if the larger of the two
#' bound deviations stays within delta_rho.
#'
#' @param df_corr long df with project, tool, metric, lo_95, hi_95 (recoded).
#' @param metrics turnover metrics to include, in column order.
#' @param delta_rho stability threshold.
#' @param save_path LaTeX table output path.
#' @param csv_path CSV (long, verification) output path.
#'
result_stability_foucault <- function(df_corr,
                                      metrics = c("INA", "ILA", "ENA", "ELA", "StA", "A"),
                                      delta_rho = 0.1,
                                      save_path = NULL, csv_path = NULL) {
  repl_tools <- c("Codeface", "git2net", "GrimoireLab", "Kaiaulu")
  d <- df_corr[df_corr$tool %in% repl_tools & df_corr$metric %in% metrics, ]
  projects <- unique(d$project[order(tolower(d$project))])
  
  # Per (project, metric): deviation of each bound over the four tools.
  long <- list()
  for (p in projects) for (m in metrics) {
    sub <- d[d$project == p & d$metric == m, ]
    sub <- sub[match(repl_tools, sub$tool), ]  # align, NA rows for missing tools
    complete <- all(!is.na(sub$lo_95) & !is.na(sub$hi_95))
    if (complete) {
      dev_lo <- max(sub$lo_95) - min(sub$lo_95)
      dev_hi <- max(sub$hi_95) - min(sub$hi_95)
      dev    <- max(dev_lo, dev_hi)
    } else {
      dev_lo <- NA; dev_hi <- NA; dev <- NA
    }
    long[[length(long) + 1]] <- data.frame(
      project = p, metric = m,
      dev_lo = round(dev_lo, 4), dev_hi = round(dev_hi, 4),
      dev = round(dev, 4),
      stable = if (is.na(dev)) NA else dev <= delta_rho,
      row.names = NULL, stringsAsFactors = FALSE
    )
  }
  long <- do.call(rbind, long)
  
  assessed <- long[!is.na(long$dev), ]
  stable <- all(assessed$stable)
  cat(sprintf("H_bR result stability: %s  (%d of %d cells assessed)\n",
              if (stable) "STABLE" else "NOT STABLE",
              nrow(assessed), nrow(long)))
  
  # Save long table to CSV.
  if (!is.null(csv_path)) write_csv(long, csv_path)
  
  # Save as LaTeX matrix table.
  if (!is.null(save_path)) {
    fmt_cell <- function(dev, stab) {
      if (is.na(dev)) return("--")
      txt <- sprintf("%.2f", dev)
      if (!stab) paste0("\\cellcolor{lfd-lilac!60}{", txt, "}") else txt
    }
    tbl <- data.frame(Project = projects, check.names = FALSE,
                      stringsAsFactors = FALSE)
    for (m in metrics) {
      col <- vapply(projects, function(p) {
        r <- long[long$project == p & long$metric == m, ]
        fmt_cell(r$dev, r$stable)
      }, character(1))
      tbl[[if (m == "A") "Total A" else m]] <- col
    }
    tabular <- capture.output(
      kable(tbl, format = "latex", booktabs = TRUE, linesep = "",
            escape = FALSE, align = c("l", rep("c", length(metrics)))))
    latex_code <- c("{\\scriptsize", tabular, "}")
    writeLines(latex_code, save_path)
  }
}



# Plot turnover evolution.
projects = c("angular_js", "ansible", "jenkins", "jquery", "rails")

df_evol_original <- load_evol_data(opt$repro_path, "original", projects)
df_evol_codeface <- load_evol_data(paste0(opt$res_path, "/evol"), "codeface", projects)
df_evol_git2net <- load_evol_data(paste0(opt$res_path, "/evol"), "git2net", projects)
df_evol_grimoire <- load_evol_data(paste0(opt$res_path, "/evol"), "grimoire", projects)
df_evol_kaiaulu <- load_evol_data(paste0(opt$res_path, "/evol"), "kaiaulu", projects)
df_evol <- rbind(df_evol_original, df_evol_codeface, df_evol_git2net,
                 df_evol_grimoire, df_evol_kaiaulu)

names(df_evol)[names(df_evol) == "s"] <- "Stayers"
names(df_evol)[names(df_evol) == "n"] <- "Newcomers"
names(df_evol)[names(df_evol) == "l"] <- "Leavers"
names(df_evol)[names(df_evol) == "tot"] <- "Total"
df_evol$time <- as.Date(df_evol$time, format = "%Y-%m-%d")
df_evol <- recode_projects_tools(df_evol)

p <- plot_evol(df_evol)

plot_save_path <- file.path("evol", "turnover_evol.pdf")
ggsave(plot_save_path, plot = p,
       width = TEXTWIDTH, height = 0.9*TEXTWIDTH, units = "in")
plot(p)

if (opt$tikz) {
  plot_save_path <- file.path("img-tikz", "turnover_evol.tex")
  tikz(plot_save_path,
       width = TEXTWIDTH, height = 0.9*TEXTWIDTH)
  print(p)
  dev.off()
}

# Plot turnover and bug patterns per module.
df_metrics_original <- load_metrics_data(opt$repro_path, "original")
df_metrics_codeface <- load_metrics_data(paste0(opt$res_path, "/metrics"), "codeface")
df_metrics_git2net <- load_metrics_data(paste0(opt$res_path, "/metrics"), "git2net")
df_metrics_grimoire <- load_metrics_data(paste0(opt$res_path, "/metrics"), "grimoire")
df_metrics_kaiaulu <- load_metrics_data(paste0(opt$res_path, "/metrics"), "kaiaulu")
df_metrics <- rbind(df_metrics_original, df_metrics_codeface, df_metrics_git2net,
                 df_metrics_grimoire, df_metrics_kaiaulu)
df_metrics <- recode_projects_tools(df_metrics)

p <- plot_patterns(df_metrics, module_name = FALSE)

plot_save_path <- file.path("patterns", "patterns.pdf")
ggsave(plot_save_path, plot = p,
       width = TEXTWIDTH, height = 1.4*TEXTWIDTH, units = "in")
plot(p)

if (opt$tikz) {
  plot_save_path <- file.path("img-tikz", "patterns.tex")
  tikz(plot_save_path,
       width = TEXTWIDTH, height = 1.4*TEXTWIDTH)
  print(p)
  dev.off()
}

p <- plot_patterns(df_metrics, module_name = TRUE)

plot_save_path <- file.path("patterns", "patterns_module_names.pdf")
ggsave(plot_save_path, plot = p,
       width = TEXTWIDTH, height = 1.8*TEXTWIDTH, units = "in")
plot(p)

# Plot correlation tables.
df_corr_original <- load_corr_data(opt$repro_path, "original")
df_corr_codeface <- load_corr_data(paste0(opt$res_path, "/corr"), "codeface")
df_corr_git2net <- load_corr_data(paste0(opt$res_path, "/corr"), "git2net")
df_corr_grimoire <- load_corr_data(paste0(opt$res_path, "/corr"), "grimoire")
df_corr_kaiaulu <- load_corr_data(paste0(opt$res_path, "/corr"), "kaiaulu")
df_corr <- rbind(df_corr_original, df_corr_codeface, df_corr_git2net,
                 df_corr_grimoire, df_corr_kaiaulu)
df_corr <- recode_projects_tools(df_corr)

table_save_path <- file.path("corr", "corr_table.tex")
corr_table(df_corr, table_save_path)

# Plot correlation tables for filtered data.
df_corr_codeface_filtered <- load_corr_data(paste0(opt$res_path, "/corr"), "codeface", filter=TRUE)
df_corr_git2net_filtered <- load_corr_data(paste0(opt$res_path, "/corr"), "git2net", filter=TRUE)
df_corr_grimoire_filtered <- load_corr_data(paste0(opt$res_path, "/corr"), "grimoire", filter=TRUE)
df_corr_kaiaulu_filtered <- load_corr_data(paste0(opt$res_path, "/corr"), "kaiaulu", filter=TRUE)
df_corr <- rbind(df_corr_original, df_corr_codeface_filtered, df_corr_git2net_filtered,
                 df_corr_grimoire_filtered, df_corr_kaiaulu_filtered)
df_corr <- recode_projects_tools(df_corr)

table_save_path <- file.path("corr", "corr_table_filtered.tex")
corr_table(df_corr, table_save_path)

df_corr <- rbind(df_corr_original, df_corr_codeface, df_corr_git2net,
                 df_corr_grimoire, df_corr_kaiaulu)
df_corr <- recode_projects_tools(df_corr)

table_save_path <- file.path("corr", "corr_table.tex")
corr_table(df_corr, table_save_path)

# Evaluate result stability across replication tools.
result_stability_foucault(
  df_corr,
  save_path = file.path("corr", "foucault_result_stability.tex"),
  csv_path  = file.path("corr", "foucault_result_stability.csv"))
