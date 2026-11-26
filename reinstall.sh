#!/usr/bin/env bash

set -e

codex plugin remove egm@egm
codex plugin add egm@egm

echo "EGM plugin reinstalled successfully."
