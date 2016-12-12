
fs = require 'fs'
path = require 'path'
readline = require 'readline'
dir = require 'node-dir'

class MonkeyClass

    fileName: ''
    extends: 'none'
    functions: []
    globals: []
    methods: []
    fields: []

    constructor: (name) ->
        @name = name
        @functions = []

class MonkeyFunction

    fileName: ''
    parameters: []
    returnType: ''

    constructor: (@name) ->



class MonkeyVariable

    fileName: ''
    type: ''

    constructor: (@name, @type) ->

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


    buildSuggestions: ->
        console.log("building suggestions...")
        mPath = atom.config.get "language-monkey2.monkey2Path"
        modsPath = path.join(mPath,'/modules/')
        console.log("module path is:" + modsPath);
        # lets try reading the canvas module for kicks
        #canvasModPath = path.join(modsPath, "/mojo/graphics/canvas.monkey2")
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

        ###
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
        ###
        #@parseFile(path.join(modsPath, 'mojo/graphics/canvas.monkey2'))

    parseFile: (filePath) ->

        console.log("parsing " + filePath)

        classRegex = RegExp /^\s*Class\s+\b(\w+)\b(\s+Extends\s+(\b\w+\b))?\s*$/, 'im'
        statementRegex = RegExp /^\s*(If|For|Select|While).*$/, 'im'
        methodRegex = RegExp /^\s*Method\s+(\w+)(:\w+)?\s*\((.*)\).*$/, 'im'
        functionRegex = RegExp /^\s*Function\s+(\w+)(:\w+)?\s*\((.*)\).*$/, 'im'
        endRegex = RegExp /^\s*(w?end(if)?)|Next\s*$/, 'im'

        privateRegex = RegExp /^\s*Private\s*$/,'im'
        publicRegex = RegExp /^\s*Public\s*$/,'im'
        globalRegex = RegExp /^\s*Global\s+\b(\w+?):(\w+?)\b/, 'im'
        fieldRegex = RegExp /^\s*Field\s+\b(\w+?):(\w+?)\b/, 'im'
        variableRegex = RegExp /^\s*Global|Local\s+\b(\w+?):(=?.+)$/, 'im'
        instanceRegex = RegExp /^\s*Global|Local\s+(\w+):.*New\s\b(\w+)\b.*$/, 'im'

        namespaceRegex = RegExp /^\s*Namespace\s*(.*)$/, 'im'
        propertyRegex = RegExp /^\s*Property\s*(.*):(.*)\(\)$/, 'im'

        commentRegex = RegExp /\s*#rem monkeydoc(.*)/, 'im'

        inPrivate = false # when the parser hits a private declaration, it will skip everything until it hits a public again
        inClass = ""; # when inside a class definition, store the class here
        scope = [] # tracks what scope we are inside of (class, if statement, method, etc.).
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

                checkClass = classRegex.exec(line)
                if checkClass != null
                    #console.log "Found class"
                    thisClassName = checkClass[1]
                    thisClassExtends = checkClass[3]
                    thisClass = new MonkeyClass(thisClassName)
                    thisClass.fileName = filePath

                    if thisClassExtends != undefined
                        thisClass.extends = thisClassExtends

                    scope.push(thisClass)
                    @classes.push(thisClass)

                checkFunction = functionRegex.exec(line)
                if checkFunction != null
                    #console.log "Found function"
                    #console.log checkFunction
                    thisFunctionName = checkFunction[1]
                    thisFunctionReturnType = checkFunction[2]
                    thisFunction = new MonkeyFunction(thisFunctionName)

                    if thisFunctionReturnType != undefined
                        thisFunction.returnType = thisFunctionReturnType.slice(1)

                    parentClass = null
                    for scopeLevel in scope by -1
                        if scopeLevel instanceof MonkeyClass
                            parentClass = scopeLevel
                            break
                    if parentClass != null
                        if thisFunction.name == 'new' or thisFunction.name == 'New'
                            parentClass.functions.unshift(thisFunction)
                        else
                            parentClass.functions.push(thisFunction)
                    else
                        @functions.push(thisFunction)

                    scope.push(thisFunction)

                checkMethod = methodRegex.exec(line)
                if checkMethod != null
                    #console.log "Found method"
                    #console.log checkMethod
                    scope.push("Method")

                checkStatement = statementRegex.exec(line)
                if checkStatement != null
                    #console.log "found statement"
                    #console.log checkStatement
                    scope.push("statement")

                checkEnd = endRegex.exec(line)
                if checkEnd != null
                    #console.log "Ending a scope"
                    #console.log checkEnd
                    scope.pop()



    # Required: Return a promise, an array of suggestions, or null.
    getSuggestions: ({editor, bufferPosition, scopeDescriptor, prefix, activatedManually}) ->
        # console.log @suggestions
        # console.log prefix, scopeDescriptor, bufferPosition, editor
        console.log @functions
        console.log @classes
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
