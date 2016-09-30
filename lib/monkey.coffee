MonkeyView = require './monkey-view'

exec = require('child_process').exec
spawn = require('child_process').spawn

{CompositeDisposable} = require 'atom'

module.exports = Monkey =
    config:
        monkeyPath:
            title: 'Monkey-x Path'
            description: 'The path to your installation of Monkey-x'
            type: 'string'
            default: ''
        monkey2Path:
            title: 'Monkey2 Path'
            description: 'The path to your installation of Monkey2'
            type: 'string'
            default: ''

    monkeyViewState: null
    modalPanel: null
    subscriptions: null
    compilationTarget: ''

    activate: (state) ->
        self = this
        @monkeyViewState = new MonkeyView(state.monkeyViewState)
        @modalPanel = atom.workspace.addModalPanel(item: @monkeyViewState.getElement(), visible: false)

        # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
        @subscriptions = new CompositeDisposable
        @compilationTarget = state.compilationTarget

        # Register command that toggles this view
        @subscriptions.add atom.commands.add 'atom-workspace',
            'monkey:build': => @build()

        @subscriptions.add atom.commands.add '.file.selected',
            'monkey:setCompilationTarget': (event) ->
                filePath = event.target.getAttribute('data-path')
                self.setCompilationTarget(filePath)

    deactivate: ->
        @modalPanel.destroy()
        @subscriptions.dispose()
        @monkeyViewState.destroy()

    serialize: ->
        monkeyViewState: @monkeyViewState.serialize()
        compilationTarget: @compilationTarget

    setCompilationTarget: (filePath)->
        @compilationTarget = filePath

    build: ->
        if @compilationTarget == ''
            console.log("no compilation target set")
            return false

        m2Path = atom.config.get "monkey.monkey2Path"
        m2Path += "\\bin\\mx2cc_windows.exe"
        buildOut = spawn m2Path, ['makeapp', @compilationTarget]
        atom.notifications.addInfo("Compiling...")

        buildOut.stdout.on 'data', (data) ->
            message = data.toString().trim()
            console.log message
            errorRegex = /error/gi
            mx2Regex = /mx2cc/
            runningRegex = /Running/

            if message.search(errorRegex) > -1
                atom.notifications.addError(message)
            if message.search(runningRegex) > -1
                atom.notifications.addSuccess("Success!")

        buildOut.stderr.on 'data', (data) ->
            message = data.toString().trim()
            console.log message
            atom.notifications.addError(message)

    toggle: ->
        if @modalPanel.isVisible()
            @modalPanel.hide()
        else
            @modalPanel.show()
