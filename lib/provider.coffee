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
        modsPath = path.join(mPath,'/modules/')
        console.log("module path is:" + modsPath);

        # lets try reading the canvas module for kicks
        canvasModPath = path.join(modsPath, "/mojo/graphics/canvas.monkey2")
        privateRegex = RegExp /^\s*Private\s*$/,'img'
        publicRegex = RegExp /^\s*Public\s*$/,'img'
        methodRegex = RegExp /^\s*Method(.*)\((.*)\)$/, 'img'
        functionRegex = RegExp /^\s*Function(.*)\((.*)\)$/, 'img'
        namespaceRegex = RegExp /^\s*Namespace\s*(.*)$/, 'img'
        propertyRegex = RegExp /^\s*Property\s*(.*):(.*)\(\)$/, 'img'
        classRegex = RegExp /^\s*Class(.*)$/, 'im'
        mDocRegex = RegExp /\s*#rem monkeydoc(.*)/, 'img'

        # TODO Read module data into data structure, eg.
        # class ->
        #   var
        #   method...
        # function ->
        # global ->
        # possibly keyed by namespace?

        # store suggestions by type.
        methods = [];
        classes = [];
        functions = [];
        globals = [];

        inPrivate = false # when the parser hits a private declaration, it will skip everything until it hits a public again
        inClass = ""; # when inside a class definition, store the class here
        inNamespace = ""; # where the heck are we anyways?

        fs.readFile canvasModPath, 'utf8', (err,data) =>
            if (err)
                throw err
            else
                # look for the namespace


                ###
                foundMethods = methodRegex.exec(data)
                console.log(foundMethods)

                while methodRegex.lastIndex > 0
                    foundMethods = methodRegex.exec(data)
                    console.log(foundMethods)
                ###



        rl = readline.createInterface({
            input: fs.createReadStream(canvasModPath)
        })

        rl.on 'line', (line) =>
            # let's look for namespace first, since it should be first
            if inNamespace == ''
                checkNamespace = namespaceRegex.exec(line)
                if checkNamespace != null
                    inNamespace = checkNamespace[1].trim()
                    console.log ("in namespace: " + inNamespace)
                    return;

            # check for public/private
            if inPrivate
                checkPublic = publicRegex.exec(line)
                if checkPublic != null
                    console.log "back in public"
                    inPrivate = false
                    return;

            checkPrivate = privateRegex.exec(line)
            if checkPrivate != null
                console.log "inside private declaration"
                inPrivate = true
                return;

            # ok, if we're not in private, lets check first for a class
            if not inPrivate
                if inClass == ''
                    checkClass = classRegex.exec(line)
                    if checkClass != null
                        inClass = checkClass[1].trim()
                        console.log "in class: " + inClass
                        # store this class as a suggestion
                        classes.push(inClass)
                        return;
                else
                    checkMethod = methodRegex.exec(line)
                    if checkMethod != null
                        methodName = checkMethod[1].trim()
                        methodParams = checkMethod[2].trim()
                        methodObj =
                            name: methodName
                            params: methodParams
                        methods.push(methodObj)
                        return

                    checkFunction = functionRegex.exec(line)
                    if checkFunction != null
                        functionName = checkFunction[1].trim()
                        functionParams = checkFunction[2].trim()
                        functionObj =
                            name:functionName
                            params: functionParams
                        functions.push(functionObj)
                        return

                    checkProperty = propertyRegex.exec(line)
                    if checkProperty != null
                        propertyName = checkProperty[1]
                        propertyType = checkProperty[2]
                        propertyObj =
                            name:propertyName
                            type: propertyType
                            


            ###
            result = namespaceRegex.exec(line)
            # console.log line
            if result != null
                console.log result[1]
                nsArray = result[1].split('.')
                console.log nsArray
                for seg in nsArray
                    console.log seg
                # ok, we have the namespace broken into array segments
                # now what?

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
