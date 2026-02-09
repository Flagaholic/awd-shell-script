# awd-shell-script


## Setup

Please add the following alias setup into the bottom of your ~/.zshrc  

```sh
# awd setup
export AWDSSH_SCRIPT="${AWDSSH_SCRIPT:-$HOME/bin/awd.sh}"

awd() {
  local script="$AWDSSH_SCRIPT"
  local cmd="${1:-help}"
  shift 2>/dev/null || true

  case "$cmd" in
    init|i)   zsh "$script" init "$@" ;;
    import|x) zsh "$script" import "$@" ;;  # awd import ezjava.xls
    pull|p)   zsh "$script" pull "$@" ;;
    push|u)   zsh "$script" push "$@" ;;
    exec|e)   zsh "$script" exec "$@" ;;
    list|l)   zsh "$script" list ;;
    *)
      print -r -- "usage:"
      print -r -- "  awd init"
      print -r -- "  awd import <challenge.xls> [user]"
      print -r -- "  awd pull <alias_or_ip> <remote_path> [local_dir]"
      print -r -- "  awd push <alias_or_ip> <local_path> <remote_path>"
      print -r -- "  awd exec <alias_or_ip> <command...>"
      print -r -- "  awd list"
      return 1
      ;;
  esac
}
```

After that, run `awd init` to initialize, then you may import your .xls file to automatically setup SSH keys.
