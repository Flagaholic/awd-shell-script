#!/usr/bin/env zsh
# awd.sh
# Minimal: init / import(from .xls) / pull / list / push / exec

set -e
set -u
set -o pipefail

AWSH_DIR="${HOME}/.ssh/awd"
KEY_DIR="${AWSH_DIR}/keys"
HOSTS_CONF="${AWSH_DIR}/hosts.conf"
MARK_BEGIN="# --- AWD BEGIN"
MARK_END="# --- AWD END"
DEFAULT_USER="ctf"

die() { print -ru2 "error: $*"; exit 1; }

ensure_dirs() {
  mkdir -p "${KEY_DIR}"
  chmod 700 "${HOME}/.ssh" 2>/dev/null || true
  chmod 700 "${AWSH_DIR}" 2>/dev/null || true
  chmod 700 "${KEY_DIR}" 2>/dev/null || true
  touch "${HOSTS_CONF}"
  chmod 600 "${HOSTS_CONF}" 2>/dev/null || true
}

ensure_include() {
  local cfg="${HOME}/.ssh/config"
  touch "${cfg}"
  chmod 600 "${cfg}" 2>/dev/null || true

  if ! grep -qF "Include ${HOSTS_CONF}" "${cfg}" 2>/dev/null; then
    {
      print ""
      print "# AWD ssh config (auto-managed)"
      print "Include ${HOSTS_CONF}"
    } >> "${cfg}"
  fi
}

remove_block() {
  local key="$1"
  local tmp
  tmp="$(mktemp)"
  awk -v b="${MARK_BEGIN} ${key} ---" -v e="${MARK_END} ${key} ---" '
    $0==b {skip=1; next}
    $0==e {skip=0; next}
    skip==0 {print}
  ' "${HOSTS_CONF}" > "${tmp}"
  cat "${tmp}" > "${HOSTS_CONF}"
  rm -f "${tmp}"
}

append_host_block() {
  local host="$1" hostname="$2" user="$3" keyfile="$4"
  {
    print "${MARK_BEGIN} ${host} ---"
    print "Host ${host}"
    print "  HostName ${hostname}"
    print "  User ${user}"
    print "  IdentityFile ${keyfile}"
    print "  IdentitiesOnly yes"
    print "  StrictHostKeyChecking no"
    print "  UserKnownHostsFile /dev/null"
    print "${MARK_END} ${host} ---"
    print ""
  } >> "${HOSTS_CONF}"
}

cmd_init() {
  ensure_dirs
  ensure_include
  print "ok: initialized"
}

cmd_import() {
  local xls="${1:-}"
  local user="${2:-$DEFAULT_USER}"
  [[ -n "${xls}" ]] || die "usage: import <challenge.xls> [user]"

  ensure_dirs
  ensure_include

  local alias_name ip url keyfile
  alias_name="${xls:t:r}"

  ip="$(LC_ALL=C strings -a -- "${xls}" | awk '
    $0=="Login Info"{f=1; next}
    f && $0 ~ /^[0-9]{1,3}(\.[0-9]{1,3}){3}$/ {print; exit}
  ')"

  url="$(LC_ALL=C strings -a -- "${xls}" | grep -Eo 'https?://[^[:space:]]+\.pem' | head -n1)"

  keyfile="${KEY_DIR}/${alias_name}.pem"
  wget -qO "${keyfile}" -- "${url}"
  chmod 600 "${keyfile}"

  remove_block "${ip}"
  append_host_block "${ip}" "${ip}" "${user}" "${keyfile}"

  remove_block "${alias_name}"
  append_host_block "${alias_name}" "${ip}" "${user}" "${keyfile}"

  print "ok: ${alias_name} -> ${user}@${ip}"
  print "try: ssh ${alias_name}"
}

cmd_pull() {
  local host="${1:-}" remote="${2:-}" localdir="${3:-.}"
  [[ -n "${host}" && -n "${remote}" ]] || die "usage: pull <alias_or_ip> <remote_path> [local_dir]"
  mkdir -p -- "${localdir}"
  scp -r -- "${host}:${remote}" "${localdir}/"
  print "ok: pulled"
}

cmd_push() {
  local host="${1:-}" localpath="${2:-}" remotepath="${3:-}"
  [[ -n "${host}" && -n "${localpath}" && -n "${remotepath}" ]] || die "usage: push <alias_or_ip> <local_path> <remote_path>"
  if [[ -d "${localpath}" ]]; then
    scp -r -- "${localpath}" "${host}:${remotepath}"
  else
    scp -- "${localpath}" "${host}:${remotepath}"
  fi
  print "ok: pushed"
}

cmd_exec() {
  local host="${1:-}"
  shift 2>/dev/null || true
  [[ -n "${host}" ]] || die "usage: exec <alias_or_ip> <command...>"
  ssh "${host}" "$@"
}

cmd_list() {
  ensure_dirs
  sed -n 's/^Host \(.*\)$/\1/p' "${HOSTS_CONF}" | sed '/^[[:space:]]*$/d' || true
}

main() {
  local cmd="${1:-}"
  shift 2>/dev/null || true

  case "${cmd}" in
    init)   cmd_init "$@" ;;
    import) cmd_import "$@" ;;
    pull)   cmd_pull "$@" ;;
    push)   cmd_push "$@" ;;
    exec)   cmd_exec "$@" ;;
    list)   cmd_list "$@" ;;
    *)
      print -ru2 "usage:"
      print -ru2 "  awd init"
      print -ru2 "  awd import <challenge.xls> [user]"
      print -ru2 "  awd pull <alias_or_ip> <remote_path> [local_dir]"
      print -ru2 "  awd push <alias_or_ip> <local_path> <remote_path>"
      print -ru2 "  awd exec <alias_or_ip> <command...>"
      print -ru2 "  awd list"
      exit 1
      ;;
  esac
}

main "$@"
