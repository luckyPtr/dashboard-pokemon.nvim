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
      if not ((r == g and r == b) or (r < 25 and g < 25 and b < 25)) then
        local color_key = r .. "," .. g .. "," .. b
        local block_count = math.floor(#blocks / 2)
        color_counts[color_key] = (color_counts[color_key] or 0) + block_count
      end
    end
  end

  local max_count = 0
  local dominant_color = "247,214,55"
  for color, count in pairs(color_counts) do
    if count > max_count then
      max_count = count
      dominant_color = color
    end
  end

  return dominant_color
end

local function build_dashboard_cfg()
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

  -- 设置高亮（不依赖 snacks）
  local r, g, b = dominant_color:match("([%d]+),([%d]+),([%d]+)")
  if r and g and b then
    local hex = string.format("#%02x%02x%02x", tonumber(r), tonumber(g), tonumber(b))
    local function set_hl()
      vim.api.nvim_set_hl(0, "PokemonName", { fg = hex, bold = true })
    end
    set_hl()
    vim.api.nvim_create_autocmd("ColorScheme", { callback = set_hl })
  end

  local dashboard_cfg = {
    dashboard = {
      preset = {
        header = [[
██████╗  ██████╗ ██╗  ██╗███████╗███╗   ███╗ ██████╗ ███╗   ██╗
██╔══██╗██╔═══██╗██║ ██╔╝██╔════╝████╗ ████║██╔═══██╗████╗  ██║
██████╔╝██║   ██║█████╔╝ █████╗  ██╔████╔██║██║   ██║██╔██╗ ██║
██╔═══╝ ██║   ██║██╔═██╗ ██╔══╝  ██║╚██╔╝██║██║   ██║██║╚██╗██║
██║     ╚██████╔╝██║  ██╗███████╗██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
╚═╝      ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝]],
      },
      formats = {
        header = { "%s", hl = "PokemonName", align = "center" },
      },
      sections = {
        { section = "header", pane = 1 },
        { icon = "󰊓 ", title = frame_filename, gap = 1, padding = 1, hl = "Title" },
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
        {
          section = "terminal",
          cmd = frame_cmd,
          pane = 2,
          indent = 10,
          width = frame_width,
          height = frame_height,
        },
      },
    },
  }

  return dashboard_cfg
end

-- 导出供 lazy.nvim 作为 dependency.opts 使用
function M.get_dashboard_cfg()
  return build_dashboard_cfg()
end

-- 向后兼容：如果有人直接调用 setup，则做受保护调用（避免重复报错）
function M.setup()
  local ok, snacks = pcall(require, "snacks")
  if not ok then
    vim.notify("dashboard-pokemon: 无法加载 snacks.nvim，跳过 setup", vim.log.levels.WARN)
    return
  end
  local cfg = build_dashboard_cfg()
  local ok2, err = pcall(function() snacks.setup(cfg) end)
  if not ok2 then
    -- 忽略已 setup 的错误
    if tostring(err):match("already") then
      vim.notify("dashboard-pokemon: snacks 已经 setup，跳过重复初始化", vim.log.levels.INFO)
    else
      vim.notify("dashboard-pokemon: setup 出错: " .. tostring(err), vim.log.levels.ERROR)
    end
  end
end

return M