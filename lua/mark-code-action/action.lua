local M = {}

local picker_api = require('mark-code-action.pickers')
local ms = vim.lsp.protocol.Methods

---@type {[MarkCodeAction.CodeActionMark]: MarkCodeAction.CodeActionIdentifier}
local code_action_marks = {} -- Stores the code action marks

---Merges the code action marks defined in the configuration to the list of code action marks
---@param opts MarkCodeAction.MarkCodeActionConfig
function M.merge_code_action_marks(opts)
    code_action_marks = vim.tbl_deep_extend('force', code_action_marks, opts.marks or {})
end

---@private
---@param bufnr integer
---@return MarkCodeAction.TextRange {start={row, col}, end={row, col}} using (1, 0) indexing
local function range_from_selection(bufnr)
    local start_pos = vim.api.nvim_buf_get_mark(bufnr, '<')
    local start_row = start_pos[1]
    local start_col = start_pos[2]

    local end_pos = vim.api.nvim_buf_get_mark(bufnr, '>')
    local end_row = end_pos[1]
    local end_col = end_pos[2]

    return {
        ['start'] = { start_row, start_col - 1 },
        ['end'] = { end_row, end_col - 1 },
    }
end

---@param bufnr integer buffer number
---@param is_range boolean true if code action params over a range
---@return lsp.CodeActionParams
local function build_code_action_params(bufnr, is_range)
    local params
    if is_range then
        local range = range_from_selection(bufnr)

        --TODO check for off by one errors
        params = vim.lsp.util.make_given_range_params(range.start, range['end'])
    else
        params = vim.lsp.util.make_range_params()
    end
    params.context = {
        triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked,
        diagnostics = vim.lsp.diagnostic.get_line_diagnostics(bufnr),
    }
    return params
end

--- Prompts the user to select a code action to mark and marks it with the user
--- provided mark name. The mark name must be a single letter within the set
--- {0-9a-zA-Z}. If mark already exists, it will be overridden.
---@param opts MarkCodeAction.MarkSelectionOptions
function M.mark_selection(opts)
    local default_opts = {
        bufnr = vim.api.nvim_get_current_buf(),
        is_range_selection = false,
    }
    opts = vim.tbl_deep_extend('force', default_opts, opts)

    local params = build_code_action_params(opts.bufnr, opts.is_range_selection)
    vim.lsp.buf_request_all(opts.bufnr, ms.textDocument_codeAction, params, function(results)
        ---@type MarkCodeAction.CodeActionIdentifier[]
        local actions = {}

        ---@type string[]
        local action_selection_list = { 'Select a code action to mark:\n' }

        local index = 1
        for client_id, result in pairs(results) do
            local client = vim.lsp.get_client_by_id(client_id)
            if client ~= nil then
                for _, lsp_action in pairs(result.result or {}) do
                    ---@type MarkCodeAction.CodeActionIdentifier
                    local action_identifier = {
                        client_id = client_id,
                        client_name = client.name,
                        kind = lsp_action.kind,
                        title = lsp_action.title,
                        full_action = lsp_action,
                    }
                    table.insert(actions, action_identifier)

                    local action_selection_text = index .. '. ' .. lsp_action.title
                    table.insert(action_selection_list, action_selection_text)

                    index = index + 1
                end
            end
        end

        if #actions == 0 then
            vim.notify('No code actions available.', vim.log.levels.WARN)
            return
        end

        --prompt user to select the code action to mark
        local selection = vim.fn.inputlist(action_selection_list)
        local selection_index = tonumber(selection)
        local selected_action = actions[selection_index]
        if selected_action == nil then
            vim.notify('Not a valid selection.', vim.log.levels.ERROR)
            return
        end

        code_action_marks[opts.mark_name] = selected_action
    end)
end

---Finds the buffer number for the buffer with given buffer name
---@private
---@param name string buffer name
---@return integer bufnr
local find_bufnr_by_name = function(name)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local buf_name = vim.api.nvim_buf_get_name(buf)
        -- checks that the buf_name has name as a suffix
        -- since nvim_buf_get_name will prefix the name with
        -- the project file path
        if buf_name:sub(-#name) == name then
            return buf
        end
    end
    return -1
end

---Opens the code action editor for the given mark name
---@param mark MarkCodeAction.CodeActionMark
function M.open_code_action_editor(mark)
    local buf_name = 'MarkCodeActionEdit: ' .. mark

    local bufnr = find_bufnr_by_name(buf_name)
    if bufnr == -1 then
        bufnr = vim.api.nvim_create_buf(true, true)
        vim.api.nvim_buf_set_name(bufnr, buf_name)
    end

    vim.bo[bufnr].filetype = 'json'
    vim.bo[bufnr].buftype = 'acwrite' --saving uses my custom autocmd

    local mark_info = {}
    mark_info[mark] = M.get_code_action_identifier_by_mark(mark)
    local action_string = vim.json.encode(mark_info)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, vim.split(action_string, '\n'))

    vim.bo[bufnr].modified = false
    vim.api.nvim_set_current_buf(bufnr)

    vim.api.nvim_create_autocmd('BufWriteCmd', {
        group = vim.api.nvim_create_augroup('MarkCodeActionEditWrite', { clear = true }),
        nested = true,
        buffer = bufnr,

        callback = function(params)
            local lines = vim.api.nvim_buf_get_lines(params.buf, 0, -1, false)

            local mark_edits = vim.json.decode(vim.fn.join(lines, '\n'))

            --TODO validate the edited mark

            code_action_marks[mark] = mark_edits[mark]
            vim.bo[params.buf].modified = false
        end,
    })
end

--- based on https://github.com/neovim/neovim/blob/8e5c48b08dad54706500e353c58ffb91f2684dd3/runtime/lua/vim/lsp/buf.lua#L677
---@private
---@param action lsp.Command|lsp.CodeAction
---@param client vim.lsp.Client
---@param ctx lsp.HandlerContext
local function apply_action(action, client, ctx)
    if action.edit then
        vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
    end
    local a_cmd = action.command
    if a_cmd then
        local command = type(a_cmd) == 'table' and a_cmd or action
        ---@diagnostic disable-next-line: param-type-mismatch
        client:_exec_cmd(command, ctx)
    end
end

--- based on https://github.com/neovim/neovim/blob/8e5c48b08dad54706500e353c58ffb91f2684dd3/runtime/lua/vim/lsp/buf.lua#L689
---@private
---@param bufnr integer buffer number
---@param client_id integer lsp client id
---@param params lsp.CodeActionParams code action params
---@param action lsp.Command|lsp.CodeAction
---@param timeout_ms integer the timeout in milliseconds used when making syncronous lsp requests
local function apply_code_action_sync(bufnr, client_id, params, action, timeout_ms)
    local client = vim.lsp.get_client_by_id(client_id)
    if client == nil then
        return
    end

    ---@type lsp.HandlerContext
    local ctx = {
        method = ms.textDocument_codeAction,
        client_id = client_id,
        bufnr = bufnr,
        params = params,
    }
    local reg = client.dynamic_capabilities:get(ms.textDocument_codeAction, { bufnr = bufnr })

    local supports_resolve = vim.tbl_get(reg or {}, 'registerOptions', 'resolveProvider')
        or client.supports_method(ms.codeAction_resolve)
    if not action.edit and client and supports_resolve then
        local response, err = client.request_sync(ms.codeAction_resolve, action, timeout_ms, bufnr)

        if err == 'timeout' then
            error('Request timeout during codeAction/resolve request to LSP server', 1)
        elseif err ~= nil then
            error('Error during codeAction/resolve request to LSP server: ' .. err, 1)
        elseif response == nil then
            error('Did not receive response from LSP server for codeAction/resolve request', 1)
        end

        local lsp_err = response.err
        local resolved_action = response.result
        if lsp_err then
            if action.command then
                apply_action(action, client, ctx)
            else
                vim.notify(lsp_err.code .. ': ' .. lsp_err.message, vim.log.levels.ERROR)
            end
        else
            apply_action(resolved_action, client, ctx)
        end
    else
        apply_action(action, client, ctx)
    end
end

---Run the code action mark
---@param opts MarkCodeAction.RunMarkOptions
function M.run_mark(opts)
    local default_opts = {
        bufnr = vim.api.nvim_get_current_buf(),
        is_range_selection = false,
        lsp_timeout_ms = 2000,
    }

    opts = vim.tbl_deep_extend('force', default_opts, opts)

    local params = build_code_action_params(opts.bufnr, opts.is_range_selection)
    local action_identifier = code_action_marks[opts.mark_name]
    if action_identifier == nil then
        vim.notify('Mark name does not exist.', vim.log.levels.ERROR)
        return
    end

    local clients = vim.lsp.get_clients({
        bufnr = opts.bufnr,
        method = ms.textDocument_codeAction,
    })
    local remaining = #clients
    if remaining == 0 then
        vim.notify('No active LSP clients on buffer.', vim.log.levels.INFO)
        return
    end

    local results, err = vim.lsp.buf_request_sync(opts.bufnr, ms.textDocument_codeAction, params, opts.lsp_timeout_ms)

    if err == 'timeout' then
        error('Request timeout while fetching available code actions from LSP server', 1)
    elseif err ~= nil then
        error('Error while fetching available code actions from LSP server: ' .. err, 1)
    elseif results == nil then
        error('Did not receive response from LSP server when fetching available code actions', 1)
    end

    local code_action_info = picker_api.find_code_action(action_identifier, results)
    if code_action_info ~= nil then
        apply_code_action_sync(
            opts.bufnr,
            code_action_info.client_id,
            params,
            code_action_info.lsp_action,
            opts.lsp_timeout_ms
        )
    end
end

---Get the list of codeaction mark names
---@return string[]
function M.get_code_action_marks()
    local marks = {}
    for mark, _ in pairs(code_action_marks) do
        table.insert(marks, mark)
    end
    return marks
end

---@param mark MarkCodeAction.CodeActionMark
---@return MarkCodeAction.CodeActionIdentifier
function M.get_code_action_identifier_by_mark(mark)
    return code_action_marks[mark]
end

return M
