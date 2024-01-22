-- Date: Fri Jan 19 12:41:41 2024
-- Mail: lunar_ubuntu@qq.com
-- Author: https://github.com/xiaoqixian

local utils = require("buffer_explorer.utils")
local icons = require("nvim-web-devicons")

local defaults = {
  highlights = {},
  -- set menu number
  menu_buf_options = {},

  modified_symbol = "[+]"
}

local M = {
  config = defaults,

  -- a durable buf table save 
  -- some durable buffer information, 
  -- the table uses the bufnr as its key, 
  -- and another table as the relavent 
  -- information of that buffer.
  durable_buf_table = {}
}

function M:setup() 
  assert(self.ui_mod, "ui module is required for window management")
  self:init()
  self:set_menu_keymaps()
end

function M:init()
  if self.bufnr then
    return
  end

  self.bufnr = self:create_menu_buf()
  if not self.bufnr or not 
    vim.api.nvim_buf_is_valid(self.bufnr) then
    utils.echoerr("create buffer failed")
    return
  end

  self:set_menu_hl()

  self:init_menu_buf(contents)
  self:update()
end

-- create a namespace and set highlight group
-- in this namespace.
function M:set_menu_hl()
  -- create menu highlighting namespace
  self.namespace_id = vim.api.nvim_create_namespace("buffer_explorer_menu")
  vim.api.nvim_set_hl_ns(self.namespace_id)

  for k, v in pairs(self.config.highlights) do
    vim.api.nvim_set_hl(self.namespace_id, k, v)
  end
end

function M:init_menu_buf(contents)
  vim.api.nvim_buf_set_name(self.bufnr, "buffer_explorer_menu")
  vim.api.nvim_buf_set_option(self.bufnr, "filetype", "buffer_explorer")
  vim.api.nvim_buf_set_option(self.bufnr, "buftype", "acwrite")

  for k, v in pairs(self.config.menu_buf_options) do
    vim.api.nvim_set_option_value(k, v, { buf = self.bufnr })
  end

end

function M:close()
  if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.api.nvim_buf_delete(self.bufnr, { force = true })
    self.bufnr = nil
    self.buf_list = nil
  end
end

function M:reload()
  self.close(self)
  self.setup(self)
end

function M:set_menu_keymaps()
  local function map_opts(bufnr, desc) 
    return {
      desc = desc,
      noremap = true,
      silent = true,
      nowait = true,
      buffer = bufnr
    }
  end

  for k, v in pairs(self.config.menu_keymaps) do
    vim.keymap.set("n", k, function()
      v.op(self)
    end, map_opts(self.bufnr, v.desc))
  end
end

-- update buffer list and 
-- menu buffer contents.
function M:update()
  self:update_buf_list()
  local contents = self:get_menu_contents()
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)

  local line_count = vim.api.nvim_buf_line_count(self.bufnr)
  vim.api.nvim_buf_set_lines(self.bufnr, 0, line_count, false, contents)
  vim.api.nvim_buf_set_option(self.bufnr, "modified", false)
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", false)

  self:update_hl()
end

function M:update_hl()
  -- clear namespace 
  vim.api.nvim_buf_clear_namespace(self.bufnr, self.namespace_id, 0, -1)

  for i, buf in pairs(self.buf_list) do
    if vim.bo[buf.bufnr].modified then
      vim.api.nvim_buf_add_highlight(self.bufnr, self.namespace_id, "ModifiedBuffer", i-1, 0, -1)
    end
  end
end

-- core functions end

-- create the menu buffer 
-- not buflisted
-- not scratch buffer
function M:create_menu_buf()
  return vim.api.nvim_create_buf(false, false)
end

function M:get_buf_name(bufnr)
  if self.durable_buf_table[bufnr] then
    return self.durable_buf_table[bufnr].name
  else 
    return vim.api.nvim_buf_get_name(bufnr)
  end
end

-- use short file name by default
function M:format_buf_line(index)
  local bufnr = self.buf_list[index].bufnr
  local buf_name = self:get_buf_name(bufnr)

  local buf_icon = icons.get_icon(buf_name, nil, { default = true })
  if not buf_icon or buf_icon == "" then
    buf_icon = " "
  end

  local tail_symbol = ""
  if vim.bo[bufnr].modified then
    tail_symbol = self.config.modified_symbol
  end

  return string.format("%s %s %s", buf_icon, buf_name, tail_symbol)
end

-- generate a buffer entry with a bufnr,
-- each buf entry represents a buffer on 
-- the menu.
-- the default get_buf_entry generates nothing.
function M:gen_buf_entry(bufnr)
end

-- a buffer filter to decide which 
-- buffers should be in the buf menu.
-- return true if the buffer should be in the menu,
-- otherwise return false
function M:buf_filter(bufnr)
  return vim.bo[bufnr].buflisted
end

function M:update_durable_table(bufnr)
  local function gen_buf_info(bufnr) 
    local buf_name = vim.api.nvim_buf_get_name(bufnr)
    local short_name = utils.normalize_path(buf_name)
    return {
      name = short_name,
      name_toggled = false
    }
  end

  if not self.durable_buf_table[bufnr] then
    self.durable_buf_table[bufnr] = gen_buf_info(bufnr)
  end
end

-- buf_list should be a list
-- instead of a table.
-- The buf list has the same order
-- as the order of buffers on the menu.
function M:update_buf_list()
  local vim_buf_list = vim.api.nvim_list_bufs()
  self.buf_list = {}

  for _, bufnr in ipairs(vim_buf_list) do
    if self:buf_filter(bufnr) then
      local buf_entry = { bufnr = bufnr }
      utils.extend_table(buf_entry, self:gen_buf_entry(bufnr))
      table.insert(self.buf_list, buf_entry)

      self:update_durable_table(bufnr)
    end
  end
end

function M:get_list_bufnr(index)
  local buf_list = self.buf_list
  if index and index <= #buf_list then
    return buf_list[index].bufnr
  end
end

function M:get_cur_bufnr()
  local index = vim.fn.line(".")
  return self:get_list_bufnr(index)
end

function M:get_menu_contents()
  local contents = {}
  for i, buf in pairs(self.buf_list) do
    table.insert(contents, self:format_buf_line(i))
  end
  return contents
end

function M:get_bufnr_index(bufnr)
  for i, buf in pairs(self.buf_list) do
    if buf.bufnr == bufnr then
      return i
    end
  end
  return nil
end

return M
