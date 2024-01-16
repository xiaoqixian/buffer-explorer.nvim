local Path = require("plenary.path")
local buffer_manager = require("buffer_manager")
local popup = require("plenary.popup")
local utils = require("buffer_manager.utils")
local log = require("buffer_manager.dev").log
local marks = require("buffer_manager").marks


local M = {}

local function create_window()
  log.trace("create_window()")

  local width = 60
  local height = 60

  if config then
    -- config supports absolute width and relative width
    if config.width then
      if config.width <= 1 then
        local gwidth = vim.api.nvim_list_uis()[1].width
        width = math.floor(gwidth * config.width)
      else 
        width = config.width
      end
    end

    if config.height then
      if config.height <= 1 then
        local gheight = vim.api.nvim_list_uis()[1].height
        height = math.floor(gheight * config.height)
      else 
        height = config.height
      end
    end

    local borderchars = config.borderchars
    -- this buf is not buflisted and not scratch buffer
    local bufnr = vim.api.nvim_create_buf(false, false)

    local win_config = {
      title = "Buffers",
      line = math.floor(((vim.o.lines - height) / 2) - 1),
      col = math.floor((vim.o.columns - width) / 2),
      minwidth = width,
      minheight = height,
      borderchars = borderchars
    }

    local win_id, win = popup.create(bufnr, win_config)

    if config.highlight ~= "" then
      vim.api.nvim_set_option_value(
        "winhighlight",
        config.highlight,
        { win = win.border.win_id }
      )
    end

    return {
      bufnr = bufnr,
      win_id = win_id
    }
end

return M
