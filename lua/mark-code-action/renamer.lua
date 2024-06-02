local M = {}

---@class MarkCodeAction.rename.Opts
---
---Predicate used to filter clients. Receives a client as argument and
---must return a boolean. Clients matching the predicate are included.
---@field filter? fun(client: vim.lsp.Client): boolean?
---
---Restrict clients used for rename to ones where client.name matches
---this field.
---@field client_name? string
---
---(default: current buffer)
---@field bufnr? integer
---
---(default: current window)
---@field win? integer
---
--- Lsp timeout
---@field timeout_ms? uinteger

---@class lsp.prepareRename.ResultWithPlaceHolder
---@field range lsp.Range
---@field placeholder string

---@class lsp.prepareRename.ResultWithDefaultBehavior
---@field defaultBehavior boolean

---@alias lsp.prepareRename.Result lsp.Range | lsp.prepareRename.ResultWithPlaceHolder | lsp.prepareRename.ResultWithDefaultBehavior | nil

---@class MarkCodeAction.DefaultRenamePrompt
---@field prompt string
---@field client_name? string
---@field client_id? uinteger
---@field prepared? boolean

--- Try to find a client that responds a default prompt and returns the prompt and client id
---@param opts? MarkCodeAction.rename.Opts Additional options:
---@return MarkCodeAction.DefaultRenamePrompt? result
---@return string? error
local function get_default_rename_prompt(opts)
    opts = opts or {}
    local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
    local win = opts.win or vim.api.nvim_get_current_win()

    local clients = vim.lsp.get_clients({
        bufnr = bufnr,
        name = opts.client_name,
        -- Clients must at least support rename, prepareRename is optional
        method = 'textDocument/rename',
    })
    if opts.filter then
        clients = vim.tbl_filter(opts.filter, clients)
    end

    if #clients == 0 then
        return nil, 'No valid lsp client attached'
    end

    local function get_text_at_range(range, offset_encoding)
        return vim.api.nvim_buf_get_text(
            bufnr,
            range.start.line,
            vim.lsp.util._get_line_byte_from_position(bufnr, range.start, offset_encoding),
            range['end'].line,
            vim.lsp.util._get_line_byte_from_position(bufnr, range['end'], offset_encoding),
            {}
        )[1]
    end

    local had_timeouts = false
    local prepared_rename_was_invalid_for_some_clients = false
    local prepared_rename_had_other_errors = false
    local potential_prompt = nil
    for _, client in ipairs(clients) do
        if client.supports_method('textDocument_prepareRename') then
            local params = vim.lsp.util.make_position_params(win, client.offset_encoding)

            ---@type { err: lsp.ResponseError|nil, result: lsp.prepareRename.Result|nil  }|nil, string|nil
            local response, err = client.request_sync('textDocument/prepareRename', params, opts.timeout_ms, bufnr)

            --Not getting a good response from one of the LSP servers is not show stopping
            --since we will just check the next LSP but I think it is a good idea to at least warn the user
            if err == 'timeout' then
                had_timeouts = true
                vim.notify(
                    'Request timeout during textDocument/prepareRename request to LSP server',
                    vim.log.levels.WARN
                )
            elseif err ~= nil then
                prepared_rename_had_other_errors = true
                vim.notify(
                    'Error during textDocument/prepareRename request to LSP server: ' .. err,
                    vim.log.levels.WARN
                )
            elseif response == nil then
                prepared_rename_had_other_errors = true
                vim.notify(
                    'Did not receive response from LSP server for textDocument/prepareRename request',
                    vim.log.levels.WARN
                )
            elseif response.err ~= nil then
                prepared_rename_had_other_errors = true
                vim.notify(
                    'Error during textDocument/prepareRename request to LSP server: ' .. response.err,
                    vim.log.levels.WARN
                )
            elseif response.result == nil then
                prepared_rename_was_invalid_for_some_clients = true
                vim.notify('textDocument/prepareRename request was invalid for lsp client', vim.log.levels.DEBUG)
            elseif response.result.placeholder then
                local prompt = response.result.placeholder
                return { prompt = prompt, client_id = client.id, client_name = client.name }
            elseif response.result.start then
                local prompt = get_text_at_range(response.result, client.offset_encoding)
                return { prompt = prompt, client_id = client.id, client_name = client.name }
            elseif response.result.range then
                local prompt = get_text_at_range(response.result.range, client.offset_encoding)
                return { prompt = prompt, client_id = client.id, client_name = client.name }
            elseif response.result.defaultBehavior == true then
                potential_prompt = {
                    prompt = vim.fn.expand('<cword>'),
                    client_id = client.id,
                    client_name = client.name,
                    prepared = true,
                }
            end
        elseif potential_prompt == nil then
            potential_prompt = { prompt = vim.fn.expand('<cword>'), client_id = client.id, client_name = client.name }
        end
    end

    if potential_prompt ~= nil then
        return potential_prompt
    elseif had_timeouts then
        return nil, 'timeout'
    elseif prepared_rename_was_invalid_for_some_clients then
        return nil, 'Rename request invalid for lsp clients.'
    elseif prepared_rename_had_other_errors then
        return nil, 'Unknown errors preparing rename'
    else
        return nil, 'Invalid state. This should not occur.' --This should not occur
    end
end

--- Try to find a client that responds a default prompt and returns the prompt and client id
---@param opts? MarkCodeAction.rename.Opts Additional options
---@return boolean? success
---@return string? error response
local function apply_rename(name, opts)
    opts = opts or {}
    local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
    local win = opts.win or vim.api.nvim_get_current_win()

    local clients = vim.lsp.get_clients({
        bufnr = bufnr,
        name = opts.client_name,
        -- Clients must at least support rename, prepareRename is optional
        method = 'textDocument/rename',
    })
    if opts.filter then
        clients = vim.tbl_filter(opts.filter, clients)
    end

    if #clients == 0 then
        vim.notify('No valid clients')
        return nil, 'No valid lsp client attached'
    end

    for _, client in ipairs(clients) do
        local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
        params.newName = name
        local response, err = client.request_sync('textDocument/rename', params, opts.timeout_ms, bufnr)
        vim.print(client.name, response, err)
        if err == 'timeout' then
            vim.notify('Request timeout during textDocument/rename request to LSP server', vim.log.levels.WARN)
        elseif err ~= nil then
            vim.notify('Error during textDocument/rename request to LSP server: ' .. err, vim.log.levels.WARN)
        elseif response == nil then
            vim.notify('Did not receive response from LSP server for textDocument/rename request', vim.log.levels.WARN)
        elseif response.err ~= nil then
            vim.notify('Error during textDocument/rename request to LSP server: ' .. response.err, vim.log.levels.WARN)
        elseif response.result == nil then
            vim.notify('Did not receive response from LSP server for textDocument/rename request', vim.log.levels.WARN)
        elseif response.result ~= nil then
            --Not going to create my own version of apply_workspace_edit unless I find out it is doing some problematic async operations
            vim.lsp.util.apply_workspace_edit(response.result, client.offset_encoding)
            return true, nil
        end
    end
    return nil, 'Something went wrong'
end

--- Renames all references to the symbol under the cursor.
---
---@param new_name string|nil If not provided, the user will be prompted for a new
---                name using a prompt buffer.
---@param opts? MarkCodeAction.rename.Opts Additional options
function M.rename(new_name, opts)
    opts = opts or {}
    local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
    local win = vim.api.nvim_get_current_win()

    if new_name then
        apply_rename(new_name, opts)
    end
    local prompt, err = get_default_rename_prompt(opts)

    if err == 'timeout' then
        error('Lsp client timout')
    elseif err ~= nil or prompt == nil then
        error(err)
    end

    local rename_prompt_bufnr = vim.api.nvim_create_buf(true, true)

    vim.bo[rename_prompt_bufnr].filetype = 'MarkCodeActionRenamePrompt'
    vim.bo[rename_prompt_bufnr].buftype = 'prompt'
    vim.fn.prompt_setprompt(rename_prompt_bufnr, '')
    vim.api.nvim_buf_set_lines(rename_prompt_bufnr, 0, -1, true, { prompt.prompt })

    local rename_prompt_win = vim.api.nvim_open_win(rename_prompt_bufnr, true, {
        split = 'below',
        win = win,
        height = 1,
    })
    vim.wo[rename_prompt_win].winfixbuf = true
    vim.fn.prompt_setcallback(rename_prompt_bufnr, function(name)
        name = vim.trim(name)
        if name == '' then
            vim.notify('Rename operation canceled', vim.log.levels.WARN)
        end

        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_set_current_win(win)
            if vim.api.nvim_buf_is_valid(bufnr) then
                vim.api.nvim_set_current_buf(bufnr)
            end
        end
        vim.api.nvim_win_close(rename_prompt_win, true)
        vim.api.nvim_buf_delete(rename_prompt_bufnr, { force = true })

        opts.client_name = prompt.client_name
        apply_rename(name, opts)
    end)

    vim.cmd([[:startinsert]])
    vim.api.nvim_win_set_cursor(rename_prompt_win, { 1, string.len(prompt.prompt) })
end

return M
