MonkeyView = require './monkey-view'
$ = require 'jquery'

exec = require('child_process').exec
spawn = require('child_process').spawn
os = require('os')


{CompositeDisposable} = require 'atom'

module.exports = Monkey =
    config:
        monkey2Path:
            title: 'Monkey2 Path'
            description: 'The full path to your installation of Monkey2 (eg. /home/user/monkey2, c:\\monkey2)'
            type: 'string'
            default: ''
        showOutputOnBuild:
            title: 'Automatically show output on build'
            type: 'boolean'
            default: true
        saveOnBuild:
            title: 'Save files on build'
            type: 'boolean'
            default: true
    monkeyViewState: null
    modalPanel: null
    subscriptions: null
    compilationTarget: ''
    projects: {}
    projectNamespace: ''
    provider: null
    self: this

    provide: ->
        @provider

    activate: (state) ->
        self = @
        @monkeyViewState = new MonkeyView(state.monkeyViewState)
        @panel = atom.workspace.addBottomPanel(item: @monkeyViewState.getElement(), visible: true)
        @outputPanel = atom.workspace.addBottomPanel(item: @monkeyViewState.getOutput(), visible: false)
        @provider = require './provider'
        @provider.buildSuggestions()
        setTimeout((()=>@provider.reParseVariables()),2000)

        # Enable view event handlers
        $(@monkeyViewState.playBtn).on 'click', (event) =>
            target = @getCompilationTarget()
            if target != undefined and target != ''
                @buildDefault()
            else
                @buildCurrent()

        $(@monkeyViewState.toggleBtn).on 'click', (event) =>
            if @outputPanel.isVisible()
                @outputPanel.hide()
                @monkeyViewState.hideOutput()
            else
                @outputPanel.show()
                @monkeyViewState.showOutput()

        $(@monkeyViewState.clearBtn).on 'click', (event) =>
            @monkeyViewState.clearOutput()


        # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
        @subscriptions = new CompositeDisposable

        @subscriptions.add atom.commands.add 'atom-workspace',
            'monkey2:build': => @build(self.getCompilationTarget())

        @subscriptions.add atom.commands.add 'atom-workspace',
            'monkey2:buildDefault': => @buildDefault()

        @subscriptions.add atom.commands.add 'atom-workspace',
            'monkey2:buildCurrent': => @buildCurrent()

        @subscriptions.add atom.commands.add 'atom-workspace',
            'monkey2:hideOutput': => @hideOutput()

        @subscriptions.add atom.commands.add 'atom-workspace',
            'monkey2:toggleOutput': => @toggleOutput()

        @subscriptions.add atom.commands.add '.file.selected',
            'monkey2:setCompilationTarget': (event) ->
                self.setCompilationTarget(event.target)

        @subscriptions.add atom.commands.add '.file.selected',
            'monkey2:clearCompilationTarget': => @clearCompilationTarget()

        @subscriptions.add atom.commands.add '.file.selected',
            'monkey2:buildSelected': (event) ->
                self.build(event.target.getAttribute('data-path'))

        @projectNamespace = atom.project.getPaths()[0]
        @projects = state.projects

        if @projects != null and @projects != undefined and @projects[@projectNamespace] != undefined

            compilationTarget = @projects[@projectNamespace].compilationTarget

            if compilationTarget != undefined and compilationTarget != ''
                pathToSearch = '[data-path="'+compilationTarget+'"]'
                fileNodes = document.querySelectorAll('.name.icon-file-text')
                fileNode = (item for item in fileNodes when item.getAttribute('data-path') == compilationTarget).pop()
                @setCompilationTarget(fileNode)
            console.log("restored serialized state")
        else
            @projects = {}
            @projects[@projectNamespace] = ''
            @projects[@projectNamespace].compilationTarget = ''
            console.log "fresh projects state"

        @subscriptions.add atom.workspace.observeTextEditors (editor) =>
            if /.monkey2$/.test(editor.getPath())
                @subscriptions.add editor.onDidStopChanging () =>
                    @provider.parseFile(editor.getPath())


    deactivate: ->
        @subscriptions.dispose()
        @monkeyViewState.destroy()

    serialize: ->
        monkeyViewState: @monkeyViewState.serialize()
        projects: @projects

    observeTextEditors: (editor) =>



    setCompilationTarget: (fileNode)->
        @clearCompilationTarget()

        #add green arrow styling
        fileNode.classList.remove('icon-file-text')
        fileNode.classList.add('icon-arrow-right')
        fileNode.id = "compilationTarget"

        #save a copy of the file path to the project so we can serialize it
        @projects[@projectNamespace] =
            compilationTarget : fileNode.getAttribute('data-path')

    getCompilationTarget: ->
        @projects[@projectNamespace].compilationTarget

    clearCompilationTarget: ->
        #check for existing compilationTarget; remove styling if found
        ctNode = document.getElementById("compilationTarget")
        if ctNode != null
            ctNode.id = ''
            ctNode.classList.remove('icon-arrow-right')
            ctNode.classList.add('icon-file-text')
        @projects[@projectNamespace].compilationTarget = ''


    hideOutput: ->
        @outputPanel.hide()

    showOutput: ->
        @outputPanel.show()

    toggleOutput: ->
        if @outputPanel.isVisible() then @outputPanel.hide() else @outputPanel.show()

    saveThenBuild: (targetPath) ->
        promises = []

        for editor in atom.workspace.getTextEditors()
            if editor != '' and editor != undefined and editor.isModified()
                editorPath = editor.getPath()
                extension = editorPath.substr(editorPath.lastIndexOf('.')+1)
                if extension = "monkey2"
                    promises.push(editor.save())

        Promise.all(promises).then(() =>
            @build(targetPath)
        )


    buildCurrent: ->
        currentEditor = atom.workspace.getActiveTextEditor()
        if currentEditor != '' and currentEditor != undefined
            if atom.config.get "language-monkey2.saveOnBuild"
                @saveThenBuild(currentEditor.getPath())
            else
                @build(currentEditor.getPath())

    buildDefault: ->
        target = @getCompilationTarget()
        if target == null
            atom.notifications.addError("No compilation target set. Right click a monkey file in the folder tree and choose 'Set Compilation Target'")
            return false
        else
            if atom.config.get "language-monkey2.saveOnBuild"
                @saveThenBuild(target)
            else
                @build(target)


    build: (targetPath) ->
        extension = targetPath.substr(targetPath.lastIndexOf('.')+1)
        mPath = ''
        buildOut = null

        if extension == 'monkey2'
            mPath = atom.config.get "language-monkey2.monkey2Path"
            if mPath == '' or mPath == null or mPath == undefined
                atom.notifications.addError("The path to Monkey2 needs to be set in the package settings")
                atom.workspace.open("atom://config/packages/language-monkey2")
                return
            if os.platform() == 'win32'
                mPath += "\\bin\\mx2cc_windows.exe"
            else if os.platform() == 'darwin'
                mPath += "/bin/mx2cc_macos"
            else
                mPath += "/bin/mx2cc_linux"
            options = @monkeyViewState.getOptions()
            buildOut = spawn mPath, ['makeapp', '-'+options.action, '-target='+options.target, '-config='+options.config, '-apptype='+options.appType, targetPath]
            @monkeyViewState.clearOutput()

            if atom.config.get "language-monkey2.showOutputOnBuild"
                @showOutput()
            else
                atom.notifications.addInfo("mx2cc compiling...")
        else
            atom.notifications.addError("Not a monkey2 file!")
            return

        buildOut.stdout.on 'data', (data) =>
            message = data.toString().trim()
            errorRegex = /error/gi
            runningRegex = /Running/
            @monkeyViewState.outputMessage(message)

        buildOut.stderr.on 'data', (data) ->
            message = data.toString().trim()
            atom.notifications.addError(message)
