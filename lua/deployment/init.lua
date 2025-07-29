-- lua/deployment/init.lua
--
-- :SyncSet <name>      – Set the active cluster
-- :SyncClear           – Clear/reset the active cluster
-- :SyncStatus          – Print the current cluster
-- :w                   – Trigger auto-push of the current file via the on-save hook
-- :SyncPushProject     – Push the full project
-- :SyncPullProject     – Download the full project
-- :SyncPushFile <name> – Push the named file
-- :SyncPullFile <name> – Pull the named file
--

local M = {}

local cfg = {}
local active_cluster_info = nil


-- ================================== Helpers ==================================

local function load_sync_config(config_path)
  local path = vim.fn.expand(config_path or "~/.cluster_sync/config.lua")
  local ok, cfg = pcall(dofile, path)
  if not ok then
    vim.notify("❌ Failed to load sync config at " .. path .. ":\n" .. tostring(cfg), vim.log.levels.ERROR)
    return {}
  end
  return cfg
end

local function notify(msg, level)
  vim.notify("Sync | " .. msg, level or vim.log.levels.INFO, {
    title = "Cluster Sync",
    timeout = 3000,
  })
end

-- Function to construct exclude patterns
local function build_rsync_excludes(proj)
  local opts = {}
  for _, pat in ipairs(vim.split(cfg.PROJECT_EXCLUDE_PATTERNS[proj] or "", " ")) do
    if pat ~= "" then table.insert(opts, "--exclude=" .. pat) end
  end
  for _, pat in ipairs(vim.split(cfg.PROJECT_EXCLUDE_DIRS[proj] or "", " ")) do
    if pat ~= "" then table.insert(opts, "--exclude=" .. pat) end
  end
  return opts
end

-- Function for :w - push a single file to the cluster
local function sync_file_to_cluster(file)
  if not active_cluster_info then
    notify("No cluster set. Use :SyncSet <name>", vim.log.levels.WARN)
    return
  end

  local cluster = active_cluster_info.name
  local user    = active_cluster_info.user
  local host    = active_cluster_info.host
  local dir     = active_cluster_info.dir
  local root    = active_cluster_info.root
  local proj    = active_cluster_info.proj

  local local_proj_root = root .. "/" .. proj
  local subpath = file:sub(#local_proj_root + 2)

  local remote_base = string.format("%s@%s:%s/%s", user, host, dir, proj)
  local remote_path = remote_base .. "/" .. subpath

  local rsync_opts = { "rsync", "-az" }
  vim.list_extend(rsync_opts, build_rsync_excludes(proj))

  table.insert(rsync_opts, file)
  table.insert(rsync_opts, remote_path)

  local result = vim.fn.system(rsync_opts)
  if vim.v.shell_error == 0 then
    local rel = file:sub(#root + 2) -- relative to project root
    local short_path = string.format("%s/%s", user, rel)
    notify("File pushed to '" .. cluster .. "' cluster: " .. short_path)
  else
    notify("❌ Rsync error:\n" .. result, vim.log.levels.ERROR)
  end
end


-- =================================== Setup ===================================

function M.setup(opts)
  opts = opts or {}
  cfg = load_sync_config(opts.config)

  -- Set remote cluster, requires exactly 1 argument
  vim.api.nvim_create_user_command('SyncSet', function(opts)
    local cluster = opts.args
    local user  = cfg.CLUSTERS_USER[cluster]
    local host  = cfg.CLUSTERS_HOST[cluster]
    local dir   = cfg.CLUSTERS_DIR[cluster]
    local roots = cfg.PROJECT_ROOTS

    if not (user and host and dir and roots) then
      notify("❌ Incomplete config for cluster: " .. cluster, vim.log.levels.ERROR)
      return
    end

    -- Get current file path or current working directory
    local file = vim.fn.expand('%:p')
    if file == '' then
      file = vim.fn.getcwd() .. "/"
    end

    -- Normalize to absolute path
    file = vim.fn.fnamemodify(file, ":p")

    -- Find matching root (longest prefix match)
    local root = nil
    for _, r in ipairs(roots) do
      if file:find(r, 1, true) == 1 then
        if not root or #r > #root then
          root = r
        end
      end
    end

    if not root then
      notify("❌ Project root could not be determined from file/cwd: " .. file, vim.log.levels.ERROR)
      return
    end

    local rel = file:sub(#root + 2) -- relative to project root
    local proj = rel:match("([^/]+)")

    vim.g.sync_cluster = cluster
    active_cluster_info = {
      name = cluster,
      user = user,
      host = host,
      dir  = dir,
      root = root,
      proj = proj,
    }

    notify("Set cluster to `" .. cluster .. "`")
  end, { nargs = 1 })

  -- Reset cluster to no remote cluster
  vim.api.nvim_create_user_command('SyncClear', function()
    vim.g.sync_cluster = nil
    active_cluster_info = nil
    notify("Cluster reset (no active cluster)")
  end, {})

  -- Print the current cluster
  vim.api.nvim_create_user_command("SyncStatus", function()
    if not active_cluster_info then
      notify("No cluster set", vim.log.levels.WARN)
      return
    end

    local info_lines = {
      "Current sync cluster:",
      "  name = " .. active_cluster_info.name,
      "  user = " .. active_cluster_info.user,
      "  host = " .. active_cluster_info.host,
      "  dir  = " .. active_cluster_info.dir,
      "  root = " .. active_cluster_info.root,
      "  proj = " .. active_cluster_info.proj,
    }

    notify(table.concat(info_lines, "\n"))
  end, {})

  -- :w every write, triggers a push of the file if a cluster is set
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = vim.api.nvim_create_augroup('SyncAutoPush', { clear = true }),
    pattern = '*',
    callback = function()
      if vim.g.sync_cluster and active_cluster_info then
        local file = vim.fn.expand('%:p')
        sync_file_to_cluster(file)
      end
    end,
  })

  -- Push full project
  vim.api.nvim_create_user_command('SyncPushProject', function()
    if not active_cluster_info then
      notify("No cluster set. Use :SyncSet <name>", vim.log.levels.WARN)
      return
    end

    local user = active_cluster_info.user
    local host = active_cluster_info.host
    local dir  = active_cluster_info.dir
    local root = active_cluster_info.root
    local proj = active_cluster_info.proj

    local remote_project_path = dir .. "/" .. proj

    -- Check if remote path exists
    local check_cmd = {
      "ssh",
      user .. "@" .. host,
      string.format("test -d %s", remote_project_path),
    }

    vim.fn.system(check_cmd)
    if vim.v.shell_error ~= 0 then
      notify("❌ Remote path does not exist: " .. remote_project_path, vim.log.levels.ERROR)
      return
    end

    local cmd = { "rsync", "-az", "--delete" }
    vim.list_extend(cmd, build_rsync_excludes(proj))

    table.insert(cmd, root .. "/" .. proj .. "/")  -- trailing slash is important for rsync dir
    table.insert(cmd, string.format("%s@%s:%s", user, host, remote_project_path))

    local result = vim.fn.system(cmd)
    if vim.v.shell_error == 0 then
      notify("Full project pushed to cluster '" .. active_cluster_info.name .. "'")
    else
      notify("❌ Rsync error:\n" .. result, vim.log.levels.ERROR)
    end
  end, {})

  -- Pull full project
  vim.api.nvim_create_user_command('SyncPullProject', function()
    if not active_cluster_info then
      notify("No cluster set. Use :SyncSet <name>", vim.log.levels.WARN)
      return
    end

    local user = active_cluster_info.user
    local host = active_cluster_info.host
    local dir  = active_cluster_info.dir
    local root = active_cluster_info.root
    local proj = active_cluster_info.proj

    local remote_project_path = dir .. "/" .. proj
    local local_target = root .. "/" .. proj .. "/"

    local cmd = { "rsync", "-az", "--delete" }
    vim.list_extend(cmd, build_rsync_excludes(proj))

    table.insert(cmd, string.format("%s@%s:%s/", user, host, remote_project_path))
    table.insert(cmd, local_target)

    local result = vim.fn.system(cmd)
    if vim.v.shell_error == 0 then
      notify("Project pulled from cluster '" .. active_cluster_info.name .. "'")
    else
      notify("❌ Rsync error:\n" .. result, vim.log.levels.ERROR)
    end
  end, {})

  -- Push single file by name
  vim.api.nvim_create_user_command('SyncPushFile', function(opts)
    if not active_cluster_info then
      notify("No cluster set. Use :SyncSet <name>", vim.log.levels.WARN)
      return
    end

    local root = active_cluster_info.root
    local proj = active_cluster_info.proj
    local rel_path = opts.args
    if rel_path == "" then
      notify("❌ Must provide relative file path", vim.log.levels.ERROR)
      return
    end

    local full_path = root .. "/" .. proj .. "/" .. rel_path
    if vim.fn.filereadable(full_path) == 0 then
      notify("❌ File not found: " .. full_path, vim.log.levels.ERROR)
      return
    end

    sync_file_to_cluster(full_path)
  end, { nargs = 1 })

  -- Pull single file by name
  vim.api.nvim_create_user_command('SyncPullFile', function(opts)
    if not active_cluster_info then
      notify("No cluster set. Use :SyncSet <name>", vim.log.levels.WARN)
      return
    end

    local user = active_cluster_info.user
    local host = active_cluster_info.host
    local dir  = active_cluster_info.dir
    local root = active_cluster_info.root
    local proj = active_cluster_info.proj
    local rel_path = opts.args

    if rel_path == "" then
      notify("❌ Must provide relative file path", vim.log.levels.ERROR)
      return
    end

    local remote_file = string.format("%s@%s:%s/%s/%s", user, host, dir, proj, rel_path)
    local local_file  = root .. "/" .. proj .. "/" .. rel_path

    local cmd = { "rsync", "-az", remote_file, local_file }

    local result = vim.fn.system(cmd)
    if vim.v.shell_error == 0 then
      notify("File pulled: " .. rel_path)
    else
      notify("❌ Rsync error:\n" .. result, vim.log.levels.ERROR)
    end
  end, { nargs = 1 })
end

return M
