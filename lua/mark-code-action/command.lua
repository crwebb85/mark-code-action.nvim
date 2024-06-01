local action = require('mark-code-action.action')
local renamer = require('mark-code-action.renamer')
local config = require('mark-code-action.config')
---Type definitions for the params that neovim passes to a user commands callback
---@class MarkCodeAction.UserCommandOptions
---@field name string
---@field args string
---@field fargs string[]
---@field bang boolean
---@field line1 number
---@field line2 number
---@field range number
---@field count number
---@field reg string
---@field mods string
---@field smods string[]

--- Prompts the user to select a code action to mark and marks it with the user
--- provided mark name. The mark name must be a single letter within the set
--- {0-9a-zA-Z}. If mark already exists, it will be overridden.
vim.api.nvim_create_user_command(
    'MarkCodeActionMark',

    --- @param opts MarkCodeAction.UserCommandOptions
    function(opts)
        local mark_name = opts.fargs[1]
        mark_name = mark_name:gsub('%s+', '') -- strip whitespace

        if string.match(mark_name, '%w') == nil or string.len(mark_name) ~= 1 then
            vim.notify('Mark name must be a single character within the set {0-9a-zA-Z}.', vim.log.levels.ERROR)
            return
        end

        action.mark_selection({
            mark_name = mark_name,
            bufnr = vim.api.nvim_get_current_buf(),
            is_range_selection = (opts.range == 2),
        })
    end,
    {
        desc = 'Marks a Code Action item',
        nargs = 1,
        range = true,
    }
)

vim.api.nvim_create_user_command(
    'MarkCodeActionRun',
    ---@param opts MarkCodeAction.UserCommandOptions
    function(opts)
        local mark_name = opts.args
        action.run_mark({
            mark_name = mark_name,
            bufnr = vim.api.nvim_get_current_buf(),
            is_range_selection = (opts.range == 2),
            is_async = opts.bang,
            lsp_timeout_ms = config.get_config().lsp_timeout_ms,
        })
    end,
    {
        desc = 'Runs a Code Action Mark',
        nargs = 1,
        complete = action.get_code_action_marks,
        range = true,
        bang = true,
    }
)

vim.api.nvim_create_user_command('MarkCodeActionInspect', function(opts)
    local mark = opts.args
    vim.print(action.get_code_action_identifier_by_mark(mark))
end, {
    desc = 'Inspects a Code Action Mark',
    nargs = 1,
    complete = action.get_code_action_marks,
})

vim.api.nvim_create_user_command('MarkCodeActionEdit', function(opts)
    local mark = opts.args
    action.open_code_action_editor(mark)
end, {
    desc = 'Edits a Code Action Mark',
    nargs = 1,
    complete = action.get_code_action_marks,
})

vim.api.nvim_create_user_command('MarkCodeActionRename', function(opts)
    local name = opts.args

    renamer.rename(nil, {
        name = nil,
        bufnr = nil,
        filter = nil,
        timeout_ms = 2000,
    })
end, {
    desc = 'Renames',
    nargs = '?',
    complete = function() end,
})
