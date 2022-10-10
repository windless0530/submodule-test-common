#! /usr/bin/env bash

###############################################################################
# Copyright 2020 The Apollo Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################

set -e

TOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=./autra.bashrc
source "${TOP_DIR}/scripts/autra.bashrc"

: ${STAGE:=dev}

PYTHON_LINT_FLAG=0
CPP_LINT_FLAG=0
SHELL_LINT_FLAG=0
JS_LINT_FLAG=0
CPPLINT_BAZEL_TARGET="//buildtools:cpplint"
CPPLINT_PATH="${TOP_DIR}/bazel-bin/buildtools/cpplint"

## Pretty Print
RED='\033[31m'
NO_COLOR='\033[0m'

# function _cpp_lint_impl() {
#   bazel test --config=cpplint "$@"
# }

function _cpp_lint_file() {
  $CPPLINT_PATH "$@" 2>&1 1>/dev/null || true
}

function run_cpp_lint() {
  pushd "${AUTRA_ROOT_DIR}" >/dev/null
  bazel build $CPPLINT_BAZEL_TARGET

  local base_commit_sha=$(git merge-base HEAD origin/master)
  local modified_file_list=$(git diff ${base_commit_sha} --name-only --diff-filter=ACM \
    | awk '{print $1}' \
    | grep -E "\.(h|cc|cpp|c)$")
  local format_output=()
  for modified_file in $modified_file_list
  do
    local dir_list=(${modified_file//\// })
    local top_dir=${dir_list[0]}
    # If top_dir is in AUTRA_DEV_DIRS
    local re="\b${top_dir}\b"
    if [[ "$AUTRA_DEV_DIRS" =~ $re ]]; then
      while read line; do
        if [[ -z "${line}" ]]; then
          continue
        fi
        format_output+=("$line");
      done <<< $(_cpp_lint_file "${AUTRA_ROOT_DIR}/${modified_file}")
    fi
  done

  if [[ ${#format_output[@]} -gt 0 ]]; then
    echo -e ${RED}"Cpplint failed! Please fix the following issues. For automatic code-format tools, refer to:" \
      "https://bg4kuaip34.feishu.cn/wiki/wikcn4V4T6vpYtZ7bVmARnqMYeb"${NO_COLOR}
    for output in "${format_output[@]}"; do
      echo ${output}
    done
    exit 1
  fi

  popd >/dev/null
}

function run_sh_lint() {
  local shellcheck_cmd
  shellcheck_cmd="$(command -v shellcheck)"
  if [ -z "${shellcheck_cmd}" ]; then
    warning "Command 'shellcheck' not found. For Debian/Ubuntu systems," \
      "please run the following command to install it: "
    warning "  sudo apt-get -y update"
    warning "  sudo apt-get -y install shellcheck"
    exit 1
  fi
  local sh_dirs="cyber scripts docker tools"
  if [[ "${STAGE}" == "dev" ]]; then
    sh_dirs="modules ${sh_dirs}"
  fi

  sh_dirs=$(printf "${AUTRA_ROOT_DIR}/%s " ${sh_dirs})
  run find ${sh_dirs} -type f \( -name "*.sh" -or -name "*.bashrc" \) -exec \
    shellcheck -x --shell=bash {} +

  for script in ${AUTRA_ROOT_DIR}/*.sh; do
    run shellcheck -x --shell=bash "${script}"
  done
}

function run_py_lint() {
  pushd "${AUTRA_ROOT_DIR}" >/dev/null
  echo "Start to run python lint..."
  if [ -z "$(command -v flake8)" ]; then
    echo "\e[31mCommand flake8 not found. You can install it manually via:"
    echo "  '[sudo -H] python3 -m pip install flake8'\e[0m"
    exit 1
  fi

  if [ -z "$(command -v pylint)" ]; then
    echo "\e[31mCommand pylint not found. You can install it manually via:"
    echo "  '[sudo -H] python3 -m pip install pylint'\e[0m"
    exit 1
  fi

  local base_commit_sha=$(git merge-base HEAD origin/master)
  local modified_file_list=$(git diff ${base_commit_sha} --name-only --diff-filter=ACM \
    | grep -E "\.py$")
  for modified_file in $modified_file_list
  do
    echo "Running flake8 on ${modified_file}"
    flake8 --config ${TOP_DIR}/.flake8 ${modified_file}
    echo "Running pylint on ${modified_file}"
    pylint --rcfile=${TOP_DIR}/.pylintrc ${modified_file}
  done
  echo "Finish python lint."
  popd >/dev/null
}

function run_js_lint() {
  :
}

function print_usage() {
  info "Usage: $0 [Options]"
  info "Options:"
  info "${TAB}--py        Lint Python files"
  info "${TAB}--sh        Lint Bash scripts"
  info "${TAB}--cpp       Lint cpp source files"
  info "${TAB}--js        Lint js source files"
  info "${TAB}-a|--all    Lint all. Equivalent to \"--py --sh --cpp\""
  info "${TAB}-h|--help   Show this message and exit"
}

function parse_cmdline_args() {
  # Enable python and cpp lint by default
  if [[ "$#" -eq 0 ]]; then
    CPP_LINT_FLAG=1
    PYTHON_LINT_FLAG=1
    return 0
  fi

  while [[ "$#" -gt 0 ]]; do
    local opt="$1"
    shift
    case "${opt}" in
      --py)
        PYTHON_LINT_FLAG=1
        ;;
      --cpp)
        CPP_LINT_FLAG=1
        ;;
      --sh)
        SHELL_LINT_FLAG=1
        ;;
      --js)
        JS_LINT_FLAG=1
        ;;
      -a | --all)
        PYTHON_LINT_FLAG=1
        CPP_LINT_FLAG=1
        SHELL_LINT_FLAG=1
        JS_LINT_FLAG=1
        ;;
      -h | --help)
        print_usage
        exit 0
        ;;
      *)
        warning "Unknown option: ${opt}"
        print_usage
        exit 1
        ;;
    esac
  done
}

function main() {
  parse_cmdline_args "$@"
  if [[ "${CPP_LINT_FLAG}" -eq 1 ]]; then
    run_cpp_lint
  fi
  if [[ "${PYTHON_LINT_FLAG}" -eq 1 ]]; then
    run_py_lint
  fi

  if [[ "${SHELL_LINT_FLAG}" -eq 1 ]]; then
    run_sh_lint
  fi

  if [[ "${JS_LINT_FLAG}" -eq 1 ]]; then
    run_js_lint
  fi
}

main "$@"
