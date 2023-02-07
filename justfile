#!/usr/bin/env -S just --justfile
# File is source from LeaLearnsToCode/base-repo-template
# Do not modify
set dotenv-load
set windows-shell := ["pwsh.exe",  "-NoLogo", "-Command"]

log := "warn"
export JUST_LOG := log

# build onepassword-connect ami with packer
[windows]
packer-onepassword:
  packer build \
    -var "dockerhub_user=$Env:DOCKERHUB_USER" \
    -var "dockerhub_pat=$Env:DOCKERHUB_PAT" \
    -var "onepassword_secret_id=$Env:ONEPASSWORD_SECRET_ID" \
    packer/onepassword-connect.pkr.hcl

# install dev dependencies
[windows]
install-dev-dependencies:
  scoop install packer

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
