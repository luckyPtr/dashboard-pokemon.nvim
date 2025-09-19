# dashboard-pokemon.nvim

在 snacks.nvim 的 Dashboard 上显示一只随机宝可梦，仿照snacks.nvim的 [dashboard.md](https://github.com/folke/snacks.nvim/blob/main/docs/dashboard.md) 的pokemon示例的Windows实现，使用 Powshell 直接输出，无效额外配置

ANSI彩色ASCII素材来自 [pokemon-colorscripts](https://github.com/Findarato/pokemon-colorscripts)

## 依赖
- Neovim 0.9+
- folke/snacks.nvim
- 仅适用于Windows

## 安装

使用lazy.nvim
```lua
return {
  {
    "luckyPtr/dashboard-pokemon.nvim",
    module = "dashboard-pokemon",
    dependencies = {
      {
        "folke/snacks.nvim",
        opts = function(_, opts)
          local ok, mod = pcall(require, "dashboard-pokemon")
          if ok and mod.patch_snacks_opts then
            return mod.patch_snacks_opts(opts)
          end
          return opts or {}
        end,
      },
    },
  },
}
```

