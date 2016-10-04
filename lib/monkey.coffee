MonkeyView = require './monkey-view'

exec = require('child_process').exec
spawn = require('child_process').spawn
os = require('os')

{CompositeDisposable} = require 'atom'

module.exports = Monkey =
    config:
        monkeyPath:
            title: 'Monkey-X Path'
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
    projects: {}
    projectNamespace: ''

    activate: (state) ->
        self = this
        @monkeyViewState = new MonkeyView(state.monkeyViewState)
        @panel = atom.workspace.addTopPanel(item: @monkeyViewState.getElement(), visible: false)

        # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
        @subscriptions = new CompositeDisposable

        @subscriptions.add atom.commands.add 'atom-workspace',
            'monkey:build': => @build(self.getCompilationTarget())

        @subscriptions.add atom.commands.add 'atom-workspace',
            'monkey:buildDefault': => @buildDefault()

        @subscriptions.add atom.commands.add 'atom-workspace',
            'monkey:buildCurrent': (event) ->
                self.build(atom.workspace.getActiveTextEditor().getPath())

        @subscriptions.add atom.commands.add '.file.selected',
            'monkey:setCompilationTarget': (event) ->
                self.setCompilationTarget(event.target)

        @subscriptions.add atom.commands.add '.file.selected',
            'monkey:buildSelected': (event) ->
                self.build(event.target.getAttribute('data-path'))


        @projectNamespace = atom.project.getPaths()[0]
        @projects = state.projects
        
        if @projects != null and @projects != undefined and @projects[@projectNamespace] != undefined

            compilationTarget = @projects[@projectNamespace].compilationTarget

            if compilationTarget != undefined
                pathToSearch = '[data-path="'+compilationTarget+'"]'
                fileNodes = document.querySelectorAll('.name.icon-file-text')
                fileNode = (item for item in fileNodes when item.getAttribute('data-path') == compilationTarget).pop()
                this.setCompilationTarget(fileNode)
            console.log("restored serialized state")
        else
            @projects = {}
            console.log "fresh projects state"

    deactivate: ->
        @modalPanel.destroy()
        @subscriptions.dispose()
        @monkeyViewState.destroy()

    serialize: ->
        monkeyViewState: @monkeyViewState.serialize()
        projects: @projects

    setCompilationTarget: (fileNode)->
        #check for existing compilationTarget; remove styling if found
        ctNode = document.getElementById("compilationTarget")
        if ctNode != null
            ctNode.id = ''
            ctNode.classList.remove('icon-arrow-right')
            ctNode.classList.add('icon-file-text')

        #add green arrow styling
        fileNode.classList.remove('icon-file-text')
        fileNode.classList.add('icon-arrow-right')
        fileNode.id = "compilationTarget"

        #save a copy of the file path to the project so we can serialize it
        @projects[@projectNamespace] =
            compilationTarget : fileNode.getAttribute('data-path')

    getCompilationTarget: ->
        @projects[@projectNamespace].compilationTarget

    buildDefault: ->
        target = this.getCompilationTarget()
        if target == null
            atom.notifications.addError("No compilation target set. Right click a monkey file in the folder tree and choose 'Set Compilation Target'")
            return false
        else
            this.build(target)

    build: (targetPath) ->
        extension = targetPath.substr(targetPath.lastIndexOf('.')+1)
        mPath = ''
        buildOut = null

        if extension == 'monkey2'
            mPath = atom.config.get "language-monkey.monkey2Path"
            if mPath == '' or mPath == null or mPath == undefined
                atom.notifications.addError("The path to Monkey2 needs to be set in the package settings")
                return
            if os.platform() == 'win32'
                mPath += "\\bin\\mx2cc_windows.exe"
            else if os.platform() == 'darwin'
                mPath += "/bin/mx2cc_macos"
            else
                mPath += "/bin/mx2cc_linux"
            buildOut = spawn mPath, ['makeapp', targetPath]

        else if extension == 'monkey'
            mPath = atom.config.get "language-monkey.monkeyPath"
            if mPath == '' or mPath == null or mPath == undefined
                atom.notifications.addError("The path to Monkey-X needs to be set in the package settings")
                return
            if os.platform() == 'win32'
                mPath += "\\bin\\transcc_winnt.exe"
            else if os.platform() == 'darwin'
                mPath += "/bin/transcc_macos"
            else
                mPath += "/bin/transcc_linux"
            buildOut = spawn mPath, ['-run', '-target=Html5_Game', '-config=debug', targetPath]
        else
            atom.notifications.addError("Not a monkey file!")
            return

        atom.notifications.addInfo("Compiling...")

        buildOut.stdout.on 'data', (data) ->
            message = data.toString().trim()
            errorRegex = /error/gi
            runningRegex = /Running/
            atom.notifications.addInfo(message)
            ###
            if message.search(errorRegex) > -1
                atom.notifications.addError(message)
            if message.search(runningRegex) > -1
                atom.notifications.addSuccess("Success!")
            ###
        buildOut.stderr.on 'data', (data) ->
            message = data.toString().trim()
            atom.notifications.addError(message)

    toggle: ->
        if @modalPanel.isVisible()
            @modalPanel.hide()
        else
            @modalPanel.show()
