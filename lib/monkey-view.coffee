$ = require 'jquery'

module.exports =
class MonkeyView
    constructor: (serializedState) ->
        self = this

        # Create root element
        @element = document.createElement('atom-panel')
        @element.classList.add('monkey-panel')
        @element.classList.add('inline-block-tight')


        # Create compiler controls
        compilerControls = document.createElement('div')
        compilerControls.classList.add('inline-block', 'monkey-compiler-controls')

        # Create message element
        message = document.createElement('div')
        message.textContent = "Monkey2"
        message.classList.add('inline-block')
        message.classList.add('monkey2Logo')

        compilerControls.appendChild(message)


        @actionSelector = document.createElement('select')
        @actionSelector.classList.add('input-select', 'inline-block')

        action1 = document.createElement('option')
        action1.textContent = "run"
        @actionSelector.appendChild(action1)

        action2 = document.createElement('option')
        action2.textContent = "build"
        @actionSelector.appendChild(action2)

        @targetSelector = document.createElement('select')
        @targetSelector.classList.add('input-select')
        @targetSelector.classList.add('inline-block')

        target1 = document.createElement('option')
        target1.textContent = "desktop"
        @targetSelector.appendChild(target1)

        target2 = document.createElement('option')
        target2.textContent = "emscripten"
        @targetSelector.appendChild(target2)

        @configSelector = document.createElement('select')
        @configSelector.classList.add('input-select')
        @configSelector.classList.add('inline-block')

        config1 = document.createElement('option')
        config1.textContent = "debug"
        @configSelector.appendChild(config1)

        config2 = document.createElement('option')
        config2.textContent = "release"
        @configSelector.appendChild(config2)

        @appTypeSelector = document.createElement('select')
        @appTypeSelector.classList.add('input-select')
        @appTypeSelector.classList.add('inline-block')

        appType1 = document.createElement('option')
        appType1.textContent = "gui"
        @appTypeSelector.appendChild(appType1)

        appType2 = document.createElement('option')
        appType2.textContent = "console"
        @appTypeSelector.appendChild(appType2)

        @playBtn = document.createElement('button')
        @playBtn.classList.add('icon')
        @playBtn.classList.add('icon-playback-play')
        @playBtn.classList.add('btn')
        @playBtn.classList.add('btn-success')
        @playBtn.classList.add('monkey-play-btn')

        compilerControlsLabel = document.createElement('div')
        compilerControlsLabel.classList.add('inline-block', 'label', 'text-highlight')
        compilerControlsLabel.textContent = "mx2cc"

        compilerControls.appendChild(compilerControlsLabel)
        compilerControls.appendChild(@actionSelector)
        compilerControls.appendChild(@targetSelector)
        compilerControls.appendChild(@configSelector)
        compilerControls.appendChild(@appTypeSelector)
        compilerControls.appendChild(@playBtn)

        @output = document.createElement('atom-panel')
        @output.classList.add('monkey-console')
        @outputMessages = document.createElement('ul')
        @outputMessages.classList.add('info-messages', 'block', 'run-command', 'native-key-bindings')
        @outputMessages.tabIndex = -1
        @output.appendChild(@outputMessages)

        outputControls = document.createElement('div')
        outputControls.classList.add('controls', 'inline-block')
        # outputControlsLabel = document.createElement('div')
        # outputControlsLabel.classList.add('inline-block', 'label', 'text-highlight')
        # outputControlsLabel.textContent = "output"
        # outputControls.appendChild(outputControlsLabel)

        @toggleBtn = document.createElement('button')
        @toggleBtn.classList.add('icon', 'icon-browser', 'btn', 'inline-block')
        @toggleBtn.textContent = "output"
        outputControls.appendChild(@toggleBtn)

        @clearBtn = document.createElement('button')
        @clearBtn.classList.add('icon', 'icon-circle-slash', 'btn', 'inline-block')
        @clearBtn.textContent = "clear"
        # outputControls.appendChild(@clearBtn)
        # Not sure if I need this...

        @element.appendChild(compilerControls)
        @element.appendChild(outputControls)

    # Returns an object that can be retrieved when package is activated
    serialize: ->

    # Tear down any state and detach
    destroy: ->
        @element.remove()
        @playBtn.remove()


    getOptions: ->
        action: $(@actionSelector).val()
        target: $(@targetSelector).val()
        config: $(@configSelector).val()
        appType: $(@appTypeSelector).val()

    getPlayBtn: ->
        @playBtn

    getClearBtn: ->
        @clearBtn

    getToggleBtn: ->
        @toggleBtn

    getElement: ->
        @element

    getOutput: ->
        @output

    outputMessage: (message) ->
        titleRegex = RegExp /^(Mx2cc)\s(version)\s(.*)$/, 'm'
        errorRegex = RegExp /^(.*)\s\[([0-9]+)\]\s:\sError\s:\s(.*)$/, 'm'
        #errorRegex = RegExp /^(.*)Error(.*)$/

        messageLines = message.split('\n')
        for line in messageLines
            messageNode = document.createElement('li')
            checkErrorRegex = errorRegex.exec(line)
            checkTitleRegex = titleRegex.exec(line)

            if checkTitleRegex != null
                titleElement = document.createElement('span')
                titleElement.classList.add('title')
                titleElement.textContent = line
                messageNode.appendChild(titleElement)

            else if checkErrorRegex != null

                messageNode.classList.add('error')

                errorLabel = document.createElement('span')
                errorLabel.classList.add('label')
                errorLabel.textContent = "Error "

                fileName = document.createElement('span')
                fileName.classList.add('file')
                fileName.dataset.lineNumber = checkErrorRegex[2]
                fileName.textContent = checkErrorRegex[1]
                fileName.addEventListener "click", (e) =>

                    fileToOpen = e.target.textContent
                    lineToView = Number(e.target.dataset.lineNumber)
                    lineToView -= 1
                    atom.workspace.open fileToOpen, {"initialLine": lineToView}


                lineNumber = document.createElement('span')
                lineNumber.classList.add('lineNumber')
                lineNumber.textContent = " Line "+checkErrorRegex[2]+" "

                errorMessage = document.createElement('span')
                errorMessage.classList.add('message')
                errorMessage.textContent = checkErrorRegex[3]

                messageNode.appendChild(errorLabel)
                messageNode.appendChild(fileName)
                messageNode.appendChild(lineNumber)

                messageNode.appendChild(errorMessage)

            else
                messageNode.textContent = line

            @outputMessages.appendChild(messageNode)
            @outputMessages.scrollTop = @outputMessages.scrollHeight

    hideOutput: ->
        ###
        @toggleBtn.classList.remove('icon-triangle-down')
        @toggleBtn.classList.add('icon-triangle-up')
        @toggleBtn.textContent = "show"
        ###

    showOutput: ->
        ###
        @toggleBtn.classList.add('icon-triangle-down')
        @toggleBtn.classList.remove('icon-triangle-up')
        @toggleBtn.textContent = "hide"
        ###

    clearOutput: ->
        console.log "Clearing output..."
        $(@outputMessages).empty()
