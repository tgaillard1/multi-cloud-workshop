#!/usr/bin/env bash

$BASE_DIR/spinnaker-for-gcp/scripts/manage/push_config.sh || exit 1
$BASE_DIR/spinnaker-for-gcp/scripts/manage/apply_config.sh
