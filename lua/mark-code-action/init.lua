local action = require('mark-code-action.action')

---@class MarkCodeAction.CodeActionIdentifier
---@field client_id? number id of the lsp client (at the time of making the mark)
---@field client_name string name of the lsp client
---@field kind string lsp action kind
---@field title string lsp action title
---@field full_action? lsp.Command|lsp.CodeAction of the lsp code action (at the time of making the mark)

---@alias MarkCodeAction.CodeActionMark string

---@alias MarkCodeAction.LinePosition integer[]  in the form {row, col} using (1, 0) indexing

---@class MarkCodeAction.TextRange
---@field start MarkCodeAction.LinePosition
---@field end MarkCodeAction.LinePosition

---@class MarkCodeAction.RunMarkOptions
---@field mark_name string name of mark
---@field bufnr integer? buffer number (default = 0)
---@field is_range_selection boolean? whether to use range params to select code action (default = false)
---@field is_async boolean? whether to run lsp commands asyncronously (default = false)

---@class MarkCodeAction.MarkSelectionOptions
---@field mark_name string name of mark
---@field bufnr integer? buffer number (default=0)
---@field is_range_selection boolean? whether to use range params to select code action (default = false)

---@class MarkCodeAction.MarkCodeActionAPI
local M = {}

---@class MarkCodeAction.MarkCodeActionConfig
---@field marks? {[MarkCodeAction.CodeActionMark]: MarkCodeAction.CodeActionIdentifier}
local config = {
    marks = {},
}

---@param opts MarkCodeAction.MarkCodeActionConfig?
M.setup = function(opts)
    config = vim.tbl_deep_extend('force', config, opts or {})
    action.merge_code_action_marks(config)

    require('mark-code-action.command') -- load commands
end

M.get_code_action_identifier_by_mark = action.get_code_action_identifier_by_mark
M.get_code_action_marks = action.get_code_action_marks

--Get current configuration
M.get_config = function()
    return config
end

return M
