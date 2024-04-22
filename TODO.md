# ✅ TODO

-   [x] add basic code action marks
-   [x] handle LSP action conflicts between multiple active LSPs
-   [x] add inspect mark command
-   [x] add ~~global~~ configuration defined marks
-   [x] restrict mark command to only allow marks names to have a single
        alphanumeric character to distinguish it from configuration marks and
        prevent overriding what is in the configuration
-   [ ] add the ability to bind several actions to the same configuration mark.
        For example "RemoveUnusedImports" is a common action in many LSPs and
        it would be nice to be able to run "MarkCodeActionRun RemoveUnusedImports"
        and it just work for all the LSPs I have configured in my configuration.
        I'm thinking either do a lookup based on lsp name or use a ranked list.
-   [ ] add a plugin checkhealth
    -   [ ] check if any configuration mark names are a single character
-   [ ] make capital letters signify global marks that get saved to a file and
        automatically loaded on plugin setup
-   [ ] add global mark syncing commands (need to think through how I want that
        to work)
-   [ ] add action picker override to configuration
-   [ ] add a namespace to types to prevent conflicts with user defined types
-   [ ] commit to a vocabulary (like whether the mark is the word used to select
        the action or the pair of the selection word and action identifier)
-   [ ] add readme
-   [ ] add gifs showing how to use the plugin
-   [ ] add docs
-   [ ] add tests
-   [ ] add CI pipeline
-   [ ] add issue template

# Guiding Principals

-   I don't want to have to have complicated commands for adding and running marks.
    I just want the MarkCodeActionMark and MarkCodeActionMark command that takes
    in a name for the mark.
-   Running marks should not prompt the user for input so that they can be ran in
    macros.
