# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

# Calculates turnover and quality metrics to replicate Foucault et al., 2015.

import argparse
import git2net
import igraph as ig
import lizard
import mysql.connector
import numpy as np
import networkx as nx
import os
import pandas as pd
import pathpy as pp
import pydriller
import query_codeface
import query_kaiaulu
import query_git2net
import query_grimoire
import re
import sqlite3
import subprocess
import yaml

from datetime import datetime, timedelta
from elasticsearch import Elasticsearch
from elasticsearch_dsl import Search
from igraph import ARPACKOptions
from pygments import lexers


def arguments():
    """Define command line options."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--tool", required=True,
                        help="Tool the analysis was performed with. Supports"
                             "codeface, kaiaulu, git2net, grimoire.")
    parser.add_argument("--data_path", required=True,
                        help="Either path to the directory containing the parsed "
                             "git log (kaiaulu, git2net) or "
                             "database port (codeface, grimoire).")
    parser.add_argument("--git_repo_path", required=True,
                        help="Path to the directory containing the git"
                             "repositories at the CLOC hash")
    parser.add_argument("--bug_fix_path", required=True,
                        help="Path to the file containing the bug fixes"
                             "identified by Foucault et al.")
    parser.add_argument("--save_path", required=True,
                        help="Path to the directory to store the results")
    parser.add_argument("--projects", type=str, required=True,
                        help="List of projects to analyse")
    return parser.parse_args()


def get_module(row):
    """
    Gets the module the given file belongs to according
    to Foucault et al.'s modularisation technique.

    Args:
        row: The dataframe row.

    Returns:
        The module path corresponding to Foucault et al.
    """

    # Define regular expressions for modularisation
    # as proposed by Foucault et al. in their configuration
    # file .dgitsources-options.
    file_path = row["file"]
    project = row["project"]

    if project == "angular_js":
        modules = [
            (re.compile("^i18n/closure/.*"), "i18n/closure/"),
            (re.compile("^i18n/e2e/.*"), "i18n/e2e/"),
            (re.compile("^i18n/spec/.*"), "i18n/spec/"),
            (re.compile("^i18n/src/closureSlurper\\.js"),
             "i18n/src/closureSlurper.js"),
            (re.compile("^i18n/src/converter\\.js"), "i18n/src/converter.js"),
            (re.compile("^i18n/src/parser\\.js"), "i18n/src/parser.js"),
            (re.compile("^i18n/src/util\\.js"), "i18n/src/util.js"),
            (re.compile("^src/auto/injector\\.js"), "src/auto/injector.js"),
            (re.compile("^src/bootstrap/google-prettify/prettify\\.js"),
             "src/bootstrap/google-prettify/prettify.js"),
            (re.compile("^src/bootstrap/.*"), "src/bootstrap/"),
            (re.compile("^src/ng/compile\\.js"), "src/ng/compile.js"),
            (re.compile("^src/ng/directive/input\\.js"), "src/ng/directive/input.js"),
            (re.compile("^src/ng/directive/ng.*"), "src/ng/directive/ng.*"),
            (re.compile("^src/ng/directive/.*"), "src/ng/directive/"),
            (re.compile("^src/ng/filter/.*"), "src/ng/filter/"),
            (re.compile("^src/ng/http.*"), "src/ng/http.*"),
            (re.compile("^src/ng/location\\.js"), "src/ng/location.js"),
            (re.compile("^src/ng/parse\\.js"), "src/ng/parse.js"),
            (re.compile("^src/ng/rootScope\\.js"), "src/ng/rootScope.js"),
            (re.compile("^src/ng/[^/]*"), "src/ng/"),
            (re.compile("^src/ngCookies/cookies\\.js"), "src/ngCookies/cookies.js"),
            (re.compile("^src/ngLocale/.*"), "src/ngLocale/"),
            (re.compile("^src/ngMock/.*"), "src/ngMock/"),
            (re.compile("^src/ngResource/.*"), "src/ngResource/"),
            (re.compile("^src/ngSanitize/directive/ngBindHtml\\.js"),
             "src/ngSanitize/directive/ngBindHtml.js"),
            (re.compile("^src/ngSanitize/filter/linky\\.js"),
             "src/ngSanitize/filter/linky.js"),
            (re.compile("^src/ngSanitize/sanitize\\.js"),
             "src/ngSanitize/sanitize.js"),
            (re.compile("^src/ngScenario/.*"), "src/ngScenario/"),
            (re.compile("^src/jqLite\\.js"), "src/jqLite.js"),
            (re.compile("^src/[^/]*"), "src/")
        ]

    elif project == "ansible":
        modules = [
            (re.compile("^lib/ansible/[^/]*"), "lib/ansible/"),
            (re.compile("^lib/ansible/utils/[^/]*"), "lib/ansible/utils/"),
            (re.compile("^lib/ansible/inventory/[^/]*"),
             "lib/ansible/inventory/"),
            (re.compile("^lib/ansible/inventory/vars_plugins/[^/]*"),
             "lib/ansible/inventory/vars_plugins/"),
            (re.compile("^lib/ansible/playbook/[^/]*"),
             "lib/ansible/playbook/"),
            (re.compile("^lib/ansible/runner/[^/]*"),
             "lib/ansible/runner/"),
            (re.compile("^lib/ansible/runner/action_plugins/[^/]*"),
             "lib/ansible/runner/action_plugins/"),
            (re.compile("^lib/ansible/runner/lookup_plugins/[^/]*"),
             "lib/ansible/runner/lookup_plugins/"),
            (re.compile("^lib/ansible/runner/connection_plugins/[^/]*"),
             "lib/ansible/runner/connection_plugins/"),
            (re.compile("^lib/ansible/runner/filter_plugins/[^/]*"),
             "lib/ansible/runner/filter_plugins/"),
            (re.compile("^lib/ansible/callback_plugins/[^/]*"),
             "lib/ansible/callback_plugins/"),
            (re.compile("^lib/ansible/module_utils/[^/]*"),
             "lib/ansible/module_utils/"),
            (re.compile("^library/cloud/.*"), "library/cloud/"),
            (re.compile("^library/commands/.*"), "library/commands/"),
            (re.compile("^library/database/.*"), "library/database/"),
            (re.compile("^library/files/.*"), "library/files/"),
            (re.compile("^library/internal/.*"), "library/internal/"),
            (re.compile("^library/inventory/.*"), "library/inventory/"),
            (re.compile("^library/messaging/.*"), "library/messaging/"),
            (re.compile("^library/monitoring/.*"), "library/monitoring/"),
            (re.compile("^library/net_infrastructure/.*"),
             "library/net_infrastructure/"),
            (re.compile("^library/network/.*"), "library/network/"),
            (re.compile("^library/notification/.*"), "library/notification/"),
            (re.compile("^library/packaging/.*"), "library/packaging/"),
            (re.compile("^library/source_control/.*"), "library/source_control/"),
            (re.compile("^library/system/.*"), "library/system/"),
            (re.compile("^library/utilities/.*"), "library/utilities/"),
            (re.compile("^library/web_infrastructure/.*"),
             "library/web_infrastructure/"),
            (re.compile("^plugins/inventory/.*\\.py"), "plugins/inventory/*.py"),
            (re.compile("^plugins/callbacks/.*\\.py"), "plugins/callbacks/*.py")
        ]

    elif project == "jenkins":
        modules = [
            (re.compile("^cli/src/main/java/hudson/cli/.*"),
             "cli/src/main/java/hudson/cli/"),
            (re.compile("^core/src/main/java/hudson/cli/declarative/.*"),
             "core/src/main/java/hudson/cli/declarative/"),
            (re.compile("^core/src/main/java/hudson/cli/handlers/.*"),
             "core/src/main/java/hudson/cli/handlers/"),
            (re.compile("^core/src/main/java/hudson/cli/util/.*"),
             "core/src/main/java/hudson/cli/util/"),
            (re.compile("^core/src/main/java/hudson/cli/.*"),
             "core/src/main/java/hudson/cli/"),
            (re.compile("^core/src/main/java/hudson/console/.*"),
             "core/src/main/java/hudson/console/"),
            (re.compile("^core/src/main/java/hudson/diagnosis/.*"),
             "core/src/main/java/hudson/diagnosis/"),
            (re.compile("^core/src/main/java/hudson/fsp/.*"),
             "core/src/main/java/hudson/fsp/"),
            (re.compile("^core/src/main/java/hudson/init/.*"),
             "core/src/main/java/hudson/init/"),
            (re.compile("^core/src/main/java/hudson/lifecycle/.*"),
             "core/src/main/java/hudson/lifecycle/"),
            (re.compile("^core/src/main/java/hudson/logging/.*"),
             "core/src/main/java/hudson/logging/"),
            (re.compile("^core/src/main/java/hudson/markup/.*"),
             "core/src/main/java/hudson/markup/"),
            (re.compile("^core/src/main/java/hudson/matrix/listeners/.*"),
             "core/src/main/java/hudson/matrix/listeners/"),
            (re.compile("^core/src/main/java/hudson/matrix/.*"),
             "core/src/main/java/hudson/matrix/"),
            (re.compile("^core/src/main/java/hudson/model/labels/.*"),
             "core/src/main/java/hudson/model/labels/"),
            (re.compile("^core/src/main/java/hudson/model/listeners/.*"),
             "core/src/main/java/hudson/model/listeners/"),
            (re.compile("^core/src/main/java/hudson/model/queue/.*"),
             "core/src/main/java/hudson/model/queue/"),
            (re.compile("^core/src/main/java/hudson/model/.*"),
             "core/src/main/java/hudson/model/"),
            (re.compile("^core/src/main/java/hudson/node_monitors/.*"),
             "core/src/main/java/hudson/node_monitors/"),
            (re.compile("^core/src/main/java/hudson/org/apache/tools/tar/.*"),
             "core/src/main/java/hudson/org/apache/tools/tar/"),
            (re.compile("^core/src/main/java/hudson/os/solaris/.*"),
             "core/src/main/java/hudson/os/solaris/"),
            (re.compile("^core/src/main/java/hudson/os/windows/.*"),
             "core/src/main/java/hudson/os/windows/"),
            (re.compile("^core/src/main/java/hudson/os/.*"),
             "core/src/main/java/hudson/os/"),
            (re.compile("^core/src/main/java/hudson/scheduler/.*"),
             "core/src/main/java/hudson/scheduler/"),
            (re.compile("^core/src/main/java/hudson/scm/.*"),
             "core/src/main/java/hudson/scm/"),
            (re.compile("^core/src/main/java/hudson/search/.*"),
             "core/src/main/java/hudson/search/"),
            (re.compile("^core/src/main/java/hudson/security/captcha/.*"),
             "core/src/main/java/hudson/security/captcha/"),
            (re.compile("^core/src/main/java/hudson/security/csrf/.*"),
             "core/src/main/java/hudson/security/csrf/"),
            (re.compile("^core/src/main/java/hudson/security/.*"),
             "core/src/main/java/hudson/security/"),
            (re.compile("^core/src/main/java/hudson/slaves/.*"),
             "core/src/main/java/hudson/slaves/"),
            (re.compile("^core/src/main/java/hudson/tasks/_maven/.*"),
             "core/src/main/java/hudson/tasks/_maven/"),
            (re.compile("^core/src/main/java/hudson/tasks/junit/.*"),
             "core/src/main/java/hudson/tasks/junit/"),
            (re.compile("^core/src/main/java/hudson/tasks/.*"),
             "core/src/main/java/hudson/tasks/"),
            (re.compile("^core/src/main/java/hudson/tools/.*"),
             "core/src/main/java/hudson/tools/"),
            (re.compile("^core/src/main/java/hudson/triggers/.*"),
             "core/src/main/java/hudson/triggers/"),
            (re.compile("^core/src/main/java/hudson/util/io/.*"),
             "core/src/main/java/hudson/util/io/"),
            (re.compile("^core/src/main/java/hudson/util/jelly/.*"),
             "core/src/main/java/hudson/util/jelly/"),
            (re.compile("^core/src/main/java/hudson/util/jna/.*"),
             "core/src/main/java/hudson/util/jna/"),
            (re.compile("^core/src/main/java/hudson/util/spring/.*"),
             "core/src/main/java/hudson/util/spring/"),
            (re.compile("^core/src/main/java/hudson/util/ssh/.*"),
             "core/src/main/java/hudson/util/ssh/"),
            (re.compile("^core/src/main/java/hudson/util/xstream/.*"),
             "core/src/main/java/hudson/util/xstream/"),
            (re.compile("^core/src/main/java/hudson/util/.*"),
             "core/src/main/java/hudson/util/"),
            (re.compile("^core/src/main/java/hudson/views/.*"),
             "core/src/main/java/hudson/views/"),
            (re.compile("^core/src/main/java/hudson/.*"),
             "core/src/main/java/hudson/"),
            (re.compile("^core/src/main/java/jenkins/management/.*"),
             "core/src/main/java/jenkins/management/"),
            (re.compile("^core/src/main/java/jenkins/model/lazy/.*"),
             "core/src/main/java/jenkins/model/lazy/"),
            (re.compile("^core/src/main/java/jenkins/model/.*"),
             "core/src/main/java/jenkins/model/"),
            (re.compile("^core/src/main/java/jenkins/mvn/.*"),
             "core/src/main/java/jenkins/mvn/"),
            (re.compile("^core/src/main/java/jenkins/scm/.*"),
             "core/src/main/java/jenkins/scm/"),
            (re.compile("^core/src/main/java/jenkins/security/.*"),
             "core/src/main/java/jenkins/security/"),
            (re.compile("^core/src/main/java/jenkins/slaves/.*"),
             "core/src/main/java/jenkins/slaves/"),
            (re.compile("^core/src/main/java/jenkins/util/io/.*"),
             "core/src/main/java/jenkins/util/io/"),
            (re.compile("^core/src/main/java/jenkins/util/xstream/.*"),
             "core/src/main/java/jenkins/util/xstream/"),
            (re.compile("^core/src/main/java/jenkins/util/.*"),
             "core/src/main/java/jenkins/util/"),
            (re.compile("^core/src/main/java/jenkins/.*"),
             "core/src/main/java/jenkins/"),
            (re.compile("^core/src/main/java/org/acegisecurity/providers/ldap/authenticator/.*"),
             "core/src/main/java/org/acegisecurity/providers/ldap/authenticator/"),
            (re.compile("^maven-plugin/src/main/java/hudson/maven/local_repo/.*"),
             "maven-plugin/src/main/java/hudson/maven/local_repo/"),
            (re.compile("^maven-plugin/src/main/java/hudson/maven/reporters/.*"),
             "maven-plugin/src/main/java/hudson/maven/reporters/"),
            (re.compile("^maven-plugin/src/main/java/hudson/maven/util/.*"),
             "maven-plugin/src/main/java/hudson/maven/util/"),
            (re.compile("^maven-plugin/src/main/java/hudson/maven/.*"),
             "maven-plugin/src/main/java/hudson/maven/")
        ]

    elif project == "jquery":
        # For JQuery, the configuration file does not contain
        # pre-defined modules. As a substitute, we use the
        # module names found in the analysis data.
        modules = [
            (re.compile(r"src/event.js"), "src/event.js"),
            (re.compile(r"src/manipulation.js"), "src/manipulation.js"),
            (re.compile(r"src/core.js"), "src/core.js"),
            (re.compile(r"src/ajax.js"), "src/ajax.js"),
            (re.compile(r"src/effects.js"), "src/effects.js"),
            (re.compile(r"src/attributes.js"), "src/attributes.js"),
            (re.compile(r"src/css.js"), "src/css.js"),
            (re.compile(r"src/traversing.js"), "src/traversing.js"),
            (re.compile(r"src/data.js"), "src/data.js"),
            (re.compile(r"src/support.js"), "src/support.js"),
            (re.compile(r"src/ajax/xhr.js"), "src/ajax/xhr.js"),
            (re.compile(r"src/callbacks.js"), "src/callbacks.js"),
            (re.compile(r"src/offset.js"), "src/offset.js"),
            (re.compile(r"src/queue.js"), "src/queue.js"),
            (re.compile(r"src/deferred.js"), "src/deferred.js"),
            (re.compile(r"src/serialize.js"), "src/serialize.js"),
            (re.compile(r"src/ajax/jsonp.js"), "src/ajax/jsonp.js"),
            (re.compile(r"src/ajax/script.js"), "src/ajax/script.js"),
            (re.compile(r"src/deprecated.js"), "src/deprecated.js"),
            (re.compile(r"src/dimensions.js"), "src/dimensions.js"),
            (re.compile(r"src/sizzle-jquery.js"), "src/sizzle-jquery.js"),
            (re.compile(r"src/exports.js"), "src/exports.js"),
            (re.compile(r"src/outro.js"), "src/outro.js"),
            (re.compile(r"src/intro.js"), "src/intro.js")
        ]

    else:  # Rails
        modules = [
            (re.compile("^actionmailer/.*"), "actionmailer/"),
            (re.compile("^actionpack/lib/action_controller/assertions/.*"),
             "actionpack/lib/action_controller/assertions/"),
            (re.compile("^actionpack/lib/action_controller/caching/.*"),
             "actionpack/lib/action_controller/caching/"),
            (re.compile("^actionpack/lib/action_controller/cgi_text/.*"),
             "actionpack/lib/action_controller/cgi_text/"),
            (re.compile("^actionpack/lib/action_controller/routing/.*"),
             "actionpack/lib/action_controller/routing/"),
            (re.compile("^actionpack/lib/action_controller/session/.*"),
             "actionpack/lib/action_controller/session/"),
            (re.compile("^actionpack/lib/action_controller/.*"),
             "actionpack/lib/action_controller/"),
            (re.compile("^actionpack/lib/action_view/erb/.*"),
             "actionpack/lib/action_view/erb/"),
            (re.compile("^actionpack/lib/action_view/helpers/.*"),
             "actionpack/lib/action_view/helpers/"),
            (re.compile("^actionpack/lib/action_view/template_handlers/.*"),
             "actionpack/lib/action_view/template_handlers/"),
            (re.compile("^actionpack/lib/action_view/.*"),
             "actionpack/lib/action_view/"),
            (re.compile("^actionpack/.*"), "actionpack/"),
            (re.compile("^activemodel/lib/active_model/state_machine/.*"),
             "activemodel/lib/active_model/state_machine/"),
            (re.compile("^activemodel/lib/active_model/validations/.*"),
             "activemodel/lib/active_model/validations/"),
            (re.compile("^activemodel/lib/active_model/.*"),
             "activemodel/lib/active_model/"),
            (re.compile("^activemodel/lib/.*"), "activemodel/lib/"),
            (re.compile("^activerecord/active_record/associations/.*"),
             "activerecord/active_record/associations/"),
            (re.compile("^activerecord/active_record/connection_adapters/.*"),
             "activerecord/active_record/connection_adapters/"),
            (re.compile("^activerecord/active_record/locking/.*"),
             "activerecord/active_record/locking/"),
            (re.compile("^activerecord/active_record/serializers/.*"),
             "activerecord/active_record/serializers/"),
            (re.compile("^activerecord/active_record/.*"),
             "activerecord/active_record/"),
            (re.compile("^activerecord/lib/.*"), "activerecord/lib/"),
            (re.compile("^activerecord/.*"), "activerecord/"),
            (re.compile("^activeresource/lib/active_resource/formats/.*"),
             "activeresource/lib/active_resource/formats/"),
            (re.compile("^activeresource/lib/active_resource/.*"),
             "activeresource/lib/active_resource/"),
            (re.compile("^activeresource/lib/.*"), "activeresource/lib/"),
            (re.compile("^activesupport/lib/active_support/cache/.*"),
             "activesupport/lib/active_support/cache/"),
            (re.compile("^activesupport/lib/active_support/core_ext/array/.*"),
             "activesupport/lib/active_support/core_ext/array/"),
            (re.compile("^activesupport/lib/active_support/core_ext/base64/.*"),
             "activesupport/lib/active_support/core_ext/base64/"),
            (re.compile("^activesupport/lib/active_support/core_ext/bigdecimal/.*"),
             "activesupport/lib/active_support/core_ext/bigdecimal/"),
            (re.compile("^activesupport/lib/active_support/core_ext/cgi/.*"),
             "activesupport/lib/active_support/core_ext/cgi/"),
            (re.compile("^activesupport/lib/active_support/core_ext/class/.*"),
             "activesupport/lib/active_support/core_ext/class/"),
            (re.compile("^activesupport/lib/active_support/core_ext/date/.*"),
             "activesupport/lib/active_support/core_ext/date/"),
            (re.compile("^activesupport/lib/active_support/core_ext/date_time/.*"),
             "activesupport/lib/active_support/core_ext/date_time/"),
            (re.compile("^activesupport/lib/active_support/core_ext/file/.*"),
             "activesupport/lib/active_support/core_ext/file/"),
            (re.compile("^activesupport/lib/active_support/core_ext/float/.*"),
             "activesupport/lib/active_support/core_ext/float/"),
            (re.compile("^activesupport/lib/active_support/core_ext/hash/.*"),
             "activesupport/lib/active_support/core_ext/hash/"),
            (re.compile("^activesupport/lib/active_support/core_ext/integer/.*"),
             "activesupport/lib/active_support/core_ext/integer/"),
            (re.compile("^activesupport/lib/active_support/core_ext/kernel/.*"),
             "activesupport/lib/active_support/core_ext/kernel/"),
            (re.compile("^activesupport/lib/active_support/core_ext/module/.*"),
             "activesupport/lib/active_support/core_ext/module/"),
            (re.compile("^activesupport/lib/active_support/core_ext/numeric/.*"),
             "activesupport/lib/active_support/core_ext/numeric/"),
            (re.compile("^activesupport/lib/active_support/core_ext/object/.*"),
             "activesupport/lib/active_support/core_ext/object/"),
            (re.compile("^activesupport/lib/active_support/core_ext/pathname/.*"),
             "activesupport/lib/active_support/core_ext/pathname/"),
            (re.compile("^activesupport/lib/active_support/core_ext/process/.*"),
             "activesupport/lib/active_support/core_ext/process/"),
            (re.compile("^activesupport/lib/active_support/core_ext/range/.*"),
             "activesupport/lib/active_support/core_ext/range/"),
            (re.compile("^activesupport/lib/active_support/core_ext/string/.*"),
             "activesupport/lib/active_support/core_ext/string/"),
            (re.compile("^activesupport/lib/active_support/core_ext/time/.*"),
             "activesupport/lib/active_support/core_ext/time/"),
            (re.compile("^activesupport/lib/active_support/json/encoders/.*"),
             "activesupport/lib/active_support/json/encoders/"),
            (re.compile("^activesupport/lib/active_support/json/.*"),
             "activesupport/lib/active_support/json/"),
            (re.compile("^activesupport/lib/active_support/multibyte/.*"),
             "activesupport/lib/active_support/multibyte/"),
            (re.compile("^activesupport/lib/active_support/testing/.*"),
             "activesupport/lib/active_support/testing/"),
            (re.compile("^activesupport/lib/active_support/values/.*"),
             "activesupport/lib/active_support/values/"),
            (re.compile("^activesupport/lib/active_support/xml_mini.*"),
             "activesupport/lib/active_support/xml_mini.*"),
            (re.compile("^activesupport/lib/active_support/.*"),
             "activesupport/lib/active_support/"),
            (re.compile("^activesupport/.*"), "activesupport/"),
            (re.compile("^railties/builtin/rails_info/.*"),
             "railties/builtin/rails_info/"),
            (re.compile("^railties/configs/.*"), "railties/configs/"),
            (re.compile("^railties/dispatches/.*"), "railties/dispatches/"),
            (re.compile("^railties/environments/.*"), "railties/environments/"),
            (re.compile("^railties/guides/.*"), "railties/guides/"),
            (re.compile("^railties/helpers/.*"), "railties/helpers/"),
            (re.compile("^railties/lib/commands/ncgi/.*"),
             "railties/lib/commands/ncgi/"),
            (re.compile("^railties/lib/commands/performance/.*"),
             "railties/lib/commands/performance/"),
            (re.compile("^railties/lib/commands/.*"),
             "railties/lib/commands/"),
            (re.compile("^railties/lib/rails/plugin/.*"),
             "railties/lib/rails/plugin/"),
            (re.compile("^railties/lib/rails/rack/.*"),
             "railties/lib/rails/rack/"),
            (re.compile("^railties/lib/rails/.*"), "railties/lib/rails/"),
            (re.compile("^railties/lib/rails_generator/.*"),
             "railties/lib/rails_generator/"),
            (re.compile("^railties/lib/tasks/.*"), "railties/lib/tasks/"),
            (re.compile("^railties/lib/.*"), "railties/lib/")
        ]

    for pattern, module in modules:
        if pattern.match(file_path):
            return module
    return None


def get_bugfixes(row, df_file, bug_fixes):
    project = row["project"]
    module = row["module"]
    bug_fix_commits = bug_fixes[project]

    # Get all commits that modified the module of interest.
    df_module = df_file[(df_file["project"] == project) & (df_file["module"] == module)]
    df_module = df_module[df_module["hash"].isin(bug_fix_commits)]
    bug_fix_count = len(df_module["hash"].unique().tolist())
    return bug_fix_count


def main(tool, data_path, git_repo_path, bug_fix_path, save_path, projects):
    if not os.path.isdir(save_path):
        os.makedirs(save_path)

    # Get tool-specific meta data and range mapping.
    if tool not in ["codeface", "kaiaulu", "git2net", "grimoire"]:
        print("Tool not supported. Choose between codeface, kaiaulu, "
              "git2net, grimoire.")
        return

    # Releases considered as S_0 (from .dgitsources-options)
    # These also correspond to the commit hashes used for cloc analysis.
    # AngularJS: v1.0.0, 2012-06-14, 519bef4f3d1cdac497c782f77457fd2f67184601
    # Ansible: v1.5.0, 2014-02-28, 6221a2740f5c3023c817d13e4a564f301ed3bc73
    # Jenkins: v1.509, 2013-04-01, 3991cd04fd13aa086c25820bdfaa9460f0810284
    # JQuery:v1.8.0, 2012-08-09, 95559f5117c8a21c1b8cc99f4badc320fd3dcbda
    # Rails: v2.3.2, 2009-03-15, 73fc42cc0b5e94541480032c2941a50edd4080c2
    # These releases also correspond to the CLOC analysis versions.
    releases = {
        "angular_js": "519bef4f3d1cdac497c782f77457fd2f67184601",
        "ansible": "6221a2740f5c3023c817d13e4a564f301ed3bc73",
        "jenkins": "3991cd04fd13aa086c25820bdfaa9460f0810284",
        "jquery": "95559f5117c8a21c1b8cc99f4badc320fd3dcbda",
        "rails": "73fc42cc0b5e94541480032c2941a50edd4080c2"
    }
    # Sometimes, a tool may not find the specified commit. In this
    # case, we fall back on the date of the respective commit from the
    # git log.
    releases_dates = {
        "angular_js": "2012-06-14",
        "ansible": "2014-02-28",
        "jenkins": "2013-04-01",
        "jquery": "2012-08-09",
        "rails": "2009-03-15"
    }

    # Start dates R_first (from .dgitsources-options)
    r_first = {
        "angular_js": "c9c176a53b1632ca2b1c6ed27382ab72ac21d45d",
        "ansible": "f31421576b00f0b167cdbe61217c31c21a41ac02",
        "jenkins": "3979d159e736834b7c8ad406ccb8c40bdead14b2",
        "jquery": "0a7232cc39912064de62ee06fd14221b36c93fd8",
        "rails": "b8bc92e61914cc6ef9d6ca12aba27d440ec0ebd5"
    }
    r_first_dates = {
        "angular_js": "2010-01-05",
        "ansible": "2012-02-23",
        "jenkins": "2010-11-26",
        "jquery": "2009-11-15",
        "rails": "2008-04-11"
    }

    # R_last (from .dgitsources-options)
    r_last = {
        "angular_js": "9d53e5a38dd369dec82d82e13e078df3d6054c8a",
        "ansible": "caf2a96ef9808436f00522b7792a3541301d90eb",
        "jenkins": "01c0ac0488c840ee71fe5c489e904bcc56bc4df6",
        "jquery": "9434e03193c45d51bbd063a0edd1a07a6178d33f",
        "rails": "7847a19f476fb9bee287681586d872ea43785e53"
    }
    r_last_dates = {
        "angular_js": "2014-12-19",
        "ansible": "2015-03-15",
        "jenkins": "2015-01-25",
        "jquery": "2014-02-19",
        "rails": "2014-12-19"
    }

    if tool == "codeface":
        con = mysql.connector.connect(
            host="127.0.0.1",
            database="codeface",
            user="codeface",
            password="codeface",
            port=str(data_path)
        )
        cur = con.cursor(buffered=True)

    # Construct data sets to answer the research questions.
    commit_dates_list = []
    act_months_before_list = []
    act_months_after_list = []
    act_months_before_list_bug = []
    act_months_after_list_bug = []

    projects = projects.split(", ")
    for p in projects:
        print("Extracting developer activity in project "+str(p)+"...")
        p_bug = p+"_bug"

        # Setup to get tool-specific project data
        if tool == "codeface":
            pid = query_codeface.get_project_id(cur, p)
            pid_bug = query_codeface.get_project_id(cur, p_bug)
        elif tool == "kaiaulu":
            # Depending on the research question, we may require
            # file filtering or not. Therefore, we load the filtered
            # and unfiltered table.
            # Main branch git log.
            git_log_complete_path = os.path.join(data_path, p, "gitlog_complete.csv")
            df_git_log_complete = pd.read_csv(git_log_complete_path, encoding="latin-1")
            git_log_filtered_path = os.path.join(data_path, p, "gitlog_filtered.csv")
            df_git_log_filtered = pd.read_csv(git_log_filtered_path, encoding="latin-1")
            # Bug branch git log.
            git_log_complete_path = os.path.join(data_path, p_bug, "gitlog_complete.csv")
            df_git_log_complete_bug = pd.read_csv(git_log_complete_path, encoding="latin-1")
            git_log_filtered_path = os.path.join(data_path, p_bug, "gitlog_filtered.csv")
            df_git_log_filtered_bug = pd.read_csv(git_log_filtered_path, encoding="latin-1")
        elif tool == "git2net":
            # Main branch database.
            project_path = os.path.join(data_path, p)
            db_path = os.path.join(project_path, p+"_line.db")
            con = sqlite3.connect(db_path)
            cur = con.cursor()
            # Bug branch database.
            db_bug_path = os.path.join(project_path+"_bug", p_bug+"_line.db")
            con_bug = sqlite3.connect(db_bug_path)
            cur_bug = con_bug.cursor()
        elif tool == "grimoire":
            es = Elasticsearch(["http://elasticsearch:" + str(data_path)])
            es.indices.put_settings(body={"index": {"max_result_window": 500000}})

        # RQ1: Turnover relevance in OSS projects based on commit activity
        # Extract all commits with their author and date that were made
        # in a certain time ra, "%Y-%m-%dT%H:%M:%S"nge specified in the diggit configurations.
        # The dataset may include duplicate rows if a developer committed
        # multiple times a day.

        # Important: Despite using the same filtering range as in original
        # paper and tool, we will likely observe different commits,
        # because diggit always traverses multiple branches in the Git DAG
        # with  Rugged, while the replication tools linearly process
        # branches and ignore the DAG.

        # Get start and end date of the first and last commits,
        # which may differ for each tool.
        # Define defaults if we can't find a specific commit.
        if tool == "codeface":
            start_date = query_codeface.get_commit_date(cur, r_first.get(p), pid)
            end_date = query_codeface.get_commit_date(cur, r_last.get(p), pid)
        elif tool == "git2net":
            start_date = query_git2net.get_commit_date(cur, r_first.get(p))
            end_date = query_git2net.get_commit_date(cur, r_last.get(p))
        elif tool == "grimoire":
            start_date = query_grimoire.get_commit_date(es, p, r_first.get(p))
            end_date = query_grimoire.get_commit_date(es, p, r_last.get(p))
        else:  # Kaiaulu
            start_date = query_kaiaulu.get_commit_date(df_git_log_complete, r_first.get(p))
            end_date = query_kaiaulu.get_commit_date(df_git_log_complete, r_last.get(p))

        if start_date is None:
            print("Could not find start commit for project "+str(p)+". Falling back to date...")
            start_date = r_first_dates.get(p)
        if end_date is None:
            print("Could not find end commit for project "+str(p)+". Falling back to date...")
            end_date = r_last_dates.get(p)

        # Extract hash, author and commit time.
        if tool == "codeface":
            # We only consider the main branch for codeface and
            # do not extract the commits from the bug branch
            # because this would require custom identity merging
            # between the two database projects.
            df_project_commit_dates = query_codeface.get_commits_info(cur, start_date, end_date, pid)
        elif tool == "git2net":
            # We only consider the main branch for git2net and
            # do not extract the commits from the bug branch
            # because this would require custom identity merging
            # between the two databases.
            df_project_commit_dates = query_git2net.get_commits_info(cur, start_date, end_date)
        elif tool == "grimoire":
            df_project_commit_dates = query_grimoire.get_commits_info(es, p, start_date, end_date)
        else: # Kaiaulu
            df_project_commit_dates = query_kaiaulu.get_commits_info(df_git_log_complete, start_date, end_date)

        df_project_commit_dates["project"] = p
        df_project_commit_dates["time"] = pd.to_datetime(df_project_commit_dates["time"]).dt.date
        commit_dates_list.append(df_project_commit_dates)

        # Create activity data sets for RQ2 and RQ3.
        # Get release dates per tool, if they differ.
        if tool == "codeface":
            # Release date on main branch.
            s_0_date = query_codeface.get_commit_date(cur, releases.get(p), pid)
            # Release date on bug branch.
            s_0_date_bug = query_codeface.get_commit_date(cur, releases.get(p), pid_bug)
        elif tool == "git2net":
            # Release date on main branch.
            s_0_date = query_git2net.get_commit_date(cur, releases.get(p))
            if s_0_date is not None:
                s_0_date = datetime.strptime(s_0_date, "%Y-%m-%d %H:%M:%S")
            # Release date on bug branch.
            s_0_date_bug = query_git2net.get_commit_date(cur_bug, releases.get(p))
            if s_0_date_bug is not None:
                s_0_date_bug = datetime.strptime(s_0_date_bug, "%Y-%m-%d %H:%M:%S")
        elif tool == "grimoire":
            s_0_date = query_grimoire.get_commit_date(es, p, releases.get(p))
            if s_0_date is not None:
                s_0_date = datetime.strptime(s_0_date, "%Y-%m-%dT%H:%M:%S")
            s_0_date_bug = None
        else:  # Kaiaulu
            # Here, we use the file-filtered git log.
            s_0_date = query_kaiaulu.get_commit_date(df_git_log_filtered, releases.get(p))
            if s_0_date is not None:
                s_0_date = datetime.strptime(s_0_date, "%Y-%m-%d %H:%M:%S")

            s_0_date_bug = query_kaiaulu.get_commit_date(df_git_log_filtered_bug, releases.get(p))
            if s_0_date_bug is not None:
                s_0_date_bug = datetime.strptime(s_0_date_bug, "%Y-%m-%d %H:%M:%S")

        if s_0_date is None:
            print("Could not find release commit for project "+str(p)+". Falling back to date...")
            s_0_date = releases_dates.get(p)
            s_0_date = datetime.strptime(s_0_date, "%Y-%m-%d")
        if s_0_date_bug is None:
            s_0_date_bug = releases_dates.get(p)
            s_0_date_bug = datetime.strptime(s_0_date_bug, "%Y-%m-%d")

        # Create interim data set of activity **before** the release.
        before_end_date = s_0_date
        after_start_date = s_0_date
        before_end_date_bug = s_0_date_bug
        after_start_date_bug = s_0_date_bug

        for i in range(1, 13):
            # Calculate range start in the same way as diggit.
            before_start_date = s_0_date - timedelta(seconds=3600 * 24 * 30) * i
            after_end_date = s_0_date + timedelta(seconds=3600 * 24 * 30)*i
            before_start_date_bug = s_0_date_bug - timedelta(seconds=3600 * 24 * 30)*i
            after_end_date_bug = s_0_date_bug + timedelta(seconds=3600 * 24 * 30)*i

            # Get churn and reference date.
            # The original study and the diggit tool calculate churn
            # as the sum of added and removed lines (diff).
            # The original study and the diggit tool use the first
            # commit in the range of interest as reference date.
            if tool == "codeface":
                # Get and unify edits from main branch.
                edits_before = query_codeface.get_files_info(cur, before_start_date, before_end_date, pid)
                edits_after = query_codeface.get_files_info(cur, after_start_date, after_end_date, pid)
                edits_before["releaseDate"] = min(edits_before["date"])
                edits_after["releaseDate"] = min(edits_after["date"])
                # Get and unify edits from bug branch.
                edits_before_bug = query_codeface.get_files_info(cur, before_start_date_bug, before_end_date_bug, pid_bug)
                edits_after_bug = query_codeface.get_files_info(cur, after_start_date_bug, after_end_date_bug, pid_bug)
                edits_before_bug["releaseDate"] = min(edits_before_bug["date"])
                if len(edits_after_bug) > 0:
                    edits_after_bug["releaseDate"] = min(edits_after_bug["date"])
            elif tool == "git2net":
                # Get and unify edits from main branch.
                edits_before = query_git2net.get_edits_info(cur, before_start_date, before_end_date)
                edits_after = query_git2net.get_edits_info(cur, after_start_date, after_end_date)
                edits_before["churn"] = edits_before["added"] + edits_before["removed"]
                edits_after["churn"] = edits_after["added"] + edits_after["removed"]
                edits_before["releaseDate"] = min(edits_before["committer_date"])
                edits_after["releaseDate"] = min(edits_after["committer_date"])
                # Get and unify edits from bug branch.
                edits_before_bug = query_git2net.get_edits_info(cur_bug, before_start_date_bug, before_end_date_bug)
                edits_after_bug = query_git2net.get_edits_info(cur_bug, after_start_date_bug, after_end_date_bug)
                edits_before_bug["churn"] = edits_before_bug["added"] + edits_before_bug["removed"]
                if len(edits_after_bug) > 0:
                    edits_after_bug["churn"] = edits_after_bug["added"] + edits_after_bug["removed"]
                edits_before_bug["releaseDate"] = min(edits_before_bug["committer_date"])
                if len(edits_after_bug) > 0:
                    edits_after_bug["releaseDate"] = min(edits_after_bug["committer_date"])
            elif tool == "grimoire":
                edits_before = query_grimoire.get_edits_info(es, p, before_start_date, before_end_date)
                edits_after = query_grimoire.get_edits_info(es, p, after_start_date, after_end_date)
                edits_before["releaseDate"] = min(edits_before["date"])
                edits_after["releaseDate"] = min(edits_after["date"])
                edits_before_bug = pd.DataFrame()
                edits_after_bug = pd.DataFrame()
            else:  # Kaiaulu
                # Here, we use the file-filtered git logs.
                # Get and unify edits from main branch.
                edits_before = query_kaiaulu.get_edits_info(df_git_log_filtered, before_start_date, before_end_date)
                edits_after = query_kaiaulu.get_edits_info(df_git_log_filtered, after_start_date, after_end_date)
                edits_before["releaseDate"] = min(edits_before["committer_datetimetz"])
                edits_after["releaseDate"] = min(edits_after["committer_datetimetz"])
                # Get and unify edits from bug branch.
                edits_before_bug = query_kaiaulu.get_edits_info(df_git_log_filtered_bug, before_start_date_bug, before_end_date_bug)
                edits_after_bug = query_kaiaulu.get_edits_info(df_git_log_filtered_bug, after_start_date_bug, after_end_date_bug)
                edits_before_bug["releaseDate"] = min(edits_before_bug["committer_datetimetz"])
                if len(edits_after_bug) > 0:
                    edits_after_bug["releaseDate"] = min(edits_after_bug["committer_datetimetz"])

            # Update dates.
            before_end_date = before_start_date
            after_start_date = after_end_date
            before_end_date_bug = before_start_date_bug
            after_start_date_bug = after_end_date_bug

            # Complete missing information.
            edits_before["project"] = p
            edits_before["commits_group_id"] = i
            act_months_before_list.append(edits_before)

            edits_after["project"] = p
            edits_after["commits_group_id"] = i
            act_months_after_list.append(edits_after)

            if len(edits_before_bug) > 0:
                edits_before_bug["project"] = p
                edits_before_bug["commits_group_id"] = i
                act_months_before_list_bug.append(edits_before_bug)

            if len(edits_after_bug) > 0:
                edits_after_bug["project"] = p
                edits_after_bug["commits_group_id"] = i
                act_months_after_list_bug.append(edits_after_bug)

    # Save the activity data sets.
    df_commit_dates = pd.concat(commit_dates_list, ignore_index=False)
    df_commit_dates.to_csv(os.path.join(save_path, "commit_dates.csv"), index=False)

    df_interim_act_months_before = pd.concat(act_months_before_list, ignore_index=False)
    df_interim_act_months_before = df_interim_act_months_before.drop_duplicates()
    df_interim_act_months_before.to_csv(os.path.join(save_path, "interim_act_months_before.csv"), index=False)

    df_interim_act_months_after = pd.concat(act_months_after_list, ignore_index=False)
    df_interim_act_months_after = df_interim_act_months_after.drop_duplicates()
    df_interim_act_months_after.to_csv(os.path.join(save_path, "interim_act_months_after.csv"), index=False)

    if len(act_months_before_list_bug) > 0 or len(act_months_after_list_bug) > 0:
        df_interim_act_months_bug = pd.concat(act_months_before_list_bug + act_months_after_list_bug, ignore_index=True)
        df_interim_act_months_bug = df_interim_act_months_bug.drop_duplicates()
        df_interim_act_months_bug.to_csv(os.path.join(save_path, "interim_act_months_bug.csv"))
    else:
        df_interim_act_months_bug = pd.DataFrame()

    # Assign files to modules.
    df_interim_modules_before = df_interim_act_months_before
    df_interim_modules_before["module"] = df_interim_modules_before.apply(get_module, axis=1)

    df_interim_modules_after = df_interim_act_months_after
    df_interim_modules_after["module"] = df_interim_modules_after.apply(get_module, axis=1)

    if len(df_interim_act_months_bug) > 0:
        df_interim_modules_bug = df_interim_act_months_bug
        df_interim_modules_bug["module"] = df_interim_modules_bug.apply(get_module, axis=1)
    else:
        df_interim_modules_bug = pd.DataFrame()

    # Filter data to keep only contributions that modified
    # one of the modules of interest and changed at least
    # one line.
    df_interim_modules_before = df_interim_modules_before[df_interim_modules_before["module"].notna()]
    df_interim_modules_after = df_interim_modules_after[df_interim_modules_after["module"].notna()]
    if len(df_interim_modules_bug) > 0:
        df_interim_modules_bug = df_interim_modules_bug[df_interim_modules_bug["module"].notna()]
    df_interim_modules_before = df_interim_modules_before[df_interim_modules_before["churn"] > 0]
    df_interim_modules_after = df_interim_modules_after[df_interim_modules_after["churn"] > 0]
    if len(df_interim_modules_bug) > 0:
        df_interim_modules_bug = df_interim_modules_bug[df_interim_modules_bug["churn"] > 0]

    # Save the interim data.
    df_interim_modules_before.to_csv(os.path.join(save_path, "interim_modules_before.csv"),
                                       index=False)
    df_interim_modules_after.to_csv(os.path.join(save_path, "interim_modules_after.csv"),
                                       index=False)
    if len(df_interim_modules_bug) > 0:
        df_interim_modules_bug.to_csv(os.path.join(save_path, "interim_modules_bug.csv"),
                                      index=False)

    if len(df_interim_modules_bug) > 0:
        df_interim_modules = pd.concat([df_interim_modules_before, df_interim_modules_after, df_interim_modules_bug],
                                       ignore_index = True)
    else:
        df_interim_modules = pd.concat([df_interim_modules_before, df_interim_modules_after], ignore_index = True)
    df_interim_modules = df_interim_modules.drop("developer", axis=1)
    df_interim_modules.to_csv(os.path.join(save_path, "interim_modules.csv"))
    df_interim_modules = df_interim_modules.drop_duplicates()
    df_interim_modules.to_csv(os.path.join(save_path, "interim_modules_without_duplicates.csv"))

    # Aggregate stats per module, developer and time interval.
    df_act_months_before = (
        df_interim_modules_before.groupby(["project", "module", "developer", "commits_group_id"])
        .agg(touches=("hash", "nunique"),
             churn=("churn", "sum"),
             releaseDate=("releaseDate", "first"))
        .reset_index()
    )
    df_act_months_before.to_csv(os.path.join(save_path, "act_months_before.csv"),
                                index=False)

    df_act_months_after = (
        df_interim_modules_after.groupby(["project", "module", "developer", "commits_group_id"])
        .agg(touches=("hash", "nunique"),
             churn=("churn", "sum"),
             releaseDate=("releaseDate", "first"))
        .reset_index()
    )
    df_act_months_after.to_csv(os.path.join(save_path, "act_months_after.csv"),
                                index=False)

    # RQ2/RQ3: Patterns of turnover and software quality.
    # Calculate LoC stats per module using CLOC.
    file_list = []
    for p in projects:
        project_git_path = os.path.join(git_repo_path, p)
        project_yaml_path = os.path.join(save_path, p+".yml")
        subprocess.run(
            ["cloc", project_git_path,
             "--progress-rate=0",
             "--quiet",
             "--by-file",
             "--yaml", "--out", project_yaml_path,
             "--script-lang=Python,python"],
            check=True
        )

        # Get file names and LoC from cloc yaml.
        with open(project_yaml_path, "r") as f:
            data = yaml.safe_load(f)

        for file_path, stats in list(data.items())[1:-1]:
            file_path = file_path.replace(project_git_path+"/", "")
            loc = stats.get("code", 0)
            entry = pd.DataFrame.from_dict({
                "project": [p],
                "file": [file_path],
                "LoC": [loc]})
            file_list.append(entry)

    # Combine data set.
    df_cloc = pd.concat(file_list, ignore_index=True)

    # Annotate cloc outputs with module matched by
    # regular expression as done by diggit.
    df_cloc["module"] = df_cloc.apply(get_module, axis=1)

    # Remove files that do not belong to the modules of
    # interest or do not contain any code.
    df_cloc = df_cloc[df_cloc["module"].notna()]
    df_cloc = df_cloc[df_cloc["LoC"] > 0]
    df_cloc.to_csv(os.path.join(save_path, "file_module_loc.csv"), index=False)

    # Optional extensions: We could further filter
    # files that were detected by our tools.
    df_cloc_filtered = df_cloc[df_cloc["file"].isin(df_interim_modules["file"])]
    df_cloc_filtered.to_csv(os.path.join(save_path, "file_module_loc_filtered.csv"), index=False)

    # Aggregate LoC per module.
    df_mod = (df_cloc.groupby(["project", "module"]).agg(LoC=("LoC", "sum")).reset_index())

    # Version with tool-detected file filtering.
    df_mod_filtered = (df_cloc_filtered.groupby(["project", "module"]).agg(LoC=("LoC", "sum")).reset_index())

    # Extract bug-fixing commits and aggregate them per module.
    with open(bug_fix_path, "r") as f:
        bug_fixes = yaml.safe_load(f)

    df_mod["BugFixes"] = df_mod.apply(get_bugfixes, axis=1, args=(df_interim_modules, bug_fixes))
    df_mod["BugDensity"] = df_mod["BugFixes"] / df_mod["LoC"]
    df_mod.to_csv(os.path.join(save_path, "mod_m.csv"), index=False)

    df_mod_filtered["BugFixes"] = df_mod_filtered.apply(get_bugfixes, axis=1, args=(df_interim_modules, bug_fixes))
    df_mod_filtered["BugDensity"] = df_mod_filtered["BugFixes"] / df_mod_filtered["LoC"]
    df_mod_filtered.to_csv(os.path.join(save_path, "mod_m_filtered.csv"), index=False)


if __name__ == "__main__":
    args = arguments()
    main(args.tool, args.data_path, args.git_repo_path,
         args.bug_fix_path, args.save_path,
         args.projects)
