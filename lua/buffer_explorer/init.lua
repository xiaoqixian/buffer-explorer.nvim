local Dev = require("buffer_explorer.dev")
local log = Dev.log
local ui = require("buffer_explorer.ui")
local utils = require("buffer_explorer.utils")

local M = {}
local menu_toggled = false

config = {}

buf_list = nil

local function get_buf_list()
  local buf_list = {}
  buf_list.modified_bufs = {} -- list
  buf_list.active_bufs = {} -- list

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local buf_name = vim.api.nvim_buf_get_name(bufnr)
    -- only collect listed buffers
    if vim.fn.buflisted(bufnr) == 1 and buf_name ~= "" then
      table.insert(buf_list, bufnr)
    end
  end

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

-- this function assumes the menu buffer is 
-- never modified by the user, as it is supposed to be.
-- and the command is not nil.
local function select_item(index, command)
  if not buf_list then
    return
  end
  local bufnr = buf_list[index]
  
  if not vim.api.nvim_buf_is_valid(bufnr) then
    utils.echoerr(string.format("Buffer %d is invalid", bufnr))
    return
  end

  --[[ utils.echoerr(string.format("select %d %s", index, vim.api.nvim_buf_get_name(bufnr))) ]]
  
  if bufnr and bufnr ~= -1 then
    if type(command) == "string" then
      vim.cmd(string.format("%s %s", command, vim.api.nvim_buf_get_name(bufnr)))

    elseif type(command) == "function" then
      command(bufnr, index)
    else 
      utils.echoerr(string.format("Unknown command type %s", type(command)))
    end
  end
end

function M._get_list_bufnr(index)
  local bufnr = buf_list[index]
  return string.format("%d %s", bufnr, vim.api.nvim_buf_get_name(bufnr))
end

local function setup_menu_keymaps(menu_keymaps)
  if not menu_keymaps or type(menu_keymaps) ~= "table" then
    return
  end
  local map = vim.keymap.set
  for k, v in pairs(menu_keymaps) do
    if v.command then
      map("n", k, function()
        -- the index must be saved in advance
        local index = vim.fn.line(".")
        if v.close then M.hide() end
        select_item(index, v.command)
      end, { buffer = ui.menu_bufnr, desc = v.desc, nowait = true, noremap = true })
    else 
      utils.echoerr(string.format("key %s has no command", k))
    end
  end
end

-- Comparing to "buffer" command, this function 
-- will avoid to enter already active buffer
function M.enter_buffer(bufnr, _) 
  local function buffer_is_active(target_bufnr)
    local tabs = vim.api.nvim_list_tabpages()
    for _, tabid in ipairs(tabs) do
      local tab_wins = vim.api.nvim_tabpage_list_wins(tabid)
      for _, winid in ipairs(tab_wins) do
        if target_bufnr == vim.api.nvim_win_get_buf(winid) then
          return true
        end
      end
    end
    return false
  end

  if not buffer_is_active(bufnr) then
    vim.cmd(string.format("buffer %s", vim.api.nvim_buf_get_name(bufnr)))
  end
end

function M.hide()
  ui.close_menu()
  menu_toggled = false
  --[[ buf_list = nil ]]
end

function M.toggle()
  if menu_toggled then
    M.hide()
    return
  end

  buf_list = get_buf_list()
  ui.show_menu(buf_list)
  
  menu_toggled = true

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(ui.menu_winid),
    callback = M.hide
  })
  setup_menu_keymaps(config.menu_keymaps)

end

function M.delete_buffer(bufnr, index)
  assert(buf_list, "Buf_list should not be nil")
  assert(vim.api.nvim_buf_is_valid(bufnr), string.format("bufnr %d is invalid", bufnr))

  if vim.bo[bufnr].modified then
    utils.echoerr(string.format("buffer %s is modified", vim.api.nvim_buf_get_name(bufnr)))
    return
  end

  vim.api.nvim_buf_delete(bufnr, { force = false })
  if not vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_set_option(ui.menu_bufnr, "modifiable", true)
    vim.cmd(string.format("%dd", index))
    vim.api.nvim_buf_set_option(ui.menu_bufnr, "modifiable", false)
    vim.api.nvim_buf_set_option(ui.menu_bufnr, "modified", false)
  end
end

function M.setup(user_config)
  config = {
    -- menu buffer local keymaps
    -- only normal mode menu_keymaps is supported
    menu_keymaps = {
      ["<CR>"] = {
        -- if command is a string, 
        -- the corresponding vim cmd will be ':<command> bufnr'
        -- where bufnr belongs to the buffer on the cursorline.
        command = M.enter_buffer,
        -- should close the window after the command is executed
        -- default by false
        close = true,
        desc = "enter this buffer"
      },
      ["t"] = {
        command = "tabnew",
        close = true,
        desc = "open buffer in new tab"
      },
      ["d"] = {
        -- if command is a function, 
        -- then this function will receive a bufnr
        -- as the first argument.
        -- where bufnr belongs to the buffer on the cursorline.
        command = M.delete_buffer,
        desc = "delete this buffer"
      }
    }
  }

  for k, v in pairs(user_config) do
    config[k] = v
  end

  ui.setup(config.ui)
end

M.setup({})

return M
