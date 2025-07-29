# Neovim Deployment Plugin

Neovim plugin for syncing files and projects to remote clusters via `rsync`, inspired by PyCharm's deployment feature.

Easily push or pull individual files or full projects between your local workspace and remote clusters using simple Vim commands.

---

## ✨ Features

- 🔁 Sync on `:w` (auto-push on save)
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

## 📌 Requirements

- `rsync` installed locally
- `ssh` access to your cluster
- `config.lua` config file

### 📁 Required Config File

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

  -- Local root directory for project detection
  PROJECT_ROOTS = {
    os.getenv("HOME") .. "/projects",
  },

  PROJECT_EXCLUDE_PATTERNS = {
    myproject = "*.zarr *.npy",
  },

  PROJECT_EXCLUDE_DIRS = {
    myproject = "__pycache__/ data_cache/",
  },
}
```

## 🔑 Available Commands

Command                | Description
-----------------------|------------------------------------------
`:SyncSet <cluster>`   | Set the current active cluster
`:SyncClear`           | Clear active cluster
`:SyncStatus`          | Show current sync cluster info
`:SyncPushProject`     | Push the full project to the cluster
`:SyncPullProject`     | Pull the full project from the cluster
`:SyncPushFile <file>` | Push a specific file (relative to project)
`:SyncPullFile <file>` | Pull a specific file (relative to project)

**Note**: After `:SyncSet`, every `:w` will auto-push the current file.

