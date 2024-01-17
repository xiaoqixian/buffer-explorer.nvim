local Dev = require("buffer_explorer.dev")
local log = Dev.log
local ui = require("buffer_explorer.ui")

local M = {}
local menu_toggled = false

M.config = {
  width = 60,
  height = 60,
  border_chars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }
}

local function get_buf_list()
  local buf_list = vim.api.nvim_list_bufs()
  buf_list.modified_bufs = {} -- list
  buf_list.active_bufs = {} -- list

  local tabs = vim.api.nvim_list_tabpages()
  for _, tabid in ipairs(tabs) do
    local tab_wins = vim.api.nvim_tabpage_list_wins(tabid)
    for _, winid in ipairs(tab_wins) do
      local is_win_valid = vim.api.nvim_win_is_valid(winid)
      local win_bufnr = vim.api.nvim_win_get_buf(winid)
      if is_win_valid then
        table.insert(buf_list.active_bufs, { bufnr = win_bufnr, winid = winid })
      end
    end
  end

  for _, bufnr in ipairs(buf_list) do
    if vim.bo[bufnr].modified then
      table.insert(buf_list.modified_bufs, bufnr)
    end
  end

  return buf_list
end

function M.toggle()
  if menu_toggled then
    ui.close_menu()
    menu_toggled = false
    return
  end

  local buf_list = get_buf_list()
  ui.show_menu(buf_list)
  
  menu_toggled = true
end

function M.setup(config)
  for k, v in pairs(config) do
    M.config[k] = v
  end
end

return M
