#!/usr/bin/env bash

# Run periodic backups in the background
su-exec postgres backup &
