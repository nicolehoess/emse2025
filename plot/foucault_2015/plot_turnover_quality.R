# Calculates and plots turnover and quality metrics based on the original 
# functions from Foucault et al., 2015 (# Foucault et al., 2015. (https://github.com/matthieu-foucault/RdeveloperTurnover)

Sys.setenv(LANG = "en")
Sys.setenv(TZ = "UTC")

library(boot)
library(broom)
library(conflicted)
conflicts_prefer(dplyr::filter)
conflicts_prefer(dplyr::select)
library(dplyr)
library(ggplot2)
library(gplots)
library(ggh4x) # devtools::install_github("teunbrand/ggh4x")
library(gridExtra)
library(htmlTable)
library(kableExtra)
library(knitr)
library(patchwork)
library(purrr)
library(psych)
library(RColorBrewer)
library(relaimpo)
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

#' Original function by Foucault et al. to compute the contributions for the
#' time periods before and after release for a given project and period size.
#' 
#' @param act_months_before the activity metrics data frame for the months before release.
#' @param act_months_after the activity metrics data frame for the months after release.
#' @param project_url the name of the subject project.
#' @param period_month_size the time interval size.
#' @return the list of contributions during the time interval of interest.
#'
get_contributions = function(act_months_before, act_months_after, project_url, period_month_size = 0) {
  contribs_before = subset(act_months_before, project == project_url & commits_group_id <= period_month_size )
  contribs_after = subset(act_months_after, project == project_url & commits_group_id <= period_month_size )
  list(before=contribs_before, after=contribs_after)
}

#' Original function by Foucault et al. to classify developers into internal
#' and external newcomers, stayers and leavers.
#' 
#' @param contribs_mod_before the data frame with contributions to modules before release.
#' @param contribs_mod_after the data frame with contributions to modules after release.
#' @param contribs_proj_before the data frame with contributions to the project before release.
#' @param contribs_proj_after the data frame with contributions to the project after release.
#' @return the list with contributor types.
#'
developer_sets = function(contribs_mod_before, contribs_mod_after, contribs_proj_before, contribs_proj_after) {
  leavers = subset(contribs_mod_before,!(developer %in% contribs_mod_after$developer))
  newcomers = subset(contribs_mod_after,!(developer %in% contribs_mod_before$developer))
  
  ext_newcomers = subset(newcomers, !(developer %in% contribs_proj_before$developer))
  int_newcomers = subset(newcomers, developer %in% contribs_proj_before$developer)
  
  ext_leavers = subset(leavers, !(developer %in% contribs_proj_after$developer))
  int_leavers = subset(leavers, developer %in% contribs_proj_after$developer)
  
  stayers = merge(contribs_mod_after, contribs_mod_before,
                  by="developer", all=F, suffixes=c(".after",".before"))
  
  list(L = leavers,
       N = newcomers,
       EN = ext_newcomers,
       IN = int_newcomers,
       EL = ext_leavers,
       IL = int_leavers,
       St = stayers)
}

#' Original function by Foucault et al. to calculate activity per contributor type
#' for a given module.
#' 
#' @param contribs_mod_before the data frame with contributions to a specific module before release.
#' @param contribs_mod_after the data frame with contributions to a specific module after release.
#' @param contribs_proj_before the data frame with contributions to the project before release.
#' @param contribs_proj_after the data frame with contributions to the project after release.
#' @param module the name of the module.
#' @return the contributor type activity rates.
#'
turnover_metrics = function(contribs_mod_before, contribs_mod_after, contribs_proj_before, contribs_proj_after, module) {
  sets = developer_sets(contribs_mod_before, contribs_mod_after, contribs_proj_before, contribs_proj_after)
  
  devs = function(x) {if (nrow(x) == 0) character(0) else unique(x$developer)}
  ndev = function(x) {length(devs(x))}
  
  ndev_before = ndev(contribs_mod_before)
  ndev_after = ndev(contribs_mod_after)
  
  res = data.frame(module=module, project=contribs_proj_before$project[1],
                   NumDevsP2 = ndev_after,
                   NumDevsP1 = ndev_before,
                   NumDevsMean = mean(c(ndev_before,ndev_after)),
                   ENA = sum(sets$EN$churn),
                   ELA = sum(sets$EL$churn),
                   INA = sum(sets$IN$churn),
                   ILA = sum(sets$IL$churn),
                   StA = sum(rowMeans(sets$S[,c("churn.after","churn.before")]))
  )
  
  #res[is.nan(res)] = 0
  res$A = rowSums(res[,c("ENA", "INA","ILA","ELA", "StA")])
  res
}

#' Original function by Foucault et al. to calculate contributor activity rates 
#' for all modules of a project.
#' 
#' @param contribs the contributions data frame.
#' @return the contributor type activity rates for all modules.
#'
turnover_metrics_project = function(contribs) {
  do.call(rbind, lapply(unique(c(contribs$before$module, contribs$after$module)), function(mod) {
    contribs_mod_before = subset(contribs$before, module == mod)
    contribs_mod_after = subset(contribs$after, module == mod)
    turnover_metrics(contribs_mod_before, contribs_mod_after, contribs$before, contribs$after, mod)
  }))
}

#' Formats the confidence interval.
#' 
#' @param x lower end.
#' @param y upper end.
#' @return the formatted confidence interval string.
#'
cor.string = function(x, y) {
  bootresult = boot(data.frame(x=x,y=y), function(df, idx) {with(df[idx,], cor.test(x,y, method="spearman")$estimate)}, R = 1000)
  ci = boot.ci(bootresult, type="bca", conf = 0.90)
  
  s = paste0("[", as.numeric(round(ci$bca[4],2)), " , ", as.numeric(round(ci$bca[5],2)) , "]")
}

#' Original function by Foucault et al. to conduct simple Spearman's correlation
#' tests across metrics.
#' 
#' @param metrics the metric values data frame.
#' @param metrics_names the names of the turnover metrics.
#' @param projects_names the names of the subject projects.
#' @param dep_variable the quality metric.
#' @return the correlations and p-values data frame.
#'
spearman_tests = function(metrics, metrics_names, projects_names, dep_variable="BugDensity") {
  do.call(rbind, by(metrics, metrics$project, function(metrics_p) {
    if (nrow(metrics_p) < 10) return()
    
    project_name = metrics_p$project[1]
    
    do.call(rbind,lapply(metrics_names, function(metric_name){
      test = cor.test(metrics_p[,metric_name],metrics_p[,dep_variable], method="spearman")
      data.frame(project=project_name, metric=metric_name, spearman_estimate = test$estimate, spearman_pvalue = test$p.value )
    }))
  }))
}

#' Original function by Foucault et al. to compute confidence intervals for
#' Spearman's correlation coefficients using bootstrapping.
#' 
#' @param metrics the metric values data frame.
#' @param metrics_names the names of the turnover metrics.
#' @param projects_names the names of the subject projects.
#' @param dep_variable the quality metric.
#' @return the confidence intervals data frame.
#'
spearman_bootstrap = function(metrics, metrics_names, projects_names, dep_variable="BugDensity") {
  do.call(rbind, by(metrics, metrics$project, function(metrics_p) {
    if (nrow(metrics_p) < 10) return()
    if (nrow(metrics_p[metrics_p$BugDensity > 0, ]) == 0) return()
    
    project_name = metrics_p$project[1]
    
    do.call(rbind,lapply(metrics_names, function(metric_name){
      bootresult = boot(data.frame(x=metrics_p[,metric_name],y=metrics_p[,dep_variable]),
                        function(df, idx) {with(df[idx,], cor.test(x,y, method="spearman")$estimate)}, R = 1000)
      ci_90 = boot.ci(bootresult, type="bca", conf = 0.90)
      ci_95 = boot.ci(bootresult, type="bca", conf = 0.95)
      data.frame(project=project_name, metric=metric_name, lo_90 = ci_90$bca[4], hi_90 = ci_90$bca[5],
                 lo_95 = ci_95$bca[4], hi_95 = ci_95$bca[5])
    }))
  }))
}

#' Original function by Foucault et al. to compute Spearman's correlation
#' coefficients across module turnover metrics and quality.
#' 
#' @param mod_m the module metrics data frame.
#' @param act_months_before the activity metrics data frame for the months before release.
#' @param act_months_after the activity metrics data frame for the months after release.
#' @param tool the replication tool based on which the data set was created.
#' @param filter whether the aditionally filtered version of the data frame is used.
#'
compute_correlations = function(mod_m, act_months_before, act_months_after, tool, filter = FALSE) {
  projects_names = c("angular_js", "ansible", "jenkins", "jquery", "rails")
  
  # Turnover metrics
  dir.create(paste0("metrics"), showWarnings =T)
  compute_metrics = function(period_month_size) {
    do.call(rbind, lapply(projects_names, function(project_url) {
      contribs = get_contributions(act_months_before, act_months_after, project_url, period_month_size)
      turnover_metrics_project(contribs)
    }))
  }
  metrics_6m = merge(mod_m, compute_metrics(6), by = c("module","project"), all=F)
  metrics = metrics_6m
  if (filter == TRUE) {
    write.csv(metrics_6m, paste0("metrics/", tool, "_metrics_6m_filtered.csv"), quote = TRUE)
  } else {
    write.csv(metrics_6m, paste0("metrics/", tool, "_metrics_6m.csv"), quote = TRUE)
  }
  
  # Correlation tables
  dir.create(paste0("corr"), showWarnings =T)
  mnames = c("INA","ILA","ENA","ELA","StA", "A")
  compute_cor = function(metr, html=F) {
    do.call(rbind, by(metr, metr$project, function(metrics_p) {
      if (nrow(metrics_p) < 10) return()
      if (nrow(metrics_p[metrics_p$BugDensity > 0, ]) == 0) return()
      
      c(metrics_p$project[1],lapply(metrics_p[,mnames], function(x){
        cor.string(metrics_p$BugDensity, x)
      }))
    }))
  }
  corr_data = merge(spearman_tests(metrics_6m, mnames, projects_names), spearman_bootstrap(metrics_6m, mnames, projects_names))
  if (filter == TRUE) {
    write.csv(corr_data, paste0("corr/", tool, "_corr_data_filtered.csv"), row.names = FALSE)
  } else {
    write.csv(corr_data, paste0("corr/", tool, "_corr_data.csv"), row.names = FALSE)
  }

  by(corr_data, corr_data$metric, function(corr_metric) {
    if (filter == TRUE) {
      cairo_pdf(paste0("corr/", tool, "_corr_", corr_metric$metric[1],"_filtered.pdf"), width = 5, height = 5)
    } else {
      cairo_pdf(paste0("corr/", tool, "_corr_", corr_metric$metric[1],".pdf"), width = 5, height = 5)
    }
    
    print(
      ggplot(corr_metric, aes(project, spearman_estimate, ymin=lo_90, ymax=hi_90)) +
        geom_point(size=3, color="#0000CC") + geom_errorbar(width=0.25, color="#0000CC") + geom_abline(slope=0, intercept=0, lty=2) +
        geom_errorbar(data=corr_metric, aes(project, spearman_estimate, ymin=lo_95, ymax=hi_95), width=0.5, color="#0000CC") +
        ylim(c(-1,1)) + theme_bw() + labs(title=corr_metric$metric[1], x="Project", y="Correlation coefficient")
    )
    dev.off()
  })
  
  corr_6m = compute_cor(metrics_6m)
  if (filter == TRUE) {
    write.csv(corr_6m, paste0("corr/", tool, "_corr_6m_filtered.csv"), row.names = FALSE)
  } else {
    write.csv(corr_6m, paste0("corr/", tool, "_corr_6m.csv"), row.names = FALSE)
  }
  
  # Module pattern plots
  dir.create(paste0("patterns"), showWarnings =T)
  by(metrics_6m, metrics_6m$project, function(metrics_p) {
    name_p = metrics_p$project[1]
    a = metrics_p[,c("A", "INA", "ENA", "ILA", "ELA", "StA", "BugFixes")]
    rownames(a) = metrics_p$module
    a = subset(a[order(a$A),], A>0)
    colnames(a)[1] = "Total A"
    
    plot_patterns = function(row_labels = TRUE) {
      if (row_labels) {
        lab_row = NULL
        width = c(4,3)
        margins = c(6,1)
      }
      else {
        lab_row = ""
        width = c(4,0.1)
        margins = c(6,0.3)
      }
      heatmap.2(log(as.matrix(a) + 0.01), Rowv=NA, Colv=NA , col = colorRampPalette(brewer.pal(9,"Blues"))(100),
                margins = margins, cexCol = 2, rowsep=1:nrow(a), labRow = lab_row,
                sepcolor='#DEEBF7', sepwidth=c(0,0.00001),
                scale="none", main = name_p, density.info='none',
                trace='none',  key=FALSE, keysize=1.0, symkey=FALSE,
                lmat=rbind( c(3,2), c(1,4), c(0,0)), lhei=c(0.17,1.425, 0.05), lwid=width)
    }
    
    cairo_pdf(paste0("patterns/", tool, "_", name_p,"_fixes_metrics.pdf"), width = 8, height = 8)
    plot_patterns()
    dev.off()
    cairo_pdf(paste0("patterns/", tool, "_", name_p,"_fixes_metrics_nomodule.pdf"), width = 3, height = 8)
    plot_patterns(FALSE)
    dev.off()
  })
}


# Read original activity data sets.
act_months_before_original <- data.frame(read_csv(path.join(opt$repro_path, 
                                                            "act_months_before.csv")))
act_months_after_original <- data.frame(read_csv(path.join(opt$repro_path, 
                                                           "act_months_after.csv")))

# Read replicated activity data
act_months_before_codeface <- data.frame(read_csv(path.join(opt$res_path, "codeface",
                                             "act_months_before.csv")))
act_months_after_codeface <- data.frame(read_csv(path.join(opt$res_path, "codeface",
                                                           "act_months_after.csv")))
act_months_before_git2net <- data.frame(read_csv(path.join(opt$res_path, "git2net",
                                                           "act_months_before.csv")))
act_months_after_git2net <- data.frame(read_csv(path.join(opt$res_path, "git2net",
                                                          "act_months_after.csv")))
act_months_before_grimoire <- data.frame(read_csv(path.join(opt$res_path, "grimoire",
                                                           "act_months_before.csv")))
act_months_after_grimoire <- data.frame(read_csv(path.join(opt$res_path, "grimoire",
                                                          "act_months_after.csv")))
act_months_before_kaiaulu <- data.frame(read_csv(path.join(opt$res_path, "kaiaulu",
                                                           "act_months_before.csv")))
act_months_after_kaiaulu <- data.frame(read_csv(path.join(opt$res_path, "kaiaulu",
                                                          "act_months_after.csv")))

# Read original module metrics data.
mod_m_original <- data.frame(read_csv(path.join(opt$repro_path, "mod_m.csv")))

# Read replicated module metrics data.
mod_m_codeface <- data.frame(read_csv(path.join(opt$res_path, "codeface", "mod_m.csv")))
mod_m_git2net <- data.frame(read_csv(path.join(opt$res_path, "git2net", "mod_m.csv")))
mod_m_grimoire <- data.frame(read_csv(path.join(opt$res_path, "grimoire", "mod_m.csv")))
mod_m_kaiaulu <- data.frame(read_csv(path.join(opt$res_path, "kaiaulu", "mod_m.csv")))

mod_m_codeface_filtered <- data.frame(read_csv(path.join(opt$res_path, "codeface", "mod_m_filtered.csv")))
mod_m_git2net_filtered <- data.frame(read_csv(path.join(opt$res_path, "git2net", "mod_m_filtered.csv")))
mod_m_grimoire_filtered <- data.frame(read_csv(path.join(opt$res_path, "grimoire", "mod_m_filtered.csv")))
mod_m_kaiaulu_filtered <- data.frame(read_csv(path.join(opt$res_path, "kaiaulu", "mod_m_filtered.csv")))

# Configure seed for reproducibility.
set.seed(42)

compute_correlations(mod_m_codeface, act_months_before_codeface, act_months_after_codeface, "codeface")
compute_correlations(mod_m_git2net, act_months_before_git2net, act_months_after_git2net, "git2net")
compute_correlations(mod_m_grimoire, act_months_before_grimoire, act_months_after_grimoire, "grimoire")
compute_correlations(mod_m_kaiaulu, act_months_before_kaiaulu, act_months_after_kaiaulu, "kaiaulu")

compute_correlations(mod_m_codeface_filtered, act_months_before_codeface, act_months_after_codeface, "codeface", filter = TRUE)
compute_correlations(mod_m_git2net_filtered, act_months_before_git2net, act_months_after_git2net, "git2net", filter = TRUE)
compute_correlations(mod_m_grimoire_filtered, act_months_before_grimoire, act_months_after_grimoire, "grimoire", filter = TRUE)
compute_correlations(mod_m_kaiaulu_filtered, act_months_before_kaiaulu, act_months_after_kaiaulu, "kaiaulu", filter = TRUE)
