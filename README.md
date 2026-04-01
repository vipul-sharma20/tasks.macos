# tasks.macos

macOS menu bar utility for [tasks.nvim](https://github.com/vipul-sharma20/tasks.nvim).

This provides a read-only view of tasks (& filter sections) and is intended to
be used along with tasks.nvim.

## Prerequisites

- macOS 13+
- [ripgrep](https://github.com/BurntSushi/ripgrep) (`brew install ripgrep`)
- A markdown vault with `#task` items (see [task format](https://github.com/vipul-sharma20/tasks.nvim#task-format-reference))

## Build & Run

```bash
make run
```

## Install

```bash
make install  # builds .app bundle → /Applications/TaskBar.app
```

## Vault Path

Resolved in order:

1. `TASKS_VAULT_PATH` environment variable
2. `~/.config/taskbar/config.json` → `{"vault_path": "~/your/vault"}`
3. Default: `~/vault`

## License

MIT
