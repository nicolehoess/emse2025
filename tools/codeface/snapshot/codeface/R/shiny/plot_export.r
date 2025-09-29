#! /usr/bin/env Rscript
## This file is part of Codeface. Codeface is free software: you can
## redistribute it and/or modify it under the terms of the GNU General Public
## License as published by the Free Software Foundation, version 2.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
## FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
## details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the Free Software
## Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
##
## Wrapper to export graphs meant for the shiny server frontend.

suppressMessages(library(igraph))

source("../config.r", chdir=TRUE)
source("../query.r", chdir=TRUE)
source("../clusters.r", chdir = TRUE)
source("../utils.r", chdir=TRUE)

gen.clusters.list <- function(l, con) {
  clusters.list <- lapply(1:length(l), function(i) {
    g <- NULL

    if (length(l) > 0) {
      g <- construct.cluster(con, l[[i]])

      ## Self-loops in the proximity analysis can become very strong;
      ## the resulting edges then typically destroy the visualisation
      ## completely. Get rid of them, thus.
      ## NOTE: simplify must be called before the cluster is annotated
      ## because the function
      if(!is.null(g)) {
        g <- simplify(g, remove.loops=TRUE)
      }
    }

    return(g)
  })

  ## Remove empty clusters
  clusters.list[sapply(clusters.list, is.null)] <- NULL

  clusters.list <- lapply(clusters.list, function(g) {
    if (!is.null(g)) {
      return(annotate.cluster(g))
    }
  })

  return(clusters.list)
}

do.plot.export <- function(conf, g, i, cluster.method) {
  V(g)$name <- NA
  pdf(paste(conf$resdir, "/", chartr(" ", "_", tolower(cluster.method)),
            "_", i, ".pdf", sep=""))

  if (max(E(g)$weight) == 1) {
    E(g)$weight <- 0.8
  } else {
    E(g)$weight <- 0.8 + (6 * E(g)$weight/max(E(g)$weight))
  }

  lo <- layout_with_dh(g, maxiter = 10, weight.edge.lengths = 1)
  lo <- norm_coords(lo, ymin=-1, ymax=1, xmin=-1, xmax=1)
  plot(g, vertex.color="lightblue", layout=lo*1, edge.arrow.size=0.5, edge.width=E(g)$weight)

  dev.off()
}

prepare.clusters.export <- function(conf, cluster.method) {
  l <- query.cluster.ids.con(conf$con, conf$pid, conf$rid, cluster.method)

  if (length(l) > 0) {
    clusters.list <- gen.clusters.list(l, conf$con)

    ## Sort the clusters by number of vertices
    sizes <- sapply(clusters.list, vcount)

    clusters.list <- clusters.list[sort(sizes, index.return=TRUE, decreasing=TRUE)$ix]

    max.length <- 8
    if (length(clusters.list) < max.length) {
      max.length <- length(clusters.list)
    }

    return(clusters.list[1:max.length])
  } else {
    return(NULL)
  }
}

do.cluster.plots.export <- function(conf, clusters.list, cluster.method) {
  par(mfcol=c(2,4))
  for (i in 1:length(clusters.list)) {
    do.plot.export(conf, clusters.list[[i]], i, cluster.method)
  }
}

config.script.run({
  conf <- config.from.args(positional.args=list("resdir", "rid"),
                           require.project=TRUE)

  for (c in list("Spin Glass Community", "Random Walk Community")) {
    clusters.list <- prepare.clusters.export(conf, c)

    if (!is.null(clusters.list)) {
        do.cluster.plots.export(conf, clusters.list, c)
    }
  }
})