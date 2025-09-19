local M = {}

local function pick_runtime_frame()
  local files = vim.api.nvim_get_runtime_file("pokemon_frames/*.txt", true)
  if #files == 0 then
    return nil
  end
  math.randomseed(os.time() + vim.loop.hrtime())
  return files[math.random(#files)]
end

local function get_dominant_color(file_path)
  if not file_path or vim.fn.filereadable(file_path) == 0 then
    return "247,214,55"
  end
  local content = table.concat(vim.fn.readfile(file_path), "\n")
  local color_counts = {}
  for color_seq, blocks in content:gmatch("%[38;2;([%d;]+)m(██+)") do
    local r, g, b = color_seq:match("([%d]+);([%d]+);([%d]+)")
    if r and g and b then
      r, g, b = tonumber(r), tonumber(g), tonumber(b)
      if not (r == g and r == b) then
        local key = r .. "," .. g .. "," .. b
        local count = math.floor(#blocks / 2)
        color_counts[key] = (color_counts[key] or 0) + count
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

  if frame_file and vim.fn.filereadable(frame_file) == 1 then
    local lines = vim.fn.readfile(frame_file) or {}
    frame_height = math.max(#lines, 1)
    local target_line = lines[2] or lines[1] or ""
    local _, blocks = target_line:gsub("█", "")
    local _, spaces = target_line:gsub(" ", "")
    frame_width = blocks + spaces
    dominant_color = get_dominant_color(frame_file)
  end

  local frame_cmd
  if frame_file then
    frame_cmd = string.format([[
powershell -NoLogo -Command "[Console]::OutputEncoding=[Text.Encoding]::UTF8; Get-Content -Raw -Encoding UTF8 '%s'"]]
      , frame_file:gsub("'", "''"))
  else
    frame_cmd = [[powershell -NoLogo -Command "Write-Host 'No frames found in runtime path'"]]
  end

  local frame_filename = frame_file and vim.fn.fnamemodify(frame_file, ":t:r") or "No frame file"

  return {
    cmd = frame_cmd,
    width = frame_width,
    height = frame_height,
    filename = frame_filename,
    color = dominant_color,
  }
end

-- 只改样式与在“已存在 sections 表”时追加 terminal；不创建/覆盖 sections
function M.patch_snacks_opts(opts)
  opts = opts or {}
  opts.dashboard = opts.dashboard or {}

  local ctx = build_frame_ctx()

  -- 高亮（不依赖 snacks）
  do
    local r, g, b = ctx.color:match("([%d]+),([%d]+),([%d]+)")
    if r and g and b then
      local hex = string.format("#%02x%02x%02x", tonumber(r), tonumber(g), tonumber(b))
      local function set_hl()
        vim.api.nvim_set_hl(0, "PokemonName", { fg = hex, bold = true })
      end
      set_hl()
      local grp = vim.api.nvim_create_augroup("DashboardPokemonHL", { clear = true })
      vim.api.nvim_create_autocmd("ColorScheme", { group = grp, callback = set_hl })
    end
  end

  -- 仅设置 header 的格式（颜色/居中），不强行覆盖字符串预设
  opts.dashboard.formats = opts.dashboard.formats or {}
  opts.dashboard.formats.header = { "%s", hl = "PokemonName", align = "center" }

  if type(opts.dashboard.preset) == "table" then
    opts.dashboard.preset.header = [[
██████╗  ██████╗ ██╗  ██╗███████╗███╗   ███╗ ██████╗ ███╗   ██╗
██╔══██╗██╔═══██╗██║ ██╔╝██╔════╝████╗ ████║██╔═══██╗████╗  ██║
██████╔╝██║   ██║█████╔╝ █████╗  ██╔████╔██║██║   ██║██╔██╗ ██║
██╔═══╝ ██║   ██║██╔═██╗ ██╔══╝  ██║╚██╔╝██║██║   ██║██║╚██╗██║
██║     ╚██████╔╝██║  ██╗███████╗██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
╚═╝      ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝]]
  end

  -- sections：已有则只追加 terminal；没有则提供最小默认 + terminal
  local function ensure_terminal(sections)
    local has_terminal = false
    for _, s in ipairs(sections) do
      if s.section == "terminal" then
        has_terminal = true
        break
      end
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
      { section = "keys", gap = 1, padding = 1 },
      { section = "startup" },
    }
    ensure_terminal(opts.dashboard.sections)
  end

  return opts
end

return M