local function pick_runtime_frame()
  local files = vim.api.nvim_get_runtime_file("pokemon_frames/*.txt", true)
  if #files == 0 then
    return nil
  end
  math.randomseed(os.time() + vim.loop.hrtime())
  return files[math.random(#files)]
end


-- 分析文件中的颜色并找出非黑色方块最多的颜色
local function get_dominant_color(file_path)
  if not file_path or vim.fn.filereadable(file_path) == 0 then
    return "247,214,55" -- 默认黄色
  end
  
  local content = table.concat(vim.fn.readfile(file_path), "\n")
  local color_counts = {}
  
  -- 匹配 ANSI 转义序列后跟方块字符的模式
  for color_seq, blocks in content:gmatch("%[38;2;([%d;]+)m(██+)") do
    -- 解析RGB值
    local r, g, b = color_seq:match("([%d]+);([%d]+);([%d]+)")
    if r and g and b then
      r, g, b = tonumber(r), tonumber(g), tonumber(b)
      -- 跳过灰色
      if not ((r == g and r == b) or (r < 10 and g < 10 and b < 10)) then
        local color_key = r .. "," .. g .. "," .. b
        local block_count = math.floor(#blocks / 2) -- 每个██算1个方块
        color_counts[color_key] = (color_counts[color_key] or 0) + block_count
      end
    end
  end
  
  -- 找出出现次数最多的颜色
  local max_count = 0
  local dominant_color = "247,214,55" -- 默认黄色
  
  for color, count in pairs(color_counts) do
    if count > max_count then
      max_count = count
      dominant_color = color
    end
  end
  
  return dominant_color
end

local frame_file = pick_runtime_frame()
local dominant_color = "247,214,55" -- 默认颜色

-- 读取文件并计算宽高
local frame_width, frame_height = 48, 24
if frame_file and vim.fn.filereadable(frame_file) == 1 then
  local lines = vim.fn.readfile(frame_file) or {}
  frame_height = math.max(#lines, 1)
  local target_line = lines[2] or lines[1] or ""
  -- 统计 '█' 与 空格 的数量（基于第二行）
  local _, blocks = target_line:gsub("█", "")
  local _, spaces = target_line:gsub(" ", "")
  -- 宽度 = '█' 的数量 + 空格的数量
  frame_width = blocks + spaces
  dominant_color = get_dominant_color(frame_file)
end


local frame_cmd
if frame_file then
  -- PowerShell 输出 UTF-8 的命令
  frame_cmd = string.format([[
powershell -NoLogo -Command "[Console]::OutputEncoding=[Text.Encoding]::UTF8; Get-Content -Raw -Encoding UTF8 '%s'"]]
  , frame_file:gsub("'", "''"))
else
  frame_cmd = [[powershell -NoLogo -Command "Write-Host 'No frames found in runtime path'"]]
end

local frame_filename = frame_file and vim.fn.fnamemodify(frame_file, ":t:r") or "No frame file"
-- 创建自定义高亮组，使用主导颜色
local r, g, b = dominant_color:match("([%d]+),([%d]+),([%d]+)")
if r and g and b then
  vim.api.nvim_set_hl(0, "PokemonName", { 
    fg = string.format("#%02x%02x%02x", tonumber(r), tonumber(g), tonumber(b)),
    bold = true 
  })
end

return {
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    dashboard = {
        preset = {
        -- Defaults to a picker that supports `fzf-lua`, `telescope.nvim` and `mini.pick`
        ---@type fun(cmd:string, opts:table)|nil
        -- pick = nil,
        -- Used by the `header` section
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
        { section = "header" , pane = 1},
        { icon = "󰊓 ", title = frame_filename, gap = 1, padding = 1, hl = "Title"},
        { section = "keys", gap = 1, padding = 1},
        { section = "startup"},
        {
          section = "terminal",
          cmd = frame_cmd,
          pane = 2,
          indent = 10,
          width = frame_width,
          height = frame_height,
        },
      },
    }
  },
  config = function(_, opts)
    local r,g,b = dominant_color:match("(%d+),(%d+),(%d+)")
    if r and g and b then
      local hex = string.format("#%02x%02x%02x", tonumber(r), tonumber(g), tonumber(b))
      local function set_hl()
        vim.api.nvim_set_hl(0, "PokemonName", { fg = hex, bold = true })
      end
      set_hl()
      vim.api.nvim_create_autocmd("ColorScheme", { callback = set_hl })
    end
    require("snacks").setup(opts)
  end
}