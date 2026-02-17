-- ┌───────────────────────────────────────────────────────────────────────────────────┐
-- │ █▓▒░ mikavilpas/yazi.nvim                                                         │
-- └───────────────────────────────────────────────────────────────────────────────────┘
return {
  "mikavilpas/yazi.nvim",
  keys = {
    {
      "<leader>-",
      function()
        require("yazi").yazi()
      end,
      desc = "Open yazi at the current file",
    },
    {
      "<leader>cw",
      function()
        require("yazi").yazi(nil, vim.fn.getcwd())
      end,
      desc = "Open yazi in cwd"
    },
  },
  init = function()
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1
    -- Lazy-load yazi when a directory buffer is entered,
    -- so open_for_directories works even before a keymap fires
    vim.api.nvim_create_autocmd("BufEnter", {
      callback = function(args)
        if vim.fn.isdirectory(vim.api.nvim_buf_get_name(args.buf)) == 1 then
          require("lazy").load({ plugins = { "yazi.nvim" } })
          return true -- remove this autocmd after first trigger
        end
      end,
    })
  end,
  opts = {
    open_for_directories = true,
    -- “fullscreen-like” float
    floating_window_scaling_factor = 1.0,
    yazi_floating_window_border = "none",
    keymaps = {
      open_file_in_vertical_split = "<c-v>",
      open_file_in_horizontal_split = "<c-x>",
      open_file_in_tab = "<c-t>",
      grep_in_directory = "<c-f>",
      replace_in_directory = "<c-g>",
      cycle_open_buffers = "<NOP>",
      copy_relative_path_to_selected_files = "<c-y>",
      send_to_quickfix_list = "<c-q>",
      change_working_directory = "<tab>",
    },
  },
}
