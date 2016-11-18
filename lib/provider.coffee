fs = require 'fs'
path = require 'path'
readline = require 'readline'

module.exports =
    selector: '.source.monkey2'
    disableForSelector: '.source.monkey2 .comment'

    # This will take priority over the default provider, which has a inclusionPriority of 0.
    # `excludeLowerPriority` will suppress any providers with a lower priority
    # i.e. The default provider will be suppressed
    inclusionPriority: 1
    excludeLowerPriority: false

    # This will be suggested before the default provider, which has a suggestionPriority of 1.
    suggestionPriority: 2

    buildSuggestions: ->
        console.log("building suggestions...")
        mPath = atom.config.get "language-monkey2.monkey2Path"
        modsPath = path.join(mPath,'/modules/mojo/')
        console.log("module path is:" + modsPath);

        # lets try reading the canvas module for kicks
        canvasModPath = path.join(modsPath, "/graphics/canvas.monkey2")
        canvasLineCount = 0
        methodRegex = RegExp /^\s*Method(.*)\((.*)\)$/, 'img'
        functionRegex = RegExp /^\s*Function(.*)\((.*)\)$/, 'img'
        classRegex = RegExp /^\s*Class/, 'im'
        #docRegex = RegExp /\s*#rem monkeydoc(.*)/, 'img'

        # TODO Read module data into data structure, eg.
        # class ->
        #   var
        #   method...
        # function ->
        # global ->
        # possibly keyed by namespace?
        
        fs.readFile canvasModPath, 'utf8', (err,data) =>
            if (err)
                throw err
            else
                foundMethods = methodRegex.exec(data)
                console.log(foundDocs)

                while methodRegex.lastIndex > 0
                    foundDocs = methodRegex.exec(data)
                    console.log(foundDocs)


        ###
        rl = readline.createInterface({
            input: fs.createReadStream(canvasModPath)
        })

        rl.on 'line', (line) =>
            index = line.search(classRegex)
            if index >= 0
                console.log line

        ###




    # Required: Return a promise, an array of suggestions, or null.
    getSuggestions: ({editor, bufferPosition, scopeDescriptor, prefix, activatedManually}) ->
        new Promise (resolve) ->
            resolve([text: 'monkey2AutoCompleteFTW'])

    # (optional): called _after_ the suggestion `replacementPrefix` is replaced
    # by the suggestion `text` in the buffer
    onDidInsertSuggestion: ({editor, triggerPosition, suggestion}) ->

    # (optional): called when your provider needs to be cleaned up. Unsubscribe
    # from things, kill any processes, etc.
    dispose: ->
