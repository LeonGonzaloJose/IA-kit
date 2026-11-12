#!/usr/bin/env bash
exec bash "$(dirname "${BASH_SOURCE[0]}")/harness.sh" --hook guard --no-contract
