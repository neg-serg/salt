-- Sort operator: use <leader>s{motion} to sort lines in range
vim.keymap.set('n', '<leader>s', function()
  vim.o.operatorfunc = 'v:lua.___sort_opfunc'
  return 'g@'
end, { expr = true, desc = 'Sort lines (operator)' })

function ___sort_opfunc()
  vim.cmd("'[,']sort")
end
