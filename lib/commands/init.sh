# shellcheck shell=bash
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
# lib/commands/init.sh: scaffold a starter config. Default writes a per-project
# .scc.conf here (and trusts it for you); --global writes the global config.
# The templates are generated FROM the allowlists (SCC_PROJ_ALLOWED /
# SCC_CFG_ALLOWED) so a newly-allowed key shows up automatically.
# SCC_PROJECT_FILE / SCC_CONFIG_FILE and the allowlists come from other modules.
# shellcheck disable=SC2154

# A concrete example value for a config key, used only in the commented template.
scc_init_example() {
  case "$1" in
    image)         printf 'ghcr.io/sensitivewebuser/sandbox-claude-code:latest' ;;
    volume)        printf 'scc-home' ;;
    pids_limit)    printf '2048' ;;
    firewall)      printf 'on' ;;
    extra_domains) printf 'example.com,cdn.example.org' ;;
    docker_args)   printf -- '--memory 8g' ;;
    profile)       printf 'work' ;;
    toolchains)    printf 'python,node' ;;
    clipboard)     printf 'on' ;;
    *)             printf '' ;;
  esac
}

scc_init_project() {  # $1=force
  scc_guard_workdir
  local file="$PWD/$SCC_PROJECT_FILE" key
  if [ -e "$file" ] && [ "$1" != 1 ]; then
    scc_die "$SCC_PROJECT_FILE already exists in $PWD (use --force to overwrite, or edit it and run 'scc trust')"
  fi
  {
    printf '# %s: per-project scc config for this repo.\n' "$SCC_PROJECT_FILE"
    printf '# Trust-gated: scc ignores it until trusted, and it may set ONLY the\n'
    printf '# keys below. A project may tighten the sandbox, never loosen it\n'
    printf '# (firewall can be turned on, never off). Uncomment what you need:\n#\n'
    for key in "${SCC_PROJ_ALLOWED[@]}"; do
      printf '# %s = %s\n' "$key" "$(scc_init_example "$key")"
    done
  } > "$file" || scc_die "could not write $file"
  scc_info "wrote $file"

  # Auto-trust: you authored this file, so trust its current contents for
  # yourself. Trust is keyed to the checksum, so editing it re-gates (scc will
  # prompt once), and anyone who clones the repo is still gated.
  local hash
  if hash="$(scc_file_sha256 "$file")"; then
    scc_project_trust_add "$file" "$hash"
    scc_info "trusted it for you. Edit it and scc will re-check once; collaborators run 'scc trust'."
  else
    scc_warn "could not hash the file to trust it; edit it, then run 'scc trust'"
  fi
}

scc_init_global() {  # $1=force
  local file="$SCC_CONFIG_FILE" key
  if [ -e "$file" ] && [ "$1" != 1 ]; then
    scc_die "$file already exists (use --force to overwrite)"
  fi
  mkdir -p "$(dirname "$file")" || scc_die "could not create $(dirname "$file")"
  {
    printf '# scc global config. key = value, one per line. Everything optional.\n'
    printf '# Precedence: these < project .scc.conf < environment < CLI flags.\n'
    printf '# Uncomment what you need:\n#\n'
    for key in "${SCC_CFG_ALLOWED[@]}"; do
      printf '# %s = %s\n' "$key" "$(scc_init_example "$key")"
    done
  } > "$file" || scc_die "could not write $file"
  scc_info "wrote $file (all keys commented; uncomment what you need)"
}

cmd_init() {
  local global=0 force=0 a
  for a in "$@"; do
    case "$a" in
      --global)    global=1 ;;
      --force|-f)  force=1 ;;
      -h|--help)
        cat <<'EOF'
scc init: write a starter scc config

  scc init            Write a .scc.conf in this directory and trust it for you
  scc init --global   Write the global config file (~/.config/scc/config)
  scc init --force    Overwrite an existing file

The templates are fully commented; uncomment what you want. A project .scc.conf
may set only a safe subset (toolchains, firewall-on) and is trust-gated.
EOF
        return 0 ;;
      *) scc_die "init: unknown option '$a' (try --global, --force, --help)" ;;
    esac
  done
  if [ "$global" = 1 ]; then scc_init_global "$force"; else scc_init_project "$force"; fi
}
