{$} = require 'atom-space-pen-views'

module.exports =
class MonkeyView
  constructor: (serializedState) ->
    # Create root element
    @element = document.createElement('atom-panel')
    @element.classList.add('monkey-panel')
    @element.classList.add('inline-block-tight')

    # Create message element
    message = document.createElement('div')
    message.textContent = "Monkey2"
    message.classList.add('inline-block')
    message.classList.add('monkey2Logo')

    @element.appendChild(message)


    targetSelector = document.createElement('select')
    targetSelector.classList.add('input-select')
    targetSelector.classList.add('inline-block')

    target1 = document.createElement('option')
    target1.textContent = "desktop"
    targetSelector.appendChild(target1)

    target2 = document.createElement('option')
    target2.textContent = "emscripten"
    targetSelector.appendChild(target2)

    configSelector = document.createElement('select')
    configSelector.classList.add('input-select')
    configSelector.classList.add('inline-block')

    config1 = document.createElement('option')
    config1.textContent = "debug"
    configSelector.appendChild(config1)

    config2 = document.createElement('option')
    config2.textContent = "release"
    configSelector.appendChild(config2)

    appTypeSelector = document.createElement('select')
    appTypeSelector.classList.add('input-select')
    appTypeSelector.classList.add('inline-block')

    appType1 = document.createElement('option')
    appType1.textContent = "gui"
    appTypeSelector.appendChild(appType1)

    appType2 = document.createElement('option')
    appType2.textContent = "console"
    appTypeSelector.appendChild(appType2)

    runArrow = document.createElement('button')
    runArrow.classList.add('icon')
    runArrow.classList.add('icon-playback-play')
    runArrow.classList.add('btn')
    runArrow.classList.add('btn-success')
    runArrow.classList.add('monkey-play-btn')


    @element.appendChild(targetSelector)
    @element.appendChild(configSelector)
    @element.appendChild(appTypeSelector)
    @element.appendChild(runArrow)

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @element.remove()

  getElement: ->
    @element
