-- 自动补全（基于 blink.cmp）
return {
  {
    "saghen/blink.cmp",
    dependencies = { "rafamadriz/friendly-snippets" },
    version = "1.*",
    opts = {
      -- 键位映射
      keymap = {
        preset = "default",
        ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
        ["<CR>"] = { "accept", "fallback" },
        ["<C-j>"] = { "select_next", "fallback" },
        ["<C-k>"] = { "select_prev", "fallback" },
        ["<Down>"] = { "select_next", "fallback" },
        ["<Up>"] = { "select_prev", "fallback" },
        ["<C-n>"] = { "select_next", "fallback_to_mappings" },
        ["<C-p>"] = { "select_prev", "fallback_to_mappings" },
        ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-e>"] = { "hide", "fallback" },
      },
      -- 外观
      appearance = {
        nerd_font_variant = "mono",
      },
      -- 补全行为
      completion = {
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 500,
        },
        ghost_text = { enabled = true }, -- 虚拟文本预览
      },
      -- 补全来源
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        providers = {
          lsp = { fallbacks = { "buffer" } }, -- LSP 无结果时回退到 buffer
        },
      },
      -- 模糊匹配引擎（优先使用 Rust 实现）
      fuzzy = {
        implementation = "prefer_rust_with_warning",
      },
      signature = { enabled = true }, -- 签名帮助
    },
    opts_extend = { "sources.default" },
  },
}
