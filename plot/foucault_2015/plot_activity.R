# Calculates and plots contributor activity based on the original functions from 
# Foucault et al., 2015. (https://github.com/matthieu-foucault/RdeveloperTurnover)

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

#' Original function by Foucault et al. to plot the developer turnover 
#' time series.
#' 
#' @param commit_dates the data frame with the commit activity time series.
#' @param tool the replication tool based on which the data set was created.
#'
plot_turnover_evolution = function(commit_dates, tool) {
  releases_dates = new.env(hash=T, parent=emptyenv())
  releases_dates[["jquery"]] = as.Date("2012-08-09")
  releases_dates[["rails"]] = as.Date("2009-03-15")
  releases_dates[["jenkins"]] = as.Date("2013-04-01")
  releases_dates[["ansible"]] = as.Date("2014-02-28")
  releases_dates[["angular_js"]] = as.Date("2012-06-14")
  
  dir.create(paste0("evol"), showWarnings =T)
  s = by(commit_dates, commit_dates$project, function(commit_dates_proj) {
    first = min(commit_dates_proj$time) + 182
    last = max(commit_dates_proj$time) - 182
    all_stayers = NULL
    stayers_leavers = NULL
    
    evol = do.call(rbind, lapply(seq(first, last, 15), function(t) {
      devsbefore = unique(subset(commit_dates_proj, time < t & time > (t - 182))$author)
      devsafter = unique(subset(commit_dates_proj, time > t & time < (t + 182))$author)
      
      stayers = intersect(devsbefore,devsafter)
      all_stayers <<- c(all_stayers, stayers)
      stayers_leavers <<- c(stayers_leavers, setdiff(all_stayers, stayers))
      all = unique(union(devsbefore,devsafter))
      newcomers = setdiff(devsafter, devsbefore)
      leavers = setdiff(devsbefore, devsafter)
      data.frame(time = t + 182, tot = length(all), s = length(stayers), n = length(newcomers), l = length(leavers))
    }))
      
    name_p = commit_dates_proj$project[1]
    write.csv(evol, paste0("evol/", tool, "_evol-",name_p,".csv"))
    
    cairo_pdf(paste0("evol/", tool, "_evol-",name_p,".pdf"),width=5, height=5)
    par(mar=c(2,2,2,1), cex =1.5)
    lw = 5
    plot(evol$time, evol$tot,
           col="#377eb8", type="l", lwd=lw, main=name_p, ylab="#developers",
           xlab="Date", ylim= c(0, max(evol$tot)))
    lines(evol$time, evol$l, col="#e41a1c", lty=2, lwd=lw)
    lines(evol$time, evol$n, col="#4daf4a", lty=15, lwd=lw)
    lines(evol$time, evol$s, col="#984ea3", lty=1, lwd=lw)
    abline(v=releases_dates[[name_p]], lty=2)
    dev.off()
      
    cairo_pdf(paste0("evol/", tool, "_evol-",name_p,"-ratio.pdf"),width=5, height=5)
    par(mar=c(2,2,2,1), cex =1.5)
    lw = 5
    plot(evol$time, (evol$l+evol$n)/evol$tot, col="#e41a1c", type="l", lwd=lw, main=name_p, ylab="#developers",
         xlab="Date", ylim= c(0, 1))
    lines(evol$time, evol$s/evol$tot, col="#984ea3", lty=1, lwd=lw)
    abline(v=releases_dates[[name_p]], lty=2)
    dev.off()
  })
}

# Read original commit data set.
df_original <- data.frame(read_csv(path.join(opt$repro_path, "commit_dates.csv")))

# Read replicated commit data.
df_codeface <- data.frame(read_csv(path.join(opt$res_path, "codeface",
                                             "commit_dates.csv")))
df_git2net <- data.frame(read_csv(path.join(opt$res_path, "git2net",
                                            "commit_dates.csv")))
df_grimoire <- data.frame(read_csv(path.join(opt$res_path, "grimoire",
                                             "commit_dates.csv")))
df_kaiaulu <- data.frame(read_csv(path.join(opt$res_path, "kaiaulu",
                                            "commit_dates.csv")))

plot_turnover_evolution(df_codeface, "codeface")
plot_turnover_evolution(df_git2net, "git2net")
plot_turnover_evolution(df_grimoire, "grimoire")
plot_turnover_evolution(df_kaiaulu, "kaiaulu")
