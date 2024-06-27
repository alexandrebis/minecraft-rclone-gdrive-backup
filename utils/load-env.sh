#!/bin/bash

# Verify presence of .env.dist and .env. Copy if does not exist
if [ ! -f ".env" ]; then
  if [ ! -f ".env.dist" ]; then
    log "Error : No .env.dist file found" && exit 1
  fi
  cp .env.dist .env
  sed -i 1d .env
fi

set -a
source .env
set +a

