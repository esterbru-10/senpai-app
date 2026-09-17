#!/bin/zsh
set -eu

project_dir="${0:A:h}"
matlab_bin="${MATLAB_BIN:-/Applications/MATLAB_R2025b_Compiler.app/bin/matlab}"

if [[ ! -x "$matlab_bin" ]]; then
  echo "MATLAB R2025b with MATLAB Compiler was not found: $matlab_bin" >&2
  exit 1
fi

escaped_project=${project_dir//\'/\'\'}
"$matlab_bin" -batch "cd('$escaped_project'); buildSenpaiStandalone(Package=true,RuntimeDelivery=\"web\")"
