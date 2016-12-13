
fs = require 'fs'
path = require 'path'
readline = require 'readline'
dir = require 'node-dir'

class MonkeyClass

    fileName: ''
    description: ''
    extends: 'none'
    functions: []
    globals: []
    methods: []
    fields: []
    properties: []
    hidden: false

    constructor: (name) ->
        @name = name
        @functions = []
        @methods = []
        @globals = []
        @fields = []
        @properties = []
        @hidden = false

class MonkeyFunction

    fileName: ''
    parameters: []
    returnType: ''
    description: ''
    hidden: false

    constructor: (name) ->
        @name = name
        @parameters = []
        @returnType = 'Void'
        @hidden = false

class MonkeyVariable

    fileName: ''
    type: ''
    description: ''
    hidden: false

    constructor: (name, type) ->
        @name = name
        @type = type
        @hidden = false

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

    classes: []
    functions: []
    globals: []
    structs: []

    buildSuggestions: ->
        console.log("building suggestions...")
        mPath = atom.config.get "language-monkey2.monkey2Path"
        modsPath = path.join(mPath,'/modules/')
        console.log("module path is:" + modsPath);
        # lets try reading the canvas module for kicks
        canvasModPath = path.join(modsPath, "/mojo/graphics/test.monkey2")
        #@parseFile(canvasModPath)

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

        classRegex = RegExp /^\s*Class\s+\b(\w+)\b(\s+Extends\s+(\b\w+\b))?\s*$/, 'im'
        structRegex = RegExp /^\s*Struct\s+\b(\w+)\b\s*$/, 'im'
        statementRegex = RegExp /^\s*(If|For|Select|While).*$/, 'im'
        methodRegex = RegExp /^\s*Method\s+(\w+)(:.+)?\s*\((.*)\).*$/, 'im'
        functionRegex = RegExp /^\s*Function\s+(\w+)(:.+)?\s*\((.*)\).*$/, 'im'
        fieldRegex = RegExp /^\s*Field\s+(\w+?):([\w\[\]]+\b).*$/, 'im'
        propertyRegex = RegExp /^\s*Property\s+(.+):(.+)\(\).*$/, 'im'
        commentRegex = RegExp /^\s*#rem monkeydoc(.*)/, 'im'
        lambdaRegex = RegExp /Lambda/, 'im'
        endRegex = RegExp /^\s*((w?end(if)?)|Next)\s*$/, 'im'

        privateRegex = RegExp /^\s*Private\s*$/,'im'
        publicRegex = RegExp /^\s*Public\s*$/,'im'
        globalRegex = RegExp /^\s*Global\s+\b(\w+?):(.+)$/, 'im'
        variableRegex = RegExp /^\s*Global|Local\s+\b(\w+?):(=?.+)$/, 'im'
        instanceRegex = RegExp /^\s*Global|Local\s+(\w+):.*New\s\b(\w+)\b.*$/, 'im'

        namespaceRegex = RegExp /^\s*Namespace\s*(.*)$/, 'im'




        inPrivate = false # when the parser hits a private declaration, it will skip everything until it hits a public again
        inClass = ""; # when inside a class definition, store the class here
        scope = [] # tracks what scope we are inside of (class, if statement, method, etc.).
        inNamespace = ""; # where the heck are we anyways?

        nextComment = ""; # when a monkeydoc comment is found, store it here; tack it on to the next thing that is found

        rl = readline.createInterface({
            input: fs.createReadStream(filePath)
        })

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
                        #console.log "Found monkeydoc comment"
                        #console.log checkComment
                        nextComment = checkComment[1].trim()
                        return

                checkLambda = lambdaRegex.exec(line)
                if checkLambda != null
                    #console.log "Found lambda"
                    #console.log checkLambda
                    scope.push("Lambda")
                    return

                checkClass = classRegex.exec(line)
                if checkClass != null
                    #console.log "Found class"
                    thisClassName = checkClass[1]
                    thisClassExtends = checkClass[3]
                    thisClass = new MonkeyClass(thisClassName)
                    thisClass.fileName = filePath

                    if thisClassExtends != undefined
                        thisClass.extends = thisClassExtends

                    if nextComment != ''
                        thisClass.description = nextComment
                        nextComment = ''
                    if thisClass.description.search("@hidden") != -1
                        thisClass.hidden = true

                    scope.push(thisClass)
                    @classes.push(thisClass)
                    return

                checkStruct = structRegex.exec(line)
                if checkStruct != null
                    #console.log "Found struct"
                    #console.log checkStruct
                    thisStruct = new MonkeyClass(checkStruct[1])
                    thisStruct.fileName = filePath

                    if nextComment != ''
                        thisStruct.description = nextComment
                        nextComment = ''
                    if thisStruct.description.search("@hidden") != -1
                        thisStruct.hidden = true
                    @structs.push(thisStruct)
                    scope.push(thisStruct)

                checkField = fieldRegex.exec(line)
                if checkField != null
                    #console.log "found field in " + filePath
                    #console.log checkField
                    thisVar = new MonkeyVariable(checkField[1], checkField[2])

                    parentClass = null
                    for scopeLevel in scope by -1
                        if scopeLevel instanceof MonkeyClass
                            parentClass = scopeLevel
                            break
                    if parentClass != null
                        parentClass.fields.push(thisVar)
                    else
                        console.log "Could not find class for " + thisVar
                        console.log filePath

                checkFunction = functionRegex.exec(line)
                if checkFunction != null

                    #console.log "Found function"
                    #console.log checkFunction
                    thisFunction = new MonkeyFunction(checkFunction[1].trim())

                    if checkFunction[2] != undefined
                        thisFunction.returnType = checkFunction[2].trim()
                        # Remove the : from the start of the return type
                        if thisFunction.returnType.charAt(0) == ':'
                            thisFunction.returnType = thisFunction.returnType.slice(1)
                    else
                        thisFunction.returnType = "Void"

                    if checkFunction[3] != undefined and checkFunction[3] != ""
                        params = checkFunction[3].split(',')
                        for param in params
                            thisFunction.parameters.push(param.trim())

                    if nextComment != ''
                        thisFunction.description = nextComment
                        nextComment = ''
                        if thisFunction.description.search("@hidden") != -1
                            thisFunction.hidden = true

                    parentClass = null
                    for scopeLevel in scope by -1
                        if scopeLevel instanceof MonkeyClass
                            parentClass = scopeLevel
                            break
                    if parentClass != null
                        parentClass.functions.push(thisFunction)
                    else
                        @functions.push(thisFunction)

                    scope.push(thisFunction)
                    return

                checkMethod = methodRegex.exec(line)
                if checkMethod != null
                    #console.log "Found method"
                    #console.log checkMethod
                    thisMethod = new MonkeyFunction(checkMethod[1].trim())

                    if checkMethod[2] != undefined
                        thisMethod.returnType = checkMethod[2].trim()
                        if thisMethod.returnType.charAt(0) == ':'
                            thisMethod.returnType = thisMethod.returnType.slice(1)
                    else
                        thisMethod.returnType = "Void"

                    if checkMethod[3] != undefined and checkMethod[3] != ""
                        params = checkMethod[3].split(',')

                        for param in params
                            thisMethod.parameters.push(param.trim())

                    if nextComment != ''
                        thisMethod.description = nextComment
                        nextComment = ''
                        if thisMethod.description.search("@hidden") != -1
                            thisMethod.hidden = true

                    parentClass = null
                    for scopeLevel in scope by -1
                        if scopeLevel instanceof MonkeyClass
                            parentClass = scopeLevel
                            break
                    if parentClass != null
                        # If it's a constructor, put it at the front of the methods array
                        if thisMethod.name == 'new' or thisMethod.name == 'New'
                            parentClass.methods.unshift(thisMethod)
                        else
                            parentClass.methods.push(thisMethod)

                        scope.push(thisMethod)
                    else
                        console.log("Could not find a class for method " + thisMethod.name)
                        console.log scope
                        console.log filePath
                    return

                checkProperty = propertyRegex.exec(line)
                if checkProperty != null
                    #console.log "found property"
                    #console.log checkProperty

                    thisProperty = new MonkeyVariable(checkProperty[1], checkProperty[2])

                    if nextComment != ''
                        thisProperty.description = nextComment
                        nextComment = ''
                        if thisProperty.description.search("@hidden") != -1
                            thisProperty.hidden = true

                    parentClass = null
                    for scopeLevel in scope by -1
                        if scopeLevel instanceof MonkeyClass
                            parentClass = scopeLevel
                            parentClass.properties.push(thisProperty)
                            break

                    scope.push(thisProperty)
                    return

                checkStatement = statementRegex.exec(line)
                if checkStatement != null
                    #console.log "found statement"
                    #console.log checkStatement
                    scope.push("statement")
                    return

                checkEnd = endRegex.exec(line)
                if checkEnd != null
                    #console.log "Ending a scope"
                    #console.log checkEnd
                    scope.pop()
                    return



    # Required: Return a promise, an array of suggestions, or null.
    getSuggestions: ({editor, bufferPosition, scopeDescriptor, prefix, activatedManually}) ->
        # console.log @suggestions
        # console.log prefix, scopeDescriptor, bufferPosition, editor
        console.log @functions
        console.log @classes
        console.log @structs
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
