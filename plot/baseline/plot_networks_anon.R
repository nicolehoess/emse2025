# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

# Plots the developer networks for comparison across tools.
library(conflicted)  
library(cowplot)
library(dplyr)
library(digest)
library(ggplot2)
library(ggh4x) # devtools::install_github("teunbrand/ggh4x")
library(ggnetwork)
library(ggrepel)
options(ggrepel.max.overlaps = Inf)

library(gridExtra)
library(igraph)
library(network)
library(patchwork)
library(scales)
library(sna)
library(tibble)
library(tidyverse)
library(this.path)

setwd(this.path::here())
source("layout.R", chdir=TRUE)

library(tikzDevice)
options(tikzLatexPackages = c(getOption("tikzLatexPackages"),
                              "\\usepackage{amsmath}"))

library("optparse")

Sys.setenv(LANG = "en_US.UTF-8")
Sys.setlocale("LC_ALL", "en_US.UTF-8")
Sys.setenv(TZ = "UTC")


option_list = list(
  make_option(c("--res_path"), type="character", default=NULL,
              help="Path to the baseline data analysis results directory",
              metavar="character"),
  make_option(c("--projects"), type="character", default=NULL,
              help="List of projects to compare",
              metavar="character"),
  make_option(c("--tikz"), type="logical", default=FALSE, action="store_true",
              help="Plot the tikz graph")
); 

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);


#' Shortens a given developer identity to first and last name.
#'
#' @param plot_data_path the full developer identity including e-mail addresses.
#' @return the shortened name.
#' 
shorten_name <- function(s) {
  l <- strsplit(s, split="<")
  name <- trimws(l[[1]][1])
  name <- str_replace_all(name, "[^[:alnum:][:space:].']", "")
  return(name)
}

#' Replaces all developer identities by their short form (first and last name)
#'
#' @param df the data frame with full developer identities including e-mail addresses.
#' @return the updated data frame with short names.
#' 
replace_names <- function(df) {
  names_old <- colnames(df)
  names_new <- lapply(names_old, shorten_name)
  colnames(df) <- names_new
  df[,1] <- colnames(df[2:length(colnames(df))])
  return(df)
}

#' Anonymise (pseudonymise) all developer identities.
#'
#' @param df the data frame with the real developer identities of all tools.
#' @return the updated data frame with anonymised (pseudonymised) identities.
#' 
anonymise_names <- function(df) {
  # Generate pseudonyms for all identities.
  pseudonym_from_hash <- function(name, n_syllables = 4) {
    # Split full names into parts for pseudonymisation.
    name_trim <- trimws(name)
    parts <- unlist(strsplit(name_trim, "\\s+"))  # split on whitespace
    
    # Convert identity to lower case to ensure e.g. John and john get
    # the same pseudonym.
    name_lower <- tolower(name)
    
    syllables <- c(
      "la","le","li","lo","lu","ba","be","bi","bo","bu",
      "da","de","di","do","du","ma","me","mi","mo","mu",
      "ra","re","ri","ro","ru","sa","se","si","so","su",
      "na","ne","ni","no","nu","ka","ke","ki","ko","ku",
      "ta","te","ti","to","tu","pa","pe","pi","po","pu",
      "fa","fe","fi","fo","fu","za","ze","zi","zo","zu",
      "ja","je","ji","jo","ju","sha","she","shi","sho","shu",
      "cha","che","chi","cho","chu","tra","tre","tri","tro","tru",
      "gra","gre","gri","gro","gru"
    )
    
    # Pseudonymise each string part.
    pseudonymise_part <- function(part) {
      # Save the capitalisation info to illustrate differences in spelling.
      first_upper <- grepl("^[A-Z]", part)
      part_lower <- tolower(part)
      
      # Hash and map to syllables
      h <- digest(part_lower, algo = "sha256")
      
      # Convert the hash into integer values.
      hex_vals <- strtoi(strsplit(h, "")[[1]], 16L)
      
      # Repeat the vector to ensure that there are enough digits to randomise
      # syllables from the entire list.
      extended <- rep(hex_vals, length.out = n_syllables * 2)
      
      # Take a different pair of hex digits to sample from
      # the syllables.
      pseudonym <- sapply(seq_len(n_syllables), function(i) {
        # Combine two digits to determine the syllable index.
        val <- extended[2*i - 1]*16 + extended[2*i]
        # Select the syllable from the list.
        syllables[(val %% length(syllables)) + 1]
      })
      
      # Combine syllables to a single name.
      pseudonym <- paste0(pseudonym, collapse = "")
      
      # Restore capitalisation info.
      if (first_upper) {
        substr(pseudonym,1,1) <- toupper(substr(pseudonym,1,1))
      }
      
      pseudonym
    }
    pseudonym <- sapply(parts, pseudonymise_part)
    
    # Concatenate pseudonym parts.
    paste(pseudonym, collapse = " ")
  }
  
  pseudonym <- sapply(df$dev_id, pseudonym_from_hash)
  
  # Create mapping data frame.
  dev_id_df <- data.frame(tool = df$tool, original = df$dev_id, 
                          pseudonym = pseudonym)
  return(dev_id_df)  
}

#' Formats a given adjacency matrix to an edge list.
#'
#' @param df the data frame in adjacency matrix format.
#' @return the data frame in edge list format.
#' 
format_df <- function(df){
  df <- replace_names(df)
  colnames(df)[1] <- "Var1"
  df <- pivot_longer(df, cols=-Var1,
                     names_to="Var2", values_to="Weight")
  return(df)
}

#' Converts an adjacency matrix data frame into a data matrix.
#'
#' @param df the data frame in adjacency matrix format.
#' @return the data matrix.
#' 
format_matrix <- function(df) {
  rownames(df) <- df[,1]
  df[,1] <- NULL
  matrix <- data.matrix(df)
  return(matrix)
}

# Plot graph.
plot_network <- function(g, tool) {
  # Tool-specific node coloring
  if (tool == "Codeface") {
    main_color <- COLOURS.LIST[2]
  } else if (tool == "git2net") {
    main_color <- COLOURS.LIST[4]
  } else if (tool == "GrimoireLab") {
    main_color <- COLOURS.LIST[8]
  } else if (tool == "Kaiaulu") {
    main_color <- COLOURS.LIST[6]
  }
  m <- margin(c(0,0,10,0))
  r <- c(1,5)

  V(g)$size <- igraph::degree(g)
  
  if (tool == "Codeface" || tool == "GrimoireLab" || tool == "Kaiaulu") {
    E(g)$weight_unscaled <- E(g)$weight
    E(g)$weight <- E(g)$weight / max(E(g)$weight)
  }
  
  # Adjust the graph layout.
  lo <- igraph::layout_in_circle(g)
  lo <- norm_coords(lo, ymin=-1, ymax=1, xmin=-1, xmax=1)
  
  # Convert igraph to ggnetwork plot.
  gnet <- ggnetwork(g, layout=lo)
  
  if (gsize(g) > 0 && (tool == "Codeface" || tool == "Kaiaulu")) {
    p <- ggplot(gnet, aes(x, y, xend = xend, yend = yend)) +
      geom_edges(color = COLOURS.LIST[12], linewidth=0.25, curvature = 0.3,
                 arrow = arrow(length = unit(4, "pt"), type = "closed")) +
      geom_edgetext(aes(label = weight_unscaled), color = COLOURS.LIST[3], size=1.6) +
      xlab(tool) +
      geom_nodes(aes(color = main_color, size=size)) +
      scale_color_manual(values = c(main_color, COLOURS.LIST[5])) +
      scale_size_continuous(range = r) +
      geom_nodelabel_repel(aes(label = name), color=COLOURS.LIST[10],
                           box.padding = unit(0.5, "lines"), size=2.5) +
      theme_paper_base() +
      theme(axis.line=element_blank(),
            axis.text.x=element_blank(),
            axis.text.y=element_blank(),
            axis.ticks=element_blank(),
            axis.title.x=element_text(size=SMALL.SIZE*1.6),
            axis.title.y=element_blank(),
            panel.background = element_rect(fill="white"),
            panel.grid = element_blank(),
            panel.border = element_blank(),
            legend.text = element_blank(),
            legend.title = element_blank(),
            legend.position = "none",
            plot.margin = m)
  } else if (gsize(g) > 0 && tool == "git2net") {
    p <- ggplot(gnet, aes(x, y, xend = xend, yend = yend)) +
      geom_edges(color = COLOURS.LIST[12], linewidth=0.25, curvature = 0.3, 
                 arrow = arrow(length = unit(4, "pt"), type = "closed")) +
      xlab(tool) +
      geom_nodes(aes(color = main_color, size=size)) +
      scale_color_manual(values = c(main_color, COLOURS.LIST[4])) +
      scale_size_continuous(range = r) +
      geom_nodelabel_repel(aes(label = name), color=COLOURS.LIST[10],
                           box.padding = unit(0.5, "lines"), size=2.5, max.overlaps = 15) +
      theme_paper_base() +
      theme(axis.line=element_blank(),
            axis.text.x=element_blank(),
            axis.text.y=element_blank(),
            axis.ticks=element_blank(),
            axis.title.x=element_text(size=SMALL.SIZE*1.6),
            axis.title.y=element_blank(),
            panel.background = element_rect(fill="white"),
            panel.grid = element_blank(),
            panel.border = element_blank(),
            legend.text = element_blank(),
            legend.title = element_blank(),
            legend.position = "none",
            plot.margin = m)
  } else if (gsize(g) > 0 && tool == "GrimoireLab") {
    p <- ggplot(gnet, aes(x, y, xend = xend, yend = yend)) +
      geom_edges(color = COLOURS.LIST[12], linewidth=0.25, curvature = 0.3) +
      geom_edgetext(aes(label = weight_unscaled), color = COLOURS.LIST[3], size=2) +
      xlab(tool) +
      geom_nodes(aes(color = main_color, size=size)) +
      scale_color_manual(values = c(main_color, COLOURS.LIST[5])) +
      scale_size_continuous(range = r) +
      geom_nodelabel_repel(aes(label = name), color=COLOURS.LIST[10],
                           box.padding = unit(0.5, "lines"), size=2.5) +
      theme_paper_base() +
      theme(axis.line=element_blank(),
            axis.text.x=element_blank(),
            axis.text.y=element_blank(),
            axis.ticks=element_blank(),
            axis.title.x=element_text(size=SMALL.SIZE*1.6),
            axis.title.y=element_blank(),
            panel.background = element_rect(fill="white"),
            panel.grid = element_blank(),
            panel.border = element_blank(),
            legend.text = element_blank(),
            legend.title = element_blank(),
            legend.position = "none",
            plot.margin = m)
  } else {
    p <- ggplot(gnet, aes(x, y, xend = xend, yend = yend)) +
      xlab(tool) +
      geom_nodes(aes(color = main_color, size=size)) +
      scale_color_manual(values = c(main_color, COLOURS.LIST[5])) +
      scale_size_continuous(range = r) +
      geom_nodelabel_repel(aes(label = name), color=COLOURS.LIST[10],
                           box.padding = unit(0.7, "lines"), size=2.5) +
      theme_paper_base() +
      theme(axis.line=element_blank(),
            axis.text.x=element_blank(),
            axis.text.y=element_blank(),
            axis.ticks=element_blank(),
            axis.title.x=element_text(size=SMALL.SIZE*1.6),
            axis.title.y=element_blank(),
            panel.background = element_rect(fill="white"),
            panel.grid = element_blank(),
            panel.border = element_blank(),
            legend.text = element_blank(),
            legend.title = element_blank(),
            legend.position = "none",
            plot.margin = m)
  }
  return(p)
}


# Plot exemplaric developer networks.
dir.create("networks", recursive = TRUE, showWarnings = FALSE)

projects <- strsplit(opt$projects, ", ")[[1]]
for (p in projects) {
  if (!dir.exists(path.join(opt$res_path, "codeface", p))) {
    next  # Skip if the project was not analysed.
  }

  ref_path = file.path(opt$res_path, "codeface", p, "proximity")
  
  # Get ranges.
  subdirs <- basename(list.dirs(path = ref_path, full.names = FALSE, recursive = FALSE))
  #subdirs <- subdirs[grepl("^[0-9]", subdirs)]
  #ranges <- sub("^([0-9]+)--.*$", "\\1", subdirs)
  # We focus on the first five ranges due to network size.
  ranges <- c("1", "2", "3", "4", "5")
  
  codeface_path = file.path(opt$res_path, "codeface", p, "proximity", "networks")
  kaiaulu_path <- file.path(opt$res_path, "kaiaulu", "procdata", p, "networks")
  git2net_path <- file.path(opt$res_path, "git2net", p, "line", "coediting")
  grimoire_path <- file.path(opt$res_path, "grimoire", p, "networks")
  for (r in ranges) {
    # Read adjacency matrics.
    # Codeface.
    adj_path_codeface <- file.path(codeface_path, paste0("range_", r, "_adjacency_matrix_with_names.csv"))
    adj_codeface <- read.csv(adj_path_codeface, header=TRUE, check.names=FALSE, encoding = "latin-1")
    adj_codeface <- replace_names(adj_codeface)
    
    # git2net.
    edgelist_path_git2net <- file.path(git2net_path, paste0("range_", r, "_edgelist_with_names.csv"))
    edgelist_git2net <- read.csv(edgelist_path_git2net, header=TRUE, check.names=FALSE, encoding = "latin-1")
    edgelist_git2net$source <- sapply(edgelist_git2net$source, shorten_name)
    edgelist_git2net$target <- sapply(edgelist_git2net$target, shorten_name)
    
    # GrimoireLab.
    adj_path_grimoire <- file.path(grimoire_path, paste0("range_", r, "_adjacency_matrix_with_names.csv"))
    adj_grimoire <- read.csv(adj_path_grimoire, header=TRUE, check.names = FALSE, encoding = "latin-1")
    adj_grimoire <- replace_names(adj_grimoire)
    
    # Kaiaulu.
    adj_path_kaiaulu <- file.path(kaiaulu_path, paste0("range_", r, "_adjacency_matrix.csv"))
    adj_kaiaulu <- read.csv(adj_path_kaiaulu, header=TRUE, check.names=FALSE, encoding = "latin-1")
    adj_kaiaulu <- replace_names(adj_kaiaulu)
    
    # Merge all names into a single data frame.
    names_codeface <- data.frame(dev_id = adj_codeface[, 1], tool = "codeface")
    names_git2net_source <- data.frame(dev_id = edgelist_git2net$source, tool = "git2net_source")
    names_git2net_target <- data.frame(dev_id = edgelist_git2net$target, tool = "git2net_target")
    names_grimoire <- data.frame(dev_id = adj_grimoire[, 1], tool = "grimoire")
    names_kaiaulu <- data.frame(dev_id = adj_kaiaulu[, 1], tool = "kaiaulu")
    pseudonym_df <- rbind(names_codeface, names_git2net_source, names_git2net_target,
                      names_grimoire, names_kaiaulu)
    
    # Anonymise (pseudonymise) names.
    pseudonym_df <- anonymise_names(pseudonym_df)
    #write.csv(pseudonym_df, paste0("names_", p, "_range_", r, ".csv"), row.names = FALSE)
    
    # Replace names according to mapping.
    adj_codeface[[1]] <- pseudonym_df$pseudonym[sapply(pseudonym_df$tool, function(x) all(x == "codeface"))]
    colnames(adj_codeface) <- c(NA, pseudonym_df$pseudonym[sapply(pseudonym_df$tool, function(x) all(x == "codeface"))])
    edgelist_git2net$source <-pseudonym_df$pseudonym[sapply(pseudonym_df$tool, function(x) all(x == "git2net_source"))]
    edgelist_git2net$target <-pseudonym_df$pseudonym[sapply(pseudonym_df$tool, function(x) all(x == "git2net_target"))]
    adj_grimoire[[1]] <- pseudonym_df$pseudonym[sapply(pseudonym_df$tool, function(x) all(x == "grimoire"))]
    colnames(adj_grimoire) <- c(NA, pseudonym_df$pseudonym[sapply(pseudonym_df$tool, function(x) all(x == "grimoire"))])
    adj_kaiaulu[[1]] <- pseudonym_df$pseudonym[sapply(pseudonym_df$tool, function(x) all(x == "kaiaulu"))]
    colnames(adj_kaiaulu) <- c(NA, pseudonym_df$pseudonym[sapply(pseudonym_df$tool, function(x) all(x == "kaiaulu"))])
    
    # Codeface directed developer network.
    matrix_codeface <- format_matrix(adj_codeface)
    g_codeface <- igraph::graph_from_adjacency_matrix(matrix_codeface, mode = "directed", weighted = TRUE)
    p_codeface <- plot_network(g_codeface, "Codeface")

    # git2net directed multi-edge graph.
    g_git2net <- igraph::graph_from_data_frame(edgelist_git2net, directed = TRUE)
    p_git2net <- plot_network(g_git2net, "git2net")

    # GrimoireLab undirected network graph.
    matrix_grimoire <- format_matrix(adj_grimoire)
    g_grimoire <- igraph::graph_from_adjacency_matrix(matrix_grimoire, weighted = TRUE)
    p_grimoire <- plot_network(g_grimoire, "GrimoireLab")

    # Kaiaulu directed developer network.
    matrix_kaiaulu <- format_matrix(adj_kaiaulu)
    g_kaiaulu <- igraph::graph_from_adjacency_matrix(matrix_kaiaulu, mode = "directed", weighted = TRUE)

    p_kaiaulu <- plot_network(g_kaiaulu, "Kaiaulu")

    # Combine plots.
    p_all <- p_codeface + p_git2net + p_grimoire + p_kaiaulu + plot_layout(ncol = 2, nrow = 2)

    plot_save_path <- file.path("networks", paste0("network_graphs_", p, "_range_", r, ".pdf"))
    ggsave(plot_save_path, plot = p_all,
           width = 1*TEXTWIDTH, height = 1.1*TEXTWIDTH, units = "in")
    plot(p_all)

    if (opt$tikz) {
      plot_save_path <- file.path("img-tikz", paste0("network_graphs_", p, "_range_", r, ".tex"))
      tikz(plot_save_path,
           width = 1*TEXTWIDTH, height = 1.1*TEXTWIDTH)
      print(p_all)
      dev.off()
    }
  }
}
