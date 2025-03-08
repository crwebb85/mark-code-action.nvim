local config = require('mark-code-action.config')

local M = {}
local ms = vim.lsp.protocol.Methods

---@class MarkCodeAction.lsp.LocationOpts
---Lsp request timeout (overrides default in config)
---@field lsp_timeout_ms? uinteger
---Predicate used to filter clients. Receives a client as argument and
---must return a boolean. Clients matching the predicate are included.
---@field filter? fun(client: vim.lsp.Client): boolean?
---A callback to map the LSP result to a list of quickfix entries
---TODO figure out a better way to abstract this so that map_result is not public
---@field map_result? fun(result: any, ctx: MarkCodeAction.lsp.MakeParametersContext): vim.quickfix.entry[]

---@class MarkCodeAction.lsp.LocationGotoOpts: MarkCodeAction.lsp.LocationOpts
---Jump to existing window if buffer is already open in a window (default: false)
---(see also reuse_win field in vim.lsp.LocationOpts)
---@field reuse_win? boolean

--- Same fields as vim.lsp.LocationOpts.OnList just repeated here to
--- decouple it from the neovim API
--- @class MarkCodeAction.lsp.LocationOpts.OnList
--- @field items table[] Structured like setqflist-what
--- @field title? string Title for the list.
--- @field context? { bufnr: integer, method: string }

---@class MarkCodeAction.lsp.LocationListOpts: MarkCodeAction.lsp.LocationOpts
---list-handler replacing the default handler.
---This table can be used with setqflist() or setloclist().
---(see also on_list field in vim.lsp.ListOpts)
---@field on_list? fun(t: MarkCodeAction.lsp.LocationOpts.OnList)
---Whether to use the location-list or the quickfix list when using the default handler.
---(see also loclist field in vim.lsp.ListOpts)
---@field loclist? boolean
---The title to use for the list (default: 'LSP locations')
---@field title? string

---The context about the LSP client and cursor information needed to build
---the request parameters for a request to that LSP client.
---@class MarkCodeAction.lsp.MakeParametersContext
---The client for which request parameters will be built
---@field client vim.lsp.Client
---The information about the current cursor
---@field cursor_info MarkCodeAction.lsp.CursorInfo

---@class MarkCodeAction.lsp.CursorInfo
---@field win integer window-ID
---@field bufnr integer buffer number
---@field cursor_pos integer[] contains four numbers [bufnum, lnum, col, off] (see also `:h getpos`)
---@field cword string the word under the cursor

---Makes the positional parameters for the clients offset_encoding.
---Has a callback that allows modifying the params for the specific LSP client.
---@param ctx MarkCodeAction.lsp.MakeParametersContext
---@return lsp.TextDocumentPositionParams positional_params
local function make_position_parameters(ctx)
    local params = vim.lsp.util.make_position_params(ctx.cursor_info.win, ctx.client.offset_encoding)
    return params
end

---Makes the positional parameters for the clients offset_encoding.
---Has a callback that allows modifying the params for the specific LSP client.
---@param ctx MarkCodeAction.lsp.MakeParametersContext
---@return lsp.TextDocumentPositionParams positional_params
---@diagnostic disable-next-line: unused-local
local function make_text_document_params(ctx)
    local params = { textDocument = vim.lsp.util.make_text_document_params() }
    return params
end

---Maps a single LSP location or multiple LSP locations to quickfix entries
---@param result lsp.Location | lsp.Location[]
---@param ctx MarkCodeAction.lsp.MakeParametersContext
---@return vim.quickfix.entry[]
local function locations_to_items(result, ctx)
    local locations = vim.islist(result) and result or { result }
    local items = vim.lsp.util.locations_to_items(locations, ctx.client.offset_encoding)
    return items
end

---Maps document symbols to quickfix entries
---@param result lsp.DocumentSymbol[]|lsp.SymbolInformation[]
---@param ctx MarkCodeAction.lsp.MakeParametersContext
---@return vim.quickfix.entry[]
local function symbols_to_items(result, ctx)
    local locations = vim.islist(result) and result or { result }
    local items = vim.lsp.util.symbols_to_items(locations, ctx.cursor_info.bufnr, ctx.client.offset_encoding)
    return items
end

---Gets the location items from the lsp for the given method
---@param method string
---@param cursor_info MarkCodeAction.lsp.CursorInfo
---@param make_params_callback fun(ctx: MarkCodeAction.lsp.MakeParametersContext)
---@param opts? MarkCodeAction.lsp.LocationOpts
---@return vim.quickfix.entry[]
---@return string|nil
local function get_locations(method, cursor_info, make_params_callback, opts)
    ---@type vim.quickfix.entry[]
    local all_entries = {}
    ---@type string[]
    local error_messages = {}

    opts = opts or {}

    local lsp_timeout_ms = opts.lsp_timeout_ms or config.get_config().lsp_timeout_ms

    local clients = vim.lsp.get_clients({ method = method, bufnr = cursor_info.bufnr })

    if opts.filter then
        clients = vim.tbl_filter(opts.filter, clients)
    end

    if not next(clients) then
        local error_message = 'Error: no client for buffer support ' .. method
        return all_entries, error_message
    end

    for _, client in ipairs(clients) do
        ---@type MarkCodeAction.lsp.MakeParametersContext
        local ctx = {
            cursor_info = cursor_info,
            client = client,
        }
        local params = make_params_callback(ctx)
        local response, err = client:request_sync(method, params, lsp_timeout_ms, cursor_info.bufnr)

        if err == 'timeout' then
            local error_message = 'During ' .. method .. ' request:\n' .. client.name .. ' timed out\n'
            table.insert(error_messages, error_message)
        elseif err ~= nil then
            local error_message = 'During '
                .. method
                .. ' request:\n'
                .. client.name
                .. ' had client err '
                .. err
                .. '\n'
            table.insert(error_messages, error_message)
        elseif response == nil then
            local error_message = 'During '
                .. method
                .. ' request:\n'
                .. client.name
                .. ' client returned an empty response\n'
            table.insert(error_messages, error_message)
        elseif response.err ~= nil then
            local error_message = 'During '
                .. method
                .. ' request:\n'
                .. client.name
                .. ' server sent an the error '
                .. response.err.code
                .. ':'
                .. response.err.message
                .. '\n'
            table.insert(error_messages, error_message)
        elseif response.result == nil then
            local error_message = 'During '
                .. method
                .. ' request:\n'
                .. client.name
                .. ' did not return back a result which per the LSP spec means there was an error.\n'
                .. ' However it did not specify what that error was.\n'
            table.insert(error_messages, error_message)
        elseif response.result ~= nil then
            local entries = opts.map_result(response.result, ctx)
            vim.list_extend(all_entries, entries)
        end
    end

    local full_error_message = nil
    if #error_messages > 0 then
        full_error_message = ''
        for _, error_message in ipairs(error_messages) do
            full_error_message = full_error_message .. error_message
        end
    end

    return all_entries, full_error_message
end

---Get the information about the cursor
---@return MarkCodeAction.lsp.CursorInfo
local function get_cursor_info()
    local cursor_pos = vim.fn.getpos('.')
    cursor_pos[1] = vim.api.nvim_get_current_buf()

    ---@type MarkCodeAction.lsp.CursorInfo
    local cursor_info = {
        win = vim.api.nvim_get_current_win(),
        bufnr = vim.api.nvim_get_current_buf(),
        cursor_pos = cursor_pos,
        cword = vim.fn.expand('<cword>'),
    }
    return cursor_info
end

---@param method string
---@param make_params_callback fun(client:vim.lsp.Client)
---@param opts? MarkCodeAction.lsp.LocationGotoOpts
local function goto_location(method, make_params_callback, opts)
    opts = opts or {}
    if opts.reuse_win == nil then
        opts.reuse_win = false
    end

    local cursor_info = get_cursor_info()
    local location_items, err = get_locations(method, cursor_info, make_params_callback, opts)

    if #location_items <= 0 and err ~= nil then
        -- If there are no locations but we did have errors
        -- then we will throw an error to break any running vim macros
        -- and also tell the user why there wasn't any items
        error(err, vim.log.levels.ERROR)
    elseif #location_items <= 0 then
        -- If there are no location items then we will throw an error to
        -- break any running vim macros
        error('Location not found for ' .. method, vim.log.levels.ERROR)
    elseif #location_items > 1 then
        --TODO if using multiple lsp's then repeats may be found so I might want to filter
        --the locations for overlapping locations
        error('More than one location found for ' .. method, vim.log.levels.ERROR)
    elseif err ~= nil then
        vim.notify(err, vim.log.levels.WARN)
    end

    local item = location_items[1]
    local next_bufnr = item.bufnr or vim.fn.bufadd(item.filename)
    local next_win = opts.reuse_win and vim.fn.win_findbuf(next_bufnr)[1] or cursor_info.win

    -- Save the current position in jumplist
    vim.cmd("normal! m'")

    -- Push a new item into tagstack for the word under the cursor
    local tagstack = { { tagname = cursor_info.cword, from = cursor_info.cursor_pos } }
    vim.fn.settagstack(vim.fn.win_getid(cursor_info.win), { items = tagstack }, 't')

    -- Make sure the buffer of the next cursor position shows up in the buffer list
    vim.bo[next_bufnr].buflisted = true

    -- Display the buffer in the window
    vim.api.nvim_win_set_buf(next_win, next_bufnr)

    -- Move the cursor to the window
    vim.api.nvim_win_set_cursor(next_win, { item.lnum, item.col - 1 })

    -- Open any folds on the cursor line so that the cursor is visible
    if vim.wo[next_win].foldenable and vim.fn.foldclosed(item.lnum) >= 0 then
        vim.cmd('normal! zv')
    end
end

---@param method string
---@param make_params_callback fun(client:vim.lsp.Client)
---@param opts? MarkCodeAction.lsp.LocationListOpts
local function list_locations(method, make_params_callback, opts)
    opts = opts or {}
    if opts.title == nil then
        opts.title = 'LSP locations'
    end

    local cursor_info = get_cursor_info()
    local location_items, err = get_locations(method, cursor_info, make_params_callback, opts)

    if #location_items <= 0 and err ~= nil then
        -- Throw an error to break any running vim macros
        -- and also tell the user why there wasn't any items
        error(error, vim.log.levels.ERROR)
    elseif #location_items <= 0 then
        -- Throw an error to break any running vim macros
        error('Locations not found for ' .. method, vim.log.levels.ERROR)
    elseif err ~= nil then
        -- Notify the user that errors were occured but at least one LSP client
        -- returned valid results
        vim.notify(err, vim.log.levels.WARN)
    end

    if opts.on_list then
        assert(vim.is_callable(opts.on_list), 'on_list is not a function')
        opts.on_list({
            title = opts.title,
            items = location_items,
            context = { bufnr = cursor_info.bufnr, method = method },
        })
    elseif opts.loclist then
        vim.fn.setloclist(0, {}, ' ', { title = opts.title, items = location_items })

        --we won't automatically open the location list since that will move the cursor to it
        --instead we will notify the user that items were found. We won't notify the user
        --while running a macro since we don't want to spam the user with messages
        if vim.fn.reg_executing() == '' then
            vim.notify('Added ' .. #location_items .. ' items to the location list', vim.log.levels.INFO)
        end
    else
        vim.fn.setqflist({}, ' ', { title = opts.title, items = location_items })

        --we won't automatically open the quickfix list since that will move the cursor to it
        --instead we will notify the user that items were found. We won't notify the user
        --while running a macro since we don't want to spam the user with messages
        if vim.fn.reg_executing() == '' then
            vim.notify('Added ' .. #location_items .. ' items to the quickfix list', vim.log.levels.INFO)
        end
    end
end

--- Jumps to the declaration of the symbol under the cursor.
--- This is a synchronous replacement for vim.lsp.buf.declaration().
--- Will error if LSPs don't return exactly one declaration.
--- Use list_declarations(opts) if you want a list instead.
--- @param opts? MarkCodeAction.lsp.LocationGotoOpts
function M.goto_declaration(opts)
    opts = opts or {}
    opts.map_result = locations_to_items
    goto_location(ms.textDocument_declaration, make_position_parameters, opts)
end

--- Jumps to the definition of the symbol under the cursor.
--- This is a synchronous replacement for vim.lsp.buf.definition()
--- Will error if LSPs don't return exactly one definition.
--- Use list_definitions(opts) if you want a list instead.
--- @param opts? MarkCodeAction.lsp.LocationGotoOpts
function M.goto_definition(opts)
    opts = opts or {}
    opts.map_result = locations_to_items
    goto_location(ms.textDocument_definition, make_position_parameters, opts)
end

--- Jumps to the definition of the type of the symbol under the cursor.
--- This is a synchronous replacement for vim.lsp.buf.type_definition().
--- Will error if LSPs don't return exactly one type_definition.
--- Use list_type_definitions(opts) if you want a list instead.
--- @param opts? MarkCodeAction.lsp.LocationGotoOpts
function M.goto_type_definition(opts)
    opts = opts or {}
    opts.map_result = locations_to_items
    goto_location(ms.textDocument_typeDefinition, make_position_parameters, opts)
end

--- Jump to the implementations for the symbol under the cursor
--- This is a synchronous replacement for vim.lsp.buf.implementation().
--- Will error if LSPs don't return exactly one implementation.
--- Use list_implementations(opts) if you want a list instead.
--- @param opts? MarkCodeAction.lsp.LocationGotoOpts
function M.goto_implementation(opts)
    opts = opts or {}
    opts.map_result = locations_to_items
    goto_location(ms.textDocument_implementation, make_position_parameters, opts)
end

--- List the declaration of the symbol under the cursor.
--- This is a synchronous replacement for vim.lsp.buf.declaration().
--- Will error if LSPs don't return at least one declaration.
--- Use goto_declaration(opts) if you want a list instead.
--- @param opts? MarkCodeAction.lsp.LocationListOpts
function M.list_declarations(opts)
    opts = opts or {}
    opts.title = opts.title or 'LSP Declarations'
    opts.map_result = locations_to_items
    list_locations(ms.textDocument_declaration, make_position_parameters, opts)
end

--- List the definitions of the symbol under the cursor.
--- This is a synchronous replacement for vim.lsp.buf.definition()
--- Will error if LSPs doesn't return at least one definition.
--- Use goto_definition(opts) if you want a list instead.
--- @param opts? MarkCodeAction.lsp.LocationListOpts
function M.list_definitions(opts)
    opts = opts or {}
    opts.title = opts.title or 'LSP Definitions'
    opts.map_result = locations_to_items
    list_locations(ms.textDocument_definition, make_position_parameters, opts)
end

--- List to the type definitions of the symbol under the cursor.
--- This is a synchronous replacement for vim.lsp.buf.type_definition().
--- Will error if LSPs doesn't return at least one type_definition.
--- Use goto_type_definition(opts) if you want a list instead.
--- @param opts? MarkCodeAction.lsp.LocationListOpts
function M.list_type_definitions(opts)
    opts = opts or {}
    opts.title = opts.title or 'LSP Type Definitions'
    opts.map_result = locations_to_items
    list_locations(ms.textDocument_typeDefinition, make_position_parameters, opts)
end

--- Lists the implementations for the symbol under the cursor.
--- This is a synchronous replacement for vim.lsp.buf.implementation().
--- Will error if LSPs don't return at least one implementation.
--- Use goto_implementation(opts) if you want a list instead.
--- @param opts? MarkCodeAction.lsp.LocationListOpts
function M.list_implementations(opts)
    opts = opts or {}
    opts.title = opts.title or 'LSP Implementations'
    opts.map_result = locations_to_items
    list_locations(ms.textDocument_implementation, make_position_parameters, opts)
end

--- Lists the references for the symbol under the cursor.
--- This is a synchronous replacement for vim.lsp.buf.references().
--- Will error if LSPs don't return at least one reference.
--- @param opts? MarkCodeAction.lsp.LocationListOpts
function M.list_references(opts)
    opts = opts or {}
    opts.title = opts.title or 'LSP References'
    opts.map_result = locations_to_items
    list_locations(ms.textDocument_references, make_position_parameters, opts)
end

--- Lists the document symbols in the buffer.
--- This is a synchronous replacement for vim.lsp.buf.document_symbol().
--- Will error if LSPs don't return at least one document symbol.
--- @param opts? MarkCodeAction.lsp.LocationListOpts
function M.list_document_symbols(opts)
    opts = opts or {}
    opts.title = opts.title or 'LSP Document Symbols'
    opts.map_result = symbols_to_items
    list_locations(ms.textDocument_documentSymbol, make_text_document_params, opts)
end

return M
