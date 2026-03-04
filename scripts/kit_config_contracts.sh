#!/usr/bin/env bash
# Shared config validation contracts used by local quality gates.

validate_bootstrap_config_file() {
  local validator_script="$1"
  local config_file="$2"

  bash "$validator_script" \
    --file "$config_file" \
    --required project_name \
    --required required_skills \
    --required startup_read_order \
    --required required_files \
    --required exclude_paths \
    --required entry_points \
    --required task_routing \
    --type project_name:string \
    --type required_skills:array \
    --type startup_read_order:array \
    --type required_files:array \
    --type exclude_paths:array \
    --type entry_points:object \
    --type task_routing:object
}

validate_taskflow_config_file() {
  local validator_script="$1"
  local config_file="$2"

  bash "$validator_script" \
    --file "$config_file" \
    --required workflow_name \
    --required version \
    --required out_dir \
    --required steps \
    --required artifacts \
    --type workflow_name:string \
    --type version:string \
    --type out_dir:string \
    --type steps:array \
    --type artifacts:object
}
