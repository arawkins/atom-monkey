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

    suggestions : {}

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
        commentRegex = RegExp /\s*#rem monkeydoc(.*)/, 'img'

        # TODO Read module data into data structure, eg.
        # class ->
        #   var
        #   method...
        # function ->
        # global ->
        # possibly keyed by namespace?

        # store suggestions by type.
        @suggestions.methods = [];
        @suggestions.classes = [];
        @suggestions.functions = [];
        @suggestions.globals = [];
        @suggestions.properties = []

        inPrivate = false # when the parser hits a private declaration, it will skip everything until it hits a public again
        inClass = ""; # when inside a class definition, store the class here
        inNamespace = ""; # where the heck are we anyways?
        nextComment = ""; # when a monkeydoc comment is found, store it here; tack it on to the next thing that is found

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

        applyComment = (suggestion, comment) ->
            if comment.search "@hidden"
                return false

            suggestion.description = comment
            return true

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


            # ok, if we're not in private, lets check first for a comment
            if not inPrivate

                if nextComment == ''
                    checkComment = commentRegex.exec(line)
                    if checkComment != null
                        nextComment = checkComment[1].trim()
                        return

                if inClass == ''
                    checkClass = classRegex.exec(line)
                    if checkClass != null
                        inClass = checkClass[1].trim()
                        # store this class as a suggestion
                        suggestion =
                            text: inClass
                            type: 'class'
                        @suggestions.classes.push (suggestion)
                        return
                else
                    checkMethod = methodRegex.exec(line)
                    if checkMethod != null
                        methodName = checkMethod[1].trim()
                        methodParams = checkMethod[2].trim().split(',')
                        methodSnippet = ""

                        suggestion =
                            type: 'method'
                            description: ''


                        if methodParams.length > 0
                            methodSnippet = methodName + "("
                            for param, index in methodParams
                                # console.log index, param
                                if param != ''
                                    methodSnippet += "${"+(index+1)+":"+param+"}"
                                if index < methodParams.length-1
                                    methodSnippet += ","
                                else
                                    methodSnippet += ")$3"

                        if methodSnippet != ''
                            suggestion.snippet = methodSnippet
                        else
                            suggestion.text = methodName

                        if nextComment != ''
                            suggestion.description = nextComment
                            nextComment = ''
                        if suggestion.description.search('@hidden') == -1
                            @suggestions.methods.push(suggestion)
                        return

                    checkFunction = functionRegex.exec(line)
                    if checkFunction != null
                        functionName = checkFunction[1].trim()
                        functionParams = checkFunction[2].trim()
                        suggestion =
                            text:functionName
                            type:'function'
                            description: ''
                        if nextComment != ''
                            suggestion.description = nextComment
                            nextComment = ''
                        if suggestion.description.search('@hidden') == -1
                            @suggestions.functions.push(suggestion)
                        return

                    checkProperty = propertyRegex.exec(line)
                    if checkProperty != null
                        propertyName = checkProperty[1]
                        propertyType = checkProperty[2]
                        suggestion =
                            text: propertyName
                            type: 'Property'
                            rightLabel: propertyType
                            description: ''
                        if nextComment != ''
                            suggestion.description = nextComment
                            nextComment = ''
                        if suggestion.description.search('@hidden') == -1
                            @suggestions.properties.push(suggestion)

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
        # console.log @suggestions
        # console.log prefix, scopeDescriptor, bufferPosition, editor
        fullPrefix = editor.getTextInBufferRange( [[bufferPosition.row, 0], [bufferPosition.row, bufferPosition.column]]).trim()
        shortlist = []
        isMethod = fullPrefix.search(/\./)
        inParams = fullPrefix.search(/\(/)
        isAssignment = fullPrefix.search("=")
        isConstructor = fullPrefix.search("New")

        # let's just search everything to start with

        for own type, list of @suggestions
            if (isMethod >= 0 and type == 'methods' and inParams == -1) or (isMethod == -1 and type != 'methods')
                for suggestion in list
                    if (suggestion.hasOwnProperty('snippet') and suggestion.snippet != '')
                        if suggestion.snippet.search(prefix) >= 0
                            suggestion.replacementPrefix = prefix
                            shortlist.push(suggestion)
                    else if (suggestion.hasOwnProperty('text') and suggestion.text != '')
                        if suggestion.text.search(prefix) >= 0
                            suggestion.replacementPrefix = prefix
                            shortlist.push(suggestion)


        new Promise (resolve) ->
            resolve(shortlist)
