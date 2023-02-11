#!/usr/bin/env -S just --justfile
# File is source from LeaLearnsToCode/base-repo-template
# Do not modify
set dotenv-load
set windows-shell := ["pwsh.exe",  "-NoLogo", "-Command"]

log := "warn"
export JUST_LOG := log

terraform-apply:
  op run -- terraform apply

terraform-destroy:
  op run -- terraform destroy

# build onepassword-connect ami with packer
[windows]
packer-onepassword:
  @$rev=(git rev-parse "@")
  op run -- packer build \
    -var "commit_hash=$rev" \
    -var "source_repo=LOCAL" \
    packer/onepassword-connect.pkr.hcl

# install dev dependencies
[windows]
install-dev-dependencies:
  scoop install packer
  scoop install terraform
  scoop install onepassword-cli

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
