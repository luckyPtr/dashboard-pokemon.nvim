local M = {}

-- 从 runtimepath 查找帧文件；找不到时从插件物理路径兜底查找
local function pick_runtime_frame()
  local files = vim.api.nvim_get_runtime_file("pokemon_frames/*.txt", true)
  if #files == 0 then
    local src = debug.getinfo(1, "S").source
    if type(src) == "string" and src:sub(1, 1) == "@" then
      local this = src:sub(2)
      local dir = vim.fs.dirname(this)
      local i = dir and dir:find("[/\\]lua[/\\]")
      local root = i and dir:sub(1, i - 1) or vim.fs.dirname(dir or "")
      local sep = package.config:sub(1, 1)
      local pattern = root .. sep .. "pokemon_frames" .. sep .. "*.txt"
      local globs = vim.fn.glob(pattern, true, true)
      if type(globs) == "table" and #globs > 0 then
        files = globs
      end
    end
  end
  if #files == 0 then
    return nil
  end
  math.randomseed(os.time() + (vim.loop and vim.loop.hrtime() or 0))
  return files[math.random(#files)]
end

-- 简单统计 ANSI 彩色块的主色（忽略灰度）
local function get_dominant_color(file_path)
  if not file_path or vim.fn.filereadable(file_path) == 0 then
    return "247,214,55"
  end
  local content = table.concat(vim.fn.readfile(file_path), "\n")
  local color_counts = {}
  for color_seq, blocks in content:gmatch("%[38;2;([%d;]+)m(█+)") do
    local r, g, b = color_seq:match("([%d]+);([%d]+);([%d]+)")
    if r and g and b then
      r, g, b = tonumber(r), tonumber(g), tonumber(b)
      if not ((r == g and r == b) or (r < 20 and g < 20 and b < 20)) then
        local key = r .. "," .. g .. "," .. b
        color_counts[key] = (color_counts[key] or 0) + #blocks
      end
    end
  end
  local maxc, dom = 0, "247,214,55"
  for color, cnt in pairs(color_counts) do
    if cnt > maxc then
      maxc, dom = cnt, color
    end
  end
  return dom
end

local function build_frame_ctx()
  local frame_file = pick_runtime_frame()
  local dominant_color = "247,214,55"
  local frame_width, frame_height = 48, 24
  local frame_filename = "No frame file"

  if frame_file and vim.fn.filereadable(frame_file) == 1 then
    frame_filename = vim.fn.fnamemodify(frame_file, ":t:r")
    local lines = vim.fn.readfile(frame_file) or {}
    frame_height = math.max(#lines, 1)
    local target_line = lines[2] or lines[1] or ""
    local _, blocks = target_line:gsub("█", "")
    local _, spaces = target_line:gsub(" ", "")
    frame_width = math.max(blocks + spaces, 32)
    dominant_color = get_dominant_color(frame_file)
  end

  local frame_cmd
  if frame_file then
    frame_cmd = string.format(
      [[powershell -NoLogo -Command "[Console]::OutputEncoding=[Text.Encoding]::UTF8; Get-Content -Raw -Encoding UTF8 '%s'"]],
      frame_file:gsub("'", "''")
    )
  else
    frame_cmd = [[powershell -NoLogo -Command "Write-Host 'No frames found in runtime path'"]]
  end

  return {
    cmd = frame_cmd,
    width = frame_width,
    height = frame_height,
    filename = frame_filename,
    color = dominant_color,
  }
end

-- 补丁 snacks.opts：保留默认 sections，只设置 header 样式，并确保 terminal 存在
function M.patch_snacks_opts(opts)
  opts = opts or {}
  opts.dashboard = opts.dashboard or {}

  local ctx = build_frame_ctx()

  -- 高亮
  do
    local r, g, b = ctx.color:match("([%d]+),([%d]+),([%d]+)")
    if r and g and b then
      local hex = string.format("#%02x%02x%02x", tonumber(r), tonumber(g), tonumber(b))
      local function set_hl() vim.api.nvim_set_hl(0, "PokemonName", { fg = hex, bold = true }) end
      set_hl()
      local grp = vim.api.nvim_create_augroup("DashboardPokemonHL", { clear = true })
      vim.api.nvim_create_autocmd("ColorScheme", { group = grp, callback = set_hl })
    end
  end

  -- 仅设置 header 的格式（颜色/居中）
  opts.dashboard.formats = opts.dashboard.formats or {}
  opts.dashboard.formats.header = { "%s", hl = "PokemonName", align = "center" }

  -- 如果 preset 是表，才覆盖 header 文本；字符串预设不动，避免打断 LazyVim 默认
  if type(opts.dashboard.preset) == "table" then
    opts.dashboard.preset.header = [[
██████╗  ██████╗ ██╗  ██╗███████╗███╗   ███╗ ██████╗ ███╗   ██╗
██╔══██╗██╔═══██╗██║ ██╔╝██╔════╝████╗ ████║██╔═══██╗████╗  ██║
██████╔╝██║   ██║█████╔╝ █████╗  ██╔████╔██║██║   ██║██╔██╗ ██║
██╔═══╝ ██║   ██║██╔═██╗ ██╔══╝  ██║╚██╔╝██║██║   ██║██║╚██╗██║
██║     ╚██████╔╝██║  ██╗███████╗██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
╚═╝      ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝]]
  end

  -- sections：已有则只追加 terminal；没有则给出最小默认 + terminal（保留 keys）
  local function ensure_terminal(sections)
    local has_terminal = false
    for _, s in ipairs(sections) do
      if s.section == "terminal" then has_terminal = true; break end
    end
    if not has_terminal then
      table.insert(sections, {
        section = "terminal",
        cmd = ctx.cmd,
        pane = 2,
        indent = 10,
        width = ctx.width,
        height = ctx.height,
      })
    end
  end

  if type(opts.dashboard.sections) == "table" then
    ensure_terminal(opts.dashboard.sections)
  else
    opts.dashboard.sections = {
      { section = "header", pane = 1 },
      { icon = "󰊓 ", title = ctx.filename, gap = 1, padding = 1, hl = "Title" },
      { section = "keys", gap = 1, padding = 1 },
      { section = "startup" },
    }
    ensure_terminal(opts.dashboard.sections)
  end

  return opts
end

return M