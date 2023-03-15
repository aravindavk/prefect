#!/bin/bash

curl -fsSL https://github.com/aravindavk/prefect/releases/latest/download/prefect-`uname -m | sed 's|aarch64|arm64|' | sed 's|x86_64|amd64|'` -o /tmp/prefect

install /tmp/prefect /usr/bin/prefect
