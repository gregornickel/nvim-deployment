# Neovim Deployment Plugin

Neovim plugin for syncing files and projects to remote clusters via `rsync`, inspired by PyCharm's deployment feature.

Easily push or pull individual files or full projects between your local workspace and remote clusters using simple Vim commands.

---

## ✨ Features

- 🔄 Sync on `:w` (auto-push on save)
- 📦 Full project push/pull via rsync
- 📄 Single file push/pull by relative path
- 🖥️ Multi-cluster support via external config
- 🧠 Remembers current cluster across operations

---

## ⚙️ Installation (with Lazy.nvim)

Add the plugin like this to your Lazy plugin spec (e.g. inside `~/.config/nvim/lua/plugins/deployment.lua`):

```lua
return {
  "gregornickel/nvim-deployment",
  name = "deployment",
  lazy = true,  -- load only when one of the defined commands is used
  cmd = {"SyncSet", "SyncClear", "SyncStatus", "SyncPushProject", "SyncPullProject", "SyncPushFile", "SyncPullFile"},
  config = function()
    require("deployment").setup({
      config = "~/.cluster_sync/config.lua",  -- path to your config file
    })
  end,
}
```

Then run:
```vim
:Lazy sync
```

## 📋 Requirements and Setup

- `rsync` installed on both local and remote machines
- `ssh` access to your cluster
- `config.lua` config file

### Config File

Create a file at `~/.cluster_sync/config.lua` like this:

```lua
-- Cluster sync configuration for nvim-deployment
-- e.g.: ~/.cluster_sync/config.lua

return {
  -- SSH username
  CLUSTERS_USER = {
    mycluster = "username",
  },

  -- SSH host (must match ~/.ssh/config or reachable host)
  CLUSTERS_HOST = {
    mycluster = "example.com",
  },

  -- Base remote directory where projects should be located
  CLUSTERS_DIR = {
    mycluster = "/home/username",
  },

  -- Local root directories where projects are stored
  PROJECT_ROOTS = {
    os.getenv("HOME") .. "/projects",
  },

  -- Optional
  PROJECT_EXCLUDE_PATTERNS = {
    myproject = "*.zarr *.npy",
  },

  -- Optional
  PROJECT_EXCLUDE_DIRS = {
    myproject = "__pycache__/ data_cache/",
  },
}
```
- `mycluster` is a short name you define to refer to a remote cluster. It's used with `:SyncSet` (e.g. `:SyncSet mycluster`) and maps to the corresponding SSH login details in your config. It does not need to match any alias in your `~/.ssh/config`.
- SSH access is done via `username@host` using the values from `CLUSTERS_USER` and `CLUSTERS_HOST`. For smooth usage, you should have passwordless SSH (e.g. via SSH keys) set up for each cluster.
- `myproject` is the name of your local project folder. It's used to apply file and directory exclusions. This folder must exist inside one of the directories listed in `PROJECT_ROOTS`.


## 🔧 Commands

| Command                | 🔧| Description                                                                   |
|------------------------|---|-------------------------------------------------------------------------------|
| `:SyncSet <cluster>`   |   | Set the current active cluster                                                |
| `:SyncClear`           |   | Clear active cluster                                                          |
| `:SyncStatus`          |   | Show active cluster info                                                      |
| `:w`                   | 🔄| Automatically pushes the current file when a cluster is set                   |
| `:SyncPushProject`     | ⬆️ | Push the full project to the cluster                                          |
| `:SyncPullProject`     | ⬇️ | Pull the full project from the cluster                                        |
| `:SyncPushFile <file>` | ⤴️ | Push a specific file (relative to your project root, e.g. `scripts/train.py`) |
| `:SyncPullFile <file>` | ⤵️ | Pull a specific file (relative to your project root, e.g. `scripts/train.py`) |

👉 Before using any sync commands, make sure to run `:SyncSet <cluster>` to have an active target.

