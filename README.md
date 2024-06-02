# Mark Code Action

**mark-code-action.nvim** is a vim macro friendly extension to the neovim LSP client. This plugin is still under heavy development, and I may still make breaking changes to the commands and API.

<!-- TOC -->

-   [Requirements](#requirements)
-   [Features](#features)
-   [Motivating Examples](#motivating-examples)
-   [Installation](#installation)
-   [Configuration](#configuration)
-   [Recipes](#recipes)
-   [Advanced topics](#advanced-topics)
-   [Commands](#commands)
-   [API](#api)

## ⚡️ Requirements

-   Neovim >= **0.10.0**

## ✨ Features

-   **LSP code action marks** - can be executed within vim macros.
-   **Mark on the fly** - `MarkCodeActionMark a` to select a code action to bind to the letter `a`
-   **Favorite marks** - Can add your favorite marks to your config so you can easily create command aliases and keymaps.
-   **UI blocking version LSP rename** - for, you guessed it, renaming variables within vim macros.
-   **LSP code action cdo and ldo support** - run a code action on every item in the quickfix/location list

## 🧠 Motivating Examples

Below are some of the examples of things that I specifcally used this plugin to do and were the motivation behind the its features.

**Removing all unused imports from a codebase**: Most IDEs have a button to remove all unused imports however creating a way to do so in neovim has been traditionally a pain since most LSP servers only have a code action that operates on the current file.

1. Add diagnostics to quick fix list. I use a usercommand I defined in my config `:QFLspDiagnostics`.
   [QFLspDiagnostics gist](https://gist.github.com/crwebb85/fda79b17a7df8517d5ae0a1cc7722611)
2. Filter the quickfix list for just the diagnostics with the words "unnecessary imports" using `:Cfilter "unnecessary imports"`
3. Navigate to first item in quick fix list with `:cfirst`
4. Using this plugin mark the code action for "Remove unnecessary usings." Use the command `:MarkCodeAction a` and select the correct code action in the prompt.
5. Run the code action once per file in the quickfix list using the command `:cfdo MarkCodeActionRun a`.

**Renaming a list of classes and creating an interface for them**: I had to refactor a code base to convert it to use the new dependency injection framework in .NET.
For each service layer class, I wanted to create an interface so that I could use dependency inversion. I also wanted to append a suffix to each of the classes to make
it easier to distinguish the services from other classes with the same name.

1. Add each class to the quickfix list. `:vimgrep "class" **/*.cs`.
2. Go to the first item in the quick fix list `:cfirst`.
3. Press `w` to jump from the class identifier to the class name.
4. Using this plugin, run the command `MarkCodeActionMark a` and select the code action for "Extract interface".
5. Go back to the first item in the quick fix list `:cfirst`.
6. Start recording a macro with the. While in normal mode type `qs` to record to the `s` register.
7. Press `w` to jump from the class identifier to the class name.
8. Run the command `:MarkCodeActionRename`.
9. Add the suffix you wish to add to the name prompt and press enter while in normal mode.
10. Create the interface by running the command `:MarkCodeActionRun a`.
11. Go to the next item in the quickfix list with `:cnext`.
12. Stop the macro recording by pressing `q` while in normal mode.
13. Run the macro on the remaining items in the quickfix list with the keymap `<number of items remaining>@s`. If you had 15 items remaining then it would be `15@s`.

## 📦 Installation

lazy.nvim

```lua
    {
        'crwebb85/mark-code-action.nvim',
        opts = {},
    }
```

## ⚙️ Configuration

The list of configuration options

```lua
require('mark-code-action')({
    -- Map of named marks for your favorite LSP code actions that you don't want to
    -- mark on the fly. This can also be useful it you wish to create keymaps for
    -- a code actions.
    marks = {
        -- User can define a mark name. For example I use CleanImports
        CleanImports = {
            -- name of the LSP client
            client_name = 'omnisharp',
            -- optionally define the code action kind
            kind = 'quickfix',
            -- the title the LSP server uses for the code action
            title = 'Remove unnecessary usings',
        },
        DisableDiagnostic = {
            client_name = 'lua_ls',
            kind = 'quickfix',
            title = 'Disable diagnostics on this line',
            -- lua_ls uses a dynamic title `Disable diagnostics on this line (undefined-field).`
            -- so to disable any diagnostic warning we need to use the begins_with picker
            -- of the diagnostic
            picker = 'begins_with',
        },
    },
    -- Timeout used when making syncronous lsp requests. Note commands like MarkCodeActionRun
    -- may make multiple request to the lsp so it could potentially (although probably won't) take longer
    -- than this timeout
    lsp_timeout_ms = 2000,
})
```

## Recipes

TODO

## Advanced topics

TODO

## Commands

Note: Commands are subject to have breaking changes as I work on improving the UX.

Also, I namespace commands with the `MarkCodeAction` prefix regardless of if the command is for working with lsp codeactions.

-   LSP Code Actions
    -   `MarkCodeActionMark <mark name>` - Prompts the user to select a code action at the cursor and marks it to a letter.
    -   `MarkCodeActionRun <mark name>` - Runs the code action for the mark at the cursors location. If the code action is not valid for the cursor location then nothing will happen.
    -   `MarkCodeActionInspect <mark name>` - Prints the internal representation of the code action mark
    -   `MarkCodeActionEdit <mark name>`
-   LSP Rename
    -   `MarkCodeActionRename` - Renames the element at the cursor using the LSP server. Prompts the user for a new name using a prompt buffer which adds more flexibility when used within vim macros.

## API

TODO
