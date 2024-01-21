local utils = require("buffer_explorer.utils")

local defaults = {
  title = "Buffer Explorer",
  title_pos = "center",
  width = 60,
  height = 10,
  border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
  win_options = {
    cursorline = true,
    number = true
  }
}

local M = {
  config = defaults,
  winid = nil
}

function M:update_win_config()
  local win_cols = vim.o.columns
  local win_rows = vim.o.lines
  local width = math.min(self.config.width, win_cols)
  local height = math.min(self.config.height, win_rows)

  local col = math.ceil((win_cols - width)*0.5)
  local row = math.ceil((win_rows - height)*0.5 - 1)

  self.win_config = {
    border = self.config.border,
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    title = self.config.title,
    title_pos = self.config.title_pos
  }
end

-- check if the current winid exists and 
-- is valid
function M:hidden()
  return self.winid == nil or not
    vim.api.nvim_win_is_valid(self.winid)
end

-- this function assumes the bufnr is not nil
-- and is valid.
function M:open(bufnr)
  if self:hidden() then
    --[[ self.winid = create_window(self.config) ]]
    self.winid = vim.api.nvim_open_win(bufnr, true, self.win_config)

    for k, v in pairs(self.config.win_options) do
      vim.api.nvim_set_option_value(k, v, { win = self.winid })
    end
    
  else 
    vim.api.nvim_win_set_buf(self.winid, bufnr)
  end

end

function M:close()
  if not self:hidden() then
    vim.api.nvim_win_close(self.winid, true)
  end
  self.winid = nil
end

function M:toggle(bufnr)
  if self:hidden() then
    self:open(bufnr)
  else 
    vim.api.nvim_win_close(self.winid, true)
    self.winid = nil
  end
end

function M:setup() 
  self:update_win_config()

  vim.api.nvim_create_autocmd({"VimResized", "WinResized"}, {
    callback = function()
      require("buffer_explorer.ui"):update_win_config()
    end
  })
end

return M
