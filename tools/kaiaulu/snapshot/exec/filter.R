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
require(magrittr,quietly=TRUE)



doc <- "
USAGE:
  filter.R filter help
  filter.R filter <tools.yml> <project_conf.yml> <gitlog_file_name_path> <save_file_name_path>
  filter.R (-h | --help)
  filter.R --version

DESCRIPTION:
  Provides a suite of functions to filter tabulated git logs. Please see
  Kaiaulu's README.md for instructions on how to create <tool.yml>
  and <project_conf.yml>.


OPTIONS:
  -h --help     Show this screen.
  --version     Show version.
"



arguments <- docopt::docopt(doc, version = 'Kaiaulu 0.0.0.9600')
if(arguments[["filter"]] & arguments[["help"]]){
  cli_alert_info("Filters a tabulated git log using filter_by_file_extension()
                  and filter_by_filepath_substring.")
}else if(arguments[["filter"]]){
  tools_path <- arguments[["<tools.yml>"]]
  conf_path <- arguments[["<project_conf.yml>"]]
  gitlog_path <- arguments[["<gitlog_file_name_path>"]]
  save_path <- arguments[["<save_file_name_path>"]]

  tool <- yaml::read_yaml(tools_path)
  conf <- yaml::read_yaml(conf_path)

  # File filters
  file_extensions <- conf[["filter"]][["keep_filepaths_ending_with"]]
  substring_filepath <- conf[["filter"]][["remove_filepaths_containing"]]

  # Read tabulated git log
  project_git <- data.table::fread(gitlog_path)

  # Filter git log
  project_git <- project_git  %>%
    filter_by_file_extension(file_extensions,"file_pathname")  %>%
    filter_by_filepath_substring(substring_filepath,"file_pathname")

  data.table::fwrite(project_git,save_path)

  cli_alert_success(paste0("Filtered git log was saved at: ",save_path))
}
