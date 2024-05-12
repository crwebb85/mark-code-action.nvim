local M = {}

---@type MarkCodeAction.MarkCodeActionConfig
local config = {
    marks = {},
    lsp_timeout_ms = 2000,
}

---Get current configuration
---@return MarkCodeAction.MarkCodeActionConfig
M.get_config = function()
    return config
end

---@param opts MarkCodeAction.MarkCodeActionConfig?
M.set_config = function(opts)
    config = vim.tbl_deep_extend('force', config, opts or {})
end

return M
