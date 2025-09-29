# SPDX-FileCopyrightText: 2025 OTH Regensburg
# SPDX-License-Identifier: GPL-2.0-only

INCH.PER.CM <- 1/2.54
TEXTWIDTH <- 18.13275*INCH.PER.CM
COLWIDTH <- 8.85553*INCH.PER.CM
HEIGHT <- 23.61475*INCH.PER.CM
BASE.SIZE <- 8.5
SMALL.SIZE <- 6.5
TINY.SIZE <- 5.5 #
TABLE.FONT.SIZE <- 2 #
SYM.SIZE <- 1.2 # Symbol size in legends
LINE.SIZE <- 0.6 # 1
LINE.SIZE.THIN <- 0.3
POINT.SIZE <- 0.5
BIG.POINT.SIZE <- 0.8
COLOURS.LIST <- c("black", "#E69F00", "#999999", "#009371", "#ECACCA",
                  "#1f78b4", "#009371", "#beaed4", "#3089c5", "#BBBBBB",
                  "#CCCCCC", "#808080", "#D996B6", "#ED665A")

theme_paper_base <- function() {
  return(theme_bw(base_size=BASE.SIZE) +
           theme(axis.title.x = element_text(size = BASE.SIZE),
                 axis.title.y = element_text(size = BASE.SIZE),
                 legend.title = element_text(size = BASE.SIZE),
                 legend.position = "top",
                 plot.margin = unit(c(0,0.1,0,0.1), 'cm')))
}

theme_paper_base_no_shrink <- function() {
  return(theme_bw(base_size=BASE.SIZE) +
           theme(axis.title.x = element_text(size = BASE.SIZE),
                 axis.title.y = element_text(size = BASE.SIZE),
                 legend.title = element_text(size = BASE.SIZE),
                 legend.position = "top",
                 plot.margin = unit(c(0,0.05,0,0.1), 'cm')))
}

theme_paper_legend_right <- function() {
  return(theme_bw(base_size=BASE.SIZE) +
           theme(axis.title.x = element_text(size = BASE.SIZE),
                 axis.title.y = element_text(size = BASE.SIZE),
                 legend.title = element_text(size = BASE.SIZE),
                 legend.position = "right",
                 plot.margin = unit(c(0,0,0,0.1), 'cm')))
}

theme_paper_no_legend <- function() {
  return(theme_bw(base_size=BASE.SIZE) +
           theme(axis.title.x = element_text(size = BASE.SIZE),
                 axis.title.y = element_text(size = BASE.SIZE),
                 legend.position = "none",
                 plot.margin = unit(c(0,0,0,0.1), 'cm')))
}

theme_paper_no_legend_small <- function() {
  return(theme_bw(base_size=SMALL.SIZE) +
           theme(axis.title.x = element_text(size = SMALL.SIZE),
                 axis.title.y = element_text(size = SMALL.SIZE),
                 legend.position = "none",
                 plot.margin = unit(c(0,0,0,0.1), 'cm')))
}


shrink_legend <- function(boxc=-5) {
  return(theme(legend.margin=margin(0,0,0,0),
               legend.box.margin=margin(boxc,boxc,boxc,boxc)))
}

