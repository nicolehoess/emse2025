#!/usr/local/bin/Rscript

# Kaiaulu - https://github.com/sailuh/kaiaulu
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


require(yaml,quietly=TRUE)
require(cli,quietly=TRUE)
require(docopt,quietly=TRUE)
require(kaiaulu,quietly=TRUE)



doc <- "
USAGE:
  identity.R match help
  identity.R match <tools.yml> <project_conf.yml> <gitlog_file_name_path> <save_file_name_path>
  identity.R (-h | --help)
  identity.R --version

DESCRIPTION:
  Provides a suite of functions to match identities in tabulated git logs.
  Please see Kaiaulu's README.md for instructions on how to create <tool.yml>
  and <project_conf.yml>.


OPTIONS:
  -h --help     Show this screen.
  --version     Show version.
"



arguments <- docopt::docopt(doc, version = 'Kaiaulu 0.0.0.9600')
if(arguments[["match"]] & arguments[["help"]]){
  cli_alert_info("Matches identities using identity_match().")
}else if(arguments[["match"]]){
  tools_path <- arguments[["<tools.yml>"]]
  conf_path <- arguments[["<project_conf.yml>"]]
  gitlog_path <- arguments[["<gitlog_file_name_path>"]]
  save_path <- arguments[["<save_file_name_path>"]]

  tool <- yaml::read_yaml(tools_path)
  conf <- yaml::read_yaml(conf_path)

  # Read git log
  project_git <- data.table::fread(gitlog_path)

  # Identity match
  project_log <- list(project_git=project_git)
  project_log <- identity_match(project_log,
                                name_column = c("author_name_email"),
                                assign_exact_identity,
                                use_name_only=TRUE,
                                label = "raw_name"
  )
  project_git <- project_log[["project_git"]]

  data.table::fwrite(project_git,save_path)

  cli_alert_success(paste0("Table with matched identities was saved at: ",
                           save_path))
}
