local utils = require("buffer_explorer.utils")

local M = {
  ui = require("buffer_explorer.ui"),
  menu = require("buffer_explorer.menu"),
}

function M:setup(user_mod) 
  utils.extend_table(self, user_mod)
  self.ui:setup()
  self.menu.ui_mod = self.ui
  self.menu:setup()
end

function M:toggle()
  if self.ui:hidden() then
    self.menu:update()
    self.ui:open(self.menu.bufnr)
    local prev_bufnr = vim.fn.bufnr("#")
    vim.api.nvim_win_set_cursor(self.ui.winid, { 
      self.menu:get_bufnr_index(prev_bufnr) or 1, 0 })
  else
    self.ui:close()
  end
end

function M:close()
  if not self.ui:hidden() then
    self.ui:close()
  end
end

return M
