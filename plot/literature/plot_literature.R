# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

# Plots the results of the literature review.
library(dplyr)
library(ggplot2)
library(tidyverse)
library(this.path)
library(treemapify)
library(scales)
library(colorspace)

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
              help="Path to the plot data set", metavar="character"),
  make_option(c("--tikz"), type="logical", default=FALSE, action="store_true",
              help="Plot the tikz graph")
); 

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);

#' Plots a tree map from the category data frame.
#'
#' @param df data frame with statistics per primary, secondary and tertiary category.
#' @return the tree map.
#'
tree_plot <- function(df) {
  # Define category colors.
  primary_colors <- c(
    "Software maintenance" = COLOURS.LIST[8],
    "Collaboration and coordination" = COLOURS.LIST[2],
    "Software quality" = COLOURS.LIST[6],
    "MSR techniques" = COLOURS.LIST[11],
    "Software architecture and design" = COLOURS.LIST[4],
    "Software governance" = COLOURS.LIST[5],
    "No MSR study" = COLOURS.LIST[3]
  )
  
  # Prepare data frame: Add fill color and adjust label text.
  df <- df %>%
    mutate(
      Primary  = ifelse(is.na(Primary) | Primary == "", " ", Primary),
      Secondary= ifelse(is.na(Secondary) | Secondary == "", " ", Secondary),
      Tertiary = ifelse(is.na(Tertiary) | Tertiary == "", " ", Tertiary),
      has_tertiary = Tertiary != " ",
      FillColor = case_when(
        Tertiary != " " ~ lighten(primary_colors[Primary], 0.6),  # Tertiary: lightest
        Secondary != " " ~ lighten(primary_colors[Primary], 0.3),  # Secondary: lighter
        TRUE ~ primary_colors[Primary]                  # Primary: normal
      ),
      Label = ifelse(Tertiary != " ", Tertiary, " ")
    )
  
  # Fix some formatting issues.
  df <- df %>%
    mutate(
      Primary = ifelse(Primary == "Software usage",
                       "Software\nusage",
                       Primary)
    )
  df <- df %>%
    mutate(
      Primary = ifelse(Primary == "Software quality",
                       "Software\nquality",
                       Primary)
    )
  df <- df %>%
    mutate(
      Primary = ifelse(Primary == "Software architecture and design",
                       "Software\narchitecture and\ndesign",
                       Primary)
    )
  df <- df %>%
    mutate(
      Primary = ifelse(Primary == "Development support and automation",
                       "Development support\nand automation",
                       Primary)
    )
  
  # Assemble the plot.
  p <- ggplot(df, aes(
    area = Count,
    subgroup = Primary,
    subgroup2 = Secondary
  )) +
    geom_treemap(aes(fill = FillColor), colour = "black", size = 0.8) +
    #geom_treemap_subgroup_border(aes(subgroup = Primary), colour = "black", size = 3) +
    
    # Primary label (horizontal, top-left)
    geom_treemap_subgroup_text(
      aes(subgroup = Primary, label = Primary),
      colour = "black",
      place = "topleft",
      angle = 0,
      grow = FALSE,
      size = 10,
      reflow = TRUE,
      fontface = "bold.italic"
    ) +
    
    # Secondary label (bottom of secondary tile)
    geom_treemap_subgroup2_text(
      aes(subgroup2 = Secondary, label = Secondary),
      colour = "black",
      place = "bottom",
      angle = 0,
      grow = FALSE,
      size = 8.5,
      reflow = TRUE,
      fontface = "bold"
    ) +
    
    # Tertiary label (vertical inside tertiary tile)
    geom_treemap_text(
      aes(label = Label),
      colour = "black",
      place = "topright",
      angle = 90,
      grow = FALSE,
      size = 7,
      reflow = TRUE
    ) + 
    
    # # Count label
    # geom_treemap_text(
    #   aes(label = Count),
    #   colour = "black",
    #   place = "center",
    #   grow = FALSE,
    #   reflow = TRUE,
    #   size = 5
    # ) +
    
    scale_fill_identity(guide = "none") +
    theme_paper_base() + 
    theme(legend.position = "none",
          axis.title = element_blank(),
          axis.text = element_blank(),
          axis.ticks = element_blank(),
          panel.grid = element_blank(),
          plot.margin = unit(c(0.05, 0.05, 0.05, 0.05), "cm"))
}


# Plot tree map.
df <- read.csv(opt$res_path, stringsAsFactors = FALSE)
p <- tree_plot(df)
ggsave("research_topic_popularity.pdf", plot = p, width = TEXTWIDTH, height = 1.4*TEXTWIDTH, units = "in")
if (opt$tikz) {
  plot_save_path <- file.path("img-tikz", "research_topic_popularity.tex")
  tikz(plot_save_path, width = TEXTWIDTH, height = 1.3*TEXTWIDTH)
  print(p)
  dev.off()
}
