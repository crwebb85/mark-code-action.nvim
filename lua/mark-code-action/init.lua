local action = require('mark-code-action.action')

---@class MarkCodeActionAPI
local M = {}

---@class MarkCodeActionConfig
---@field marks? {[CodeActionMark]: CodeActionIdentifier}
local config = {
    marks = {},
}

---@param opts MarkCodeActionConfig?
M.setup = function(opts)
    config = vim.tbl_deep_extend('force', config, opts or {})
    action.merge_code_action_marks(config)

    vim.api.nvim_create_user_command('MarkCodeActionMark', action.command_mark, {
        desc = 'Marks a Code Action item',
        nargs = 1,
        range = true,
    })

    vim.api.nvim_create_user_command('MarkCodeActionRun', action.command_run_mark, {
        desc = 'Runs a Code Action Mark',
        nargs = 1,
        complete = action.get_code_action_marks,
        range = true,
    })

    vim.api.nvim_create_user_command('MarkCodeActionInspect', function(args)
        local mark = args.args
        vim.print(action.get_code_action_identifier_by_mark(mark))
    end, {
        desc = 'Inspects a Code Action Mark',
        nargs = 1,
        complete = action.get_code_action_marks,
    })

    vim.api.nvim_create_user_command('MarkCodeActionEdit', function(args)
        local mark = args.args
        action.open_code_action_editor(mark)
    end, {
        desc = 'Edits a Code Action Mark',
        nargs = 1,
        complete = action.get_code_action_marks,
    })
end

M.get_code_action_identifier_by_mark = action.get_code_action_identifier_by_mark
M.get_code_action_marks = action.get_code_action_marks

--Get current configuration
M.get_config = function()
    return config
end

return M
