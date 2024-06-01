# ✅ TODO

-   [x] add basic code action marks
-   [x] handle LSP action conflicts between multiple active LSPs
-   [x] add inspect mark command
-   [x] add ~~global~~ configuration defined marks
-   [x] restrict mark command to only allow marks names to have a single
        alphanumeric character to distinguish it from configuration marks and
        prevent overriding what is in the configuration
-   [x] add edit mark command
-   [x] add running the code actions syncronously using bang
-   [x] extract timeout into config
-   [ ] determine how best to allow the user to change the timeout.
        I am considering either a command for setting the timeout or pass it
        into the run command as an optional argument
-   [x] add type definitions to find_actions descriptions to sync functions
-   [ ] add match strategies (title equals, contains, begins with, ends with, vimregex, lua regex, etc)
-   [ ] add the ability to bind several actions to the same configuration mark.
        For example "RemoveUnusedImports" is a common action in many LSPs and
        it would be nice to be able to run "MarkCodeActionRun RemoveUnusedImports"
        and it just work for all the LSPs I have configured in my configuration.
        I'm thinking either do a lookup based on lsp name or use a ranked list.
-   [ ] Add configuration/edit mark validation
-   [ ] add a plugin checkhealth
    -   [ ] check if any configuration mark names are a single character
-   [ ] make capital letters signify global marks that get saved to a file and
        automatically loaded on plugin setup
-   [ ] add global mark syncing commands (need to think through how I want that
        to work)
-   [ ] add action picker override to configuration
-   [x] add a namespace to types to prevent conflicts with user defined types
-   [ ] commit to a vocabulary (like whether the mark is the word used to select
        the action or the pair of the selection word and action identifier)
-   [ ] add readme
-   [ ] add gifs showing how to use the plugin
-   [ ] add docs
-   [ ] add tests
-   [ ] add CI pipeline
-   [ ] add issue template
-   [x] add syncronous lsp renaming

# Guiding Principals

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

# Brainstorming Datastructure For Marks and their configuration:

-   array of code actions identifiers

    -   Pros:
        -   easy to program
        -   easy to cofigure
        -   could allow the user to override the function to pick which one to run
            (but this feature would likely be never used since it would be complicated to program)
    -   Cons:
        -   would need to loop over all the code actions in the list to find the
            first available code action
        -   harder to get a list of all the marks compatible with a lsp

-   dictionary of code actions identifiers (key = lsp name)
    (3)

    -   Pros:
        -   easy to get a list of all the marks compatible with a lsp
        -   easy configuration
        -   fairly easy change
    -   Cons:
        -   cannot have fallthrough code actions (similar to how conform.nvim has fall through
            formatters when a formatter is unavailable)
        -   the user would have to write the lsp name in both the key and in the client_name field which the user may find annoying

-   configure as an array of code actions but store as a dictionary of code actions identifiers (key = lsp name)
    (2)

    -   Pros:
        -   easy to configure
        -   easy to pick code action
    -   Cons:
        -   user may override a code action by configuring it twice in the array (may need a healthcheck for it)
        -   requires processing the array on plugin load to convert it to a dictionary
        -   most code actions in configuration would be an array with a single element

-   configure as a code action idnetifier | an array of code action identifiers
    but store as a dictionary of code actions identifiers (key = lsp name)
    (1)

    -   Pros:
        -   easy to configure
        -   easy to read configuration
        -   easy to pick code action
        -   most code actions in configuration won't be an array with a single elements
    -   Cons:
        -   user may override a code action by configuring it twice in the array (may need a healthcheck for it)
        -   requires processing the array on plugin load to convert it to a dictionary

-   dictionary of code actions identifier arrays (key = lsp name)
    (Terrible)

    -   Pros:
        -   easy to get a list of all the marks compatible with a lsp
        -   can have a fallback action (similar to how conform.nvim has fallback
            formatters when a formatter is unavailable) This may not be a use case worth my time
    -   Cons:
        -   would make the configuration much more complicated

-   code action identifier | array of code actions identifiers
    (Sub-Optimal)
    -   Pros:
        -   allow fall through code actions
        -   enables fallthrough code actions (similar to how conform.nvim has fall through
            formatters when a formatter is unavailable)
        -   configuration is easier than some of the other options
    -   Cons:
        -   harder to program
        -   slightly complicates configuration
        -   would need to detect whether a code action or an array of codeactions
