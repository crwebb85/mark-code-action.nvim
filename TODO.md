# ✅ TODO

-   [x] feat: add basic code action marks
-   [x] feat: handle LSP action conflicts between multiple active LSPs
-   [x] feat: add inspect mark command
-   [x] feat: add configuration defined marks
-   [x] feat: restrict mark command to only allow marks names to have a single
        alphanumeric character to distinguish it from configuration marks and
        prevent overriding what is in the configuration
-   [x] feat: add edit mark command
-   [x] feat: add running the code actions syncronously
-   [x] feat: extract timeout into config
-   [x] feat: add type definitions to find_actions descriptions to sync functions
-   [x] add action picker strategies for title equals, contains, begins with, ends with
-   [x] refactor: add a namespace to types to prevent conflicts with user defined types
-   [x] docs: add readme
-   [x] add syncronous lsp renaming
-   [x] refactor!: remove async version of running code actions
-   [x] fix: configuration for lsp_timeout_ms
-   [ ] fix: cursor after rename operation
-   [ ] feat: add user defined pickers to configuration
-   [ ] refactor: break up code to expose a public API and add it to the readme
-   [ ] chore: commit to a vocabulary (like whether the mark is the word used to select
        the action or the pair of the selection word and action identifier)
-   [ ] docs: add gifs showing how to use the plugin

## Nice to haves:

-   [ ] feat: determine how best to allow the user to change the timeout.
        I am considering either a command for setting the timeout or pass it
        into the run command as an optional argument
-   [ ] feat: add action picker strategies for matching the title against vimregex and lua regex
-   [ ] feat: add configuration/edit mark validation
-   [ ] feat: add a plugin checkhealth
    -   [ ] feat: check if any configuration mark names are a single character
-   [ ] feat: add tests
-   [ ] feat: add CI pipeline
-   [ ] feat: add issue template
-   [ ] feat: make capital letters signify global marks that get saved to a file and
        automatically loaded on plugin setup
-   [ ] feat: add global mark syncing commands (need to think through how I want that
        to work)

## Guiding Principals

-   I don't want to have to have complicated commands for adding and running marks.
    I just want the MarkCodeActionMark and MarkCodeActionMark command that takes
    in a name for the mark.
-   Running marks should not prompt the user for input so that they can be ran in
    macros.
-   I won't support configuring multiple actions to be chained together for the
    same mark. For example "Sorting Imports" and "Remove Unused Imports" ought to
    be configured to seperate marks. The user can always create a custom macro,
    keybinding, or command to chain them together.
-   Avoid plugin dependencies
