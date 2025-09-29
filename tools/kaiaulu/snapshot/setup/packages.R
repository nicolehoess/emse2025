dir.create(Sys.getenv("R_LIBS_USER"), recursive = TRUE)
.libPaths(Sys.getenv("R_LIBS_USER"))  # add to the path

install.packages("devtools", dependencies=TRUE)
install.packages("doMPI", dependencies=TRUE)
install.packages("doParallel", dependencies=TRUE)
install.packages("dplyr", dependencies=TRUE)
install.packages("knitr", dependencies=TRUE)
install.packages("reactable", dependencies=TRUE)
install.packages("igraph", dependencies=TRUE)
install.packages("visNetwork", dependencies=TRUE)
install.packages("docopt", dependencies=TRUE)
install.packages("snow", dependencies=TRUE)
install.packages("doSNOW", dependencies=TRUE)
