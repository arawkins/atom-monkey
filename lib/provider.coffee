fs = require 'fs'
path = require 'path'
readline = require 'readline'
dir = require 'node-dir'

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

    suggestions :
        methods: []
        classes: []
        functions: []
        globals: []
        variables: []
        properties: []
        instances: []

    buildSuggestions: ->
        console.log("building suggestions...")
        mPath = atom.config.get "language-monkey2.monkey2Path"
        modsPath = path.join(mPath,'/modules/')
        console.log("module path is:" + modsPath);
        # lets try reading the canvas module for kicks
        #canvasModPath = path.join(modsPath, "/mojo/graphics/canvas.monkey2")
        #@parseFile(canvasModPath)
        console.log ("project path is" + [0])

        for projectPath in atom.project.getPaths()
            dir.files(projectPath, (err, files) =>
                if (err)
                    console.log err
                    return
                files = files.filter((file) ->
                   return /.monkey2$/.test(file)
                )
                for file in files
                    @parseFile(file)
            )

        dir.files(path.join(modsPath, '/mojo/graphics'), (err, files) =>
            if (err)
                console.log err
                return
            files = files.filter((file) ->
               return /.monkey2$/.test(file)
            )

            for file in files
                @parseFile(file)

        )

        #@parseFile(path.join(modsPath, 'mojo/graphics/canvas.monkey2'))

    parseFile: (filePath) ->
        console.log("parsing " + filePath)
        privateRegex = RegExp /^\s*Private\s*$/,'im'
        publicRegex = RegExp /^\s*Public\s*$/,'im'
        globalRegex = RegExp /^\s*Global\s+\b(\w+?):(\w+?)\b/, 'im'
        fieldRegex = RegExp /^\s*Field\s+\b(\w+?):(\w+?)\b/, 'im'
        variableRegex = RegExp /^\s*Global|Local\s+\b(\w+?):(=?.+)$/, 'im'
        instanceRegex = RegExp /^\s*Global|Local\s+(\w+):.*New\s\b(\w+)\b.*$/, 'im'
        methodRegex = RegExp /^\s*Method(.*)\((.*)\)$/, 'im'
        functionRegex = RegExp /^\s*Function(.*):?(.*)?\((.*)\)$/, 'im'
        namespaceRegex = RegExp /^\s*Namespace\s*(.*)$/, 'im'
        propertyRegex = RegExp /^\s*Property\s*(.*):(.*)\(\)$/, 'im'
        classRegex = RegExp /^\s*Class\s+\b(\w+)\b.*$/, 'im'
        commentRegex = RegExp /\s*#rem monkeydoc(.*)/, 'im'

        inPrivate = false # when the parser hits a private declaration, it will skip everything until it hits a public again
        inClass = ""; # when inside a class definition, store the class here
        inNamespace = ""; # where the heck are we anyways?
        nextComment = ""; # when a monkeydoc comment is found, store it here; tack it on to the next thing that is found

        rl = readline.createInterface({
            input: fs.createReadStream(filePath)
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
                    #console.log ("in namespace: " + inNamespace)
                    return;

            # check for public/private
            if inPrivate
                checkPublic = publicRegex.exec(line)
                if checkPublic != null
                    #console.log "back in public"
                    inPrivate = false
                    return;

            checkPrivate = privateRegex.exec(line)
            if checkPrivate != null
                #console.log "inside private declaration"
                inPrivate = true
                return;


            # ok, if we're not in private, lets check first for a comment
            if not inPrivate

                if nextComment == ''
                    checkComment = commentRegex.exec(line)
                    if checkComment != null
                        nextComment = checkComment[1].trim()
                        return

                checkInstance = instanceRegex.exec(line)
                if checkInstance != null
                    console.log("Found instance")
                    console.log(checkInstance)
                    instanceName = checkInstance[1].trim()
                    instanceType = checkInstance[2].trim()
                    suggestion =
                        type: 'variable'
                        description: ''
                        rightLabel: instanceType
                        text: instanceName

                    if nextComment != ''
                        suggestion.description = nextComment
                        nextComment = ''
                    if suggestion.description.search('@hidden') == -1
                        @suggestions.instances.push(suggestion)

                    return
                ###
                checkVariable = variableRegex.exec(line)
                if checkVariable != null

                    variableName = checkVariable[1].trim()
                    variableType = checkVariable[2].trim()
                    indexOfNew = variableType.indexOf('New')
                    if indexOfNew == -1
                        indexOfNew = variableType.indexOf('new')



                    if variableType.charAt(0) == '='
                        variableType = variableType.slice(1)
                    console.log variableName
                    console.log variableType

                    suggestion =
                        type: 'variable'
                        description: ''
                        rightLabel: variableType
                        text: variableName

                    if nextComment != ''
                        suggestion.description = nextComment
                        nextComment = ''
                    if suggestion.description.search('@hidden') == -1
                        @suggestions.variables.push(suggestion)

                    return
                ###
                checkFunction = functionRegex.exec(line)
                if checkFunction != null
                    console.log("Found function", checkFunction)
                    functionName = checkFunction[1].trim()
                    functionParams = checkFunction[2].trim().split(',')
                    functionSnippet = ''

                    suggestion =
                        type:'function'
                        description: ''

                    if functionParams.length > 0
                        functionSnippet = functionName + "("
                        for param, index in functionParams
                            # console.log index, param
                            if param != ''
                                functionSnippet += "${"+(index+1)+":"+param+"}"
                            if index < functionParams.length-1
                                functionSnippet += ","
                            else
                                functionSnippet += ")$"+(index+2)
                    else
                        functionSnippet = functionName + "()"

                    suggestion.snippet = functionSnippet

                    if nextComment != ''
                        suggestion.description = nextComment
                        nextComment = ''
                    if suggestion.description.search('@hidden') == -1
                        @suggestions.functions.push(suggestion)
                    return


                checkClass = classRegex.exec(line)
                if checkClass != null
                    inClass = checkClass[1].trim()
                    console.log("found class", checkClass)
                    # don't store this; wait for a constructor
                    return

                checkMethod = methodRegex.exec(line)
                if checkMethod != null
                    console.log("found method", checkMethod)
                    methodName = checkMethod[1].trim()
                    methodParams = checkMethod[2].trim().split(',')
                    methodSnippet = ""
                    suggestion =
                        description: ''
                        inClass: inClass

                    if methodName == 'New'
                        suggestion.type = 'class'
                        suggestion.displayText = inClass
                    else
                        suggestion.type = 'method'

                    if methodParams.length > 0
                        if suggestion.type == 'class'
                            methodSnippet = inClass + "("
                        else
                            methodSnippet = methodName + "("
                        for param, index in methodParams
                            # console.log index, param
                            if param != ''
                                methodSnippet += "${"+(index+1)+":"+param+"}"
                            if index < methodParams.length-1
                                methodSnippet += ","
                            else
                                methodSnippet += ")$" + (index+2)

                    if methodSnippet != ''
                        suggestion.snippet = methodSnippet
                    else
                        suggestion.text = methodName

                    if nextComment != ''
                        suggestion.description = nextComment
                        nextComment = ''
                    if suggestion.description.search('@hidden') == -1
                        if methodName == 'New'
                            @suggestions.classes.push(suggestion)
                        else
                            @suggestions.methods.push(suggestion)
                    return

                checkField = fieldRegex.exec(line)
                if checkField != null
                    console.log("Found field", checkField)
                    fieldName = checkField[1].trim()
                    fieldType = checkField[2].trim()
                    suggestion =
                        type: 'property'
                        inClass: inClass
                        description: ''
                        rightLabel: fieldType
                        text: fieldName

                    if nextComment != ''
                        suggestion.description = nextComment
                        nextComment = ''
                    if suggestion.description.search('@hidden') == -1
                        @suggestions.properties.push(suggestion)
                    return

                checkProperty = propertyRegex.exec(line)
                if checkProperty != null
                    console.log("found property", checkProperty)
                    propertyName = checkProperty[1]
                    propertyType = checkProperty[2]
                    suggestion =
                        text: propertyName
                        type: 'property'
                        rightLabel: propertyType
                        description: ''
                        inClass: inClass
                    if nextComment != ''
                        suggestion.description = nextComment
                        nextComment = ''
                    if suggestion.description.search('@hidden') == -1
                        @suggestions.properties.push(suggestion)



    # Required: Return a promise, an array of suggestions, or null.
    getSuggestions: ({editor, bufferPosition, scopeDescriptor, prefix, activatedManually}) ->
        # console.log @suggestions
        # console.log prefix, scopeDescriptor, bufferPosition, editor

        # if the first character of the prefix is a number, get out of here
        if /^\d/.test(prefix.charAt(0))
            return

        fullPrefix = editor.getTextInBufferRange( [[bufferPosition.row, 0], [bufferPosition.row, bufferPosition.column]]).trim()
        shortlist = []
        isInstance = fullPrefix.search(/\./)
        inParams = fullPrefix.search(/\(/)
        isAssignment = fullPrefix.search("=")
        isConstructor = fullPrefix.toLowerCase().search("new")

        for own type, list of @suggestions

            if (isInstance >= 0 and (type == 'methods' or type == 'properties') and inParams == -1)

                # lets find the type of this instance
                segments = fullPrefix.split('.')
                segments.pop() # we don't need the last element; it's already in the prefix variable
                instanceName = segments.pop() # this is the first bit before the period. This should be the instance name
                instanceType = ''
                for instanceSuggestion in @suggestions.instances
                    if instanceName == instanceSuggestion.text
                        instanceType = instanceSuggestion.rightLabel
                        break

                if instanceType != ''
                    for suggestion in list
                        if @checkSuggestion(suggestion, prefix, instanceType)
                            if prefix != '.'
                                suggestion.replacementPrefix = prefix
                            else
                                suggestion.replacementPrefix = ''
                            shortlist.push(suggestion)

            else if (isConstructor >= 0 and type == 'classes' and inParams == -1)
                for suggestion in list
                    if @checkSuggestion(suggestion, prefix)
                        if prefix != '' and prefix != ' '
                            suggestion.replacementPrefix = prefix
                        shortlist.push(suggestion)

            else if (isInstance == -1 and (type == 'functions' or type == 'variables') and inParams == -1)
                for suggestion in list
                    if @checkSuggestion(suggestion, prefix)
                        if prefix != '' and prefix != ' '
                            suggestion.replacementPrefix = prefix
                        shortlist.push(suggestion)

        new Promise (resolve) ->
            resolve(shortlist)

    checkSuggestion: (suggestion, prefix, instanceType) ->
        if prefix == ''
            return true

        if instanceType != undefined and instanceType != ''
            if suggestion.inClass != instanceType
                return false

        if (suggestion.hasOwnProperty('snippet') and suggestion.snippet != '')
            if suggestion.snippet.toLowerCase().search(prefix.toLowerCase()) >= 0
                return true
        else if (suggestion.hasOwnProperty('text') and suggestion.text != '')
            if suggestion.text.search(prefix) >= 0
                return true
        return false
