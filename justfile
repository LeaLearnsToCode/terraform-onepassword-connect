#!/usr/bin/env -S just --justfile
# File is source from LeaLearnsToCode/base-repo-template
# Do not modify
set windows-shell := ["powershell.exe",  "-NoLogo", "-Command"]

log := "warn"
export JUST_LOG := log

# run github/super-linter locally
super-linter:
  docker run --rm \
    -e RUN_LOCAL=true \
    -e USE_FIND_ALGORITHM=true \
    -e VALIDATE_ALL_CODEBASE=true \
    --env-file ".github/super-linter.env" \
    -v {{justfile_directory()}}:/tmp/lint \
    github/super-linter:v4

# Local Variables:
# mode: makefile
# End:
# vim: set ft=make :
