#!/usr/bin/env -S just --justfile
# File is source from LeaLearnsToCode/base-repo-template
# Do not modify
set dotenv-load
set windows-shell := ["pwsh.exe",  "-NoLogo", "-Command"]

log := "warn"
export JUST_LOG := log

@_default:
    just -l

# terraform init
terraform-init:
  terraform init

# terraform plan
terraform-plan:
  op run -- terraform plan \
    -var "app_env={{_app_env}}"

#-var "git_tag={{git_tag}}"

# terraform apply
terraform-apply: _constrain_prod_mode
  op run -- terraform apply \
    -var "app_env={{_app_env}}"

# terraform destroy
terraform-destroy: _constrain_prod_mode
  op run -- terraform destroy \
    -var "app_env={{_app_env}}"

# packer init
packer-init:
  packer init packer

# packer build onepassword-connect ami
packer-build: _constrain_prod_mode
  op run -- packer build \
    -var "app_env={{_app_env}}" \
    -var "promoted=false" \
    -var "git_sha={{git_sha}}{{ if _has_local_changes == "true" { " with local changes" } else { "" } }}" \
    -var "git_branch={{git_branch}}" \
    -var "git_repo=github.com/{{github_repo}}" \
    -var "git_commit=github.com/{{github_repo}}/commit/{{git_sha}}" \
    -var "git_tag={{git_tag}}" \
    packer/onepassword-connect.pkr.hcl

# signin to onepassword
[windows]
op-signin:
  op signin -f

# signin to onepassword
[linux]
op-signin:
  eval $(op signin)

# install development dependencies for this project
[windows]
install-dependencies:
  scoop install sed
  scoop install packer
  scoop install terraform

# install the onepassword cli
[windows]
install-onepassword:
  scoop install 1password-cli

# install development dependencies for this project
[linux]
install-dependencies-ubuntu:
  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor \
    --output /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] "\
    "https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list

  sudo apt update
  sudo apt install packer terraform
  packer --version
  terraform --version


#install 1password cli
[linux]
install-onepassword-ubuntu:
  curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
    sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] " \
    "https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
    sudo tee /etc/apt/sources.list.d/1password.list
  sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
  curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | \
    sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
  sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
  curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
    sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg

  sudo apt update
  sudo apt install 1password-cli
  op --version

# run github/super-linter locally
lint:
  docker run --rm \
    -e RUN_LOCAL=true \
    -e USE_FIND_ALGORITHM=true \
    -e VALIDATE_ALL_CODEBASE=true \
    --env-file ".github/super-linter.env" \
    -v {{justfile_directory()}}:/tmp/lint \
    github/super-linter:v4

# TODO: only supports ssh cloning is good enough for me
github_repo := `git remote get-url origin | sed s/git@github\.com://g | sed s/\.git//g | xargs`
git_branch := `git branch --show-current`
git_sha := `git rev-parse HEAD`
git_tag := `git tag --points-at HEAD`

_app_env := env_var_or_default("APP_ENV", "development")
_is_prod_mode := if _app_env == "production" { "true" } else { "false" }
_has_local_changes := if `git status --porcelain` != "" { "true" } else { "false" }
_on_main := if git_branch == "main" { "true" } else { "false" }

# Blocks running a command in prod mode
[windows]
[no-exit-message]
@_constrain_prod_mode:
  echo "Running in {{_app_env}} mode{{ if _app_env == "production" { "!!!!" } else { "." } }}"
  if(${{_is_prod_mode}}) { \
    if(${{_has_local_changes}}) { echo "No Local Changes Allowed In Production Mode"; exit 1 } \
    if(!${{_on_main}}) { echo "You must be on main to deploy in production mode"; exit 1 } \
  }

# Blocks running a command in prod mode
[linux]
[no-exit-message]
_constrain_prod_mode:
  #!/usr/bin/env bash
  echo "Running in {{_app_env}} mode{{ if _app_env == "production" { "!!!!" } else { "." } }}"
  if {{_is_prod_mode}}; then
    if {{_has_local_changes}}; then
      echo "No Local Changes Allowed In Production Mode"
      exit 1
    fi
    if !{{ _on_main }}; then
      echo "You must be on main to deploy in production mode"
      exit 1
    fi
  fi

# Local Variables:
# mode: makefile
# End:
# vim: set ft=make :
