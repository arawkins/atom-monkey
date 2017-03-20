
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
    constants:[]
    properties: []
    hidden: false
    private :false

    constructor: (name) ->
        @name = name
        @functions = []
        @methods = []
        @globals = []
        @fields = []
        @properties = []
        @constants = []
        @hidden = false
        @private = false

    getConstructorSnippet: () ->
        snippet = ""
        constructorMethod = @methods[0] # The constructor (New) method should be in the 0 position
        if constructorMethod != null and constructorMethod != undefined and constructorMethod.name.toLowerCase() == 'new'
            if constructorMethod.parameters.length > 0
                snippet = @name + "("
                for param, index in constructorMethod.parameters
                    if param != ''
                        snippet += "${"+(index+1)+":"+param+"}"
                    if index < constructorMethod.parameters.length-1
                        snippet += ","
                    else
                        snippet += ")$" + (index+2)
            else
                snippet = @name + "()"
        else
            snippet = @name
        return snippet

class MonkeyFunction

    fileName: ''
    parameters: []
    returnType: ''
    description: ''
    hidden: false
    isConstructor: false
    private: false

    constructor: (name) ->
        @name = name
        @parameters = []
        @returnType = 'Void'
        @hidden = false
        @private = false

    getSnippet: () ->
        functionSnippet = ''
        if @parameters.length > 0
            functionSnippet = @name + "("
            for param, index in @parameters
                # console.log index, param
                if param != ''
                    functionSnippet += "${"+(index+1)+":"+param+"}"
                if index < @parameters.length-1
                    functionSnippet += ","
                else
                    functionSnippet += ")$"+(index+2)
        else
            functionSnippet = @name + "()"
        functionSnippet.description = @description

        return functionSnippet

class MonkeyVariable

    fileName: ''
    type: ''
    description: ''
    hidden: false
    private: false

    # sometimes we need to come back to variables and figure out their type
    # later, since it can depend on the parsing of other stuff (ie. method return values)
    # setting typeNeedsParsing to true will mark the variable to be checked again after
    # the initial parsing
    typeNeedsParsing = false

    constructor: (name, type) ->
        @name = name
        @type = type
        @hidden = false
        @private= false

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

    parsedFiles: []

    buildSuggestions: ->
        mPath = atom.config.get "language-monkey2.monkey2Path"
        modsPath = path.join(mPath,'/modules')

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


        dir.files(path.join(modsPath, '/'), (err, files) =>
            if (err)
                console.log err
                return
            files = files.filter((file) ->
               return /.monkey2$/.test(file)
            )

            for file in files
                @parseFile(file)


        )

    parseFile: (filePath) ->

        #fileData gets filled in with all of the data, then returned
        fileData =
            filePath: filePath
            classes: []
            functions: []
            globals: []
            structs: []
            constants: []
            interfaces: []
            variables: []

        #console.log("parsing " + filePath)

        classRegex = RegExp /^\s*Class\s+(\b[\w<>]+\b)(\s+Extends\s+(\b\w+\b))?.*$/, 'im'
        structRegex = RegExp /^\s*Struct\s+\b([\w<>]+)\b.*$/, 'im'
        statementRegex = RegExp /^\s*(For|Select|While).*$/, 'im'
        ifRegex = RegExp /^\s*\bIf\b\s+.*$/, 'im'
        ifThenRegex = RegExp /^\s*\bIf\b\s+.*\bThen\b.*$/, 'im'
        methodRegex = RegExp /^\s*Method\s+(\w+)(:.+)?\s*\((.*)\).*$/, 'im'
        functionRegex = RegExp /^\s*Function\s+(\w+)(:.+)?\s*\((.*)\).*$/, 'im'
        fieldRegex = RegExp /^\s*Field\s+(\w+?):([\w\[\]]+\b).*$/, 'im'
        globalRegex = RegExp /^\s*Global\s+(\w+?):([\w\[\]]+\b).*$/, 'im'
        constRegex = RegExp /^\s*Const\s+(\w+?):([\w\[\]]+\b).*$/, 'im'
        propertyRegex = RegExp /^\s*Property\s+(.+):(.+)\(\).*$/, 'im'
        commentRegex = RegExp /^\s*#rem monkeydoc(.*)/, 'im'
        lambdaRegex = RegExp /Lambda/, 'im'
        enumRegex = RegExp /Enum/, 'im'
        operatorRegex = RegExp /Operator.*$/,'im'
        interfaceRegex = RegExp /^\s*Interface\s+(.*)/, 'im'
        endRegex = RegExp /^\s*((w?end(if)?)|Next)\s*$/, 'im'
        privateRegex = RegExp /^\s*Private\s*$/,'im'
        publicRegex = RegExp /^\s*Public\s*$/,'im'
        externRegex = RegExp /^\s*Extern\s*$/,'im'
        variableRegex = RegExp /^\s*(Global|Local)\s+(\w+):(=|\w+)\s+(.*)$/, 'im'
        instanceRegex = RegExp /^\s*(Global|Local)\s+(\w+):(=|\w+)\s?New\s\b(\w+)\b.*$/, 'im'
        namespaceRegex = RegExp /^\s*Namespace\s*(.*)$/, 'im'

        tabRegex = RegExp /^(\s*)\w+.*$/, 'im'


        inPrivate = false # when the parser hits a private declaration, it will skip everything until it hits a public again
        privateIndent = -1
        inExtern = false # like inPrivate, ignore everything while in an extern
        inClass = ""; # when inside a class definition, store the class here
        lastLineWasIf = false


        scope = [] # tracks what scope we are inside of (class, if statement, method, etc.).
        inNamespace = ""; # where the heck are we anyways?
        previousIndent = -1;
        currentIndent = -1;

        nextComment = ""; # when a monkeydoc comment is found, store it here; tack it on to the next thing that is found

        rl = readline.createInterface({
            input: fs.createReadStream(filePath)
        })

        rl.on 'line', (line) =>

            # checkTabs is used to help detect one line if statements
            # if we are following an if statement, and the tab spacing hasn't changed,
            # we're going to assume the if statement was a one liner
            checkTabs = tabRegex.exec(line)
            if checkTabs != null
                previousIndent = currentIndent
                currentIndent = checkTabs[1].length
                if lastLineWasIf and previousIndent == currentIndent
                    #console.log("one line if statement, detected by tabspace")
                    #console.log(line)
                    scope.pop()

            lastLineWasIf = false

            # let's look for namespace first, since it should be first
            if inNamespace == ''
                checkNamespace = namespaceRegex.exec(line)
                if checkNamespace != null
                    inNamespace = checkNamespace[1].trim()
                    #console.log ("in namespace: " + inNamespace)
                    return;

            checkExtern = externRegex.exec(line)
            if checkExtern != null
                inExtern = true
                return

            # check for public/private
            if inPrivate or inExtern
                checkPublic = publicRegex.exec(line)
                if checkPublic != null
                    #console.log "back in public"
                    inPrivate = false
                    inExtern = false
                    return;

            checkPrivate = privateRegex.exec(line)
            if checkPrivate != null
                #console.log "inside private declaration"
                inPrivate = true
                inExtern = false
                privateIndent = currentIndent
                #console.log("entering private at indent " + privateIndent)
                return;


            # ok, if we're not in private, lets check first for a comment
            if not inExtern

                checkComment = commentRegex.exec(line)
                if checkComment != null
                    #console.log "Found monkeydoc comment"
                    #console.log checkComment
                    nextComment = checkComment[1].trim()
                    return

                checkInstance = instanceRegex.exec(line)
                if checkInstance != null

                    instanceName = checkInstance[2].trim()
                    instanceType = checkInstance[4].trim()
                    thisInstance = new MonkeyVariable(instanceName, instanceType)
                    thisInstance.fileName = filePath
                    thisInstance.private = inPrivate

                    if nextComment != ''
                        thisInstance.description = nextComment
                        nextComment = ''
                    if thisInstance.description.search('@hidden') == -1
                        fileData.variables.push(thisInstance)

                    return

                checkVariable = variableRegex.exec(line)
                if checkVariable != null
                    #console.log "found variable"
                    #console.log checkVariable
                    parseLater = false
                    variableName = checkVariable[2].trim()
                    if checkVariable[3] != '='
                        variableType = checkVariable[3].trim()
                    else
                        variableType = checkVariable[4].trim()
                        parseLater = true
                    thisVariable = new MonkeyVariable(variableName, variableType)
                    thisVariable.typeNeedsParsing = parseLater
                    thisVariable.fileName = filePath
                    thisVariable.private = inPrivate

                    if nextComment != ''
                        thisVariable.description = nextComment
                        nextComment = ''
                    if thisVariable.description.search('@hidden') == -1
                        fileData.variables.push(thisVariable)
                        #console.log(thisVariable)

                    return

                checkLambda = lambdaRegex.exec(line)
                if checkLambda != null
                    #console.log "Found lambda"
                    #console.log checkLambda
                    scope.push("Lambda")
                    return

                checkEnum = enumRegex.exec(line)
                if checkEnum != null
                    scope.push("Enum")
                    return

                checkOperator = operatorRegex.exec(line)
                if checkOperator != null
                    #console.log "Found operator"
                    #console.log checkOperator
                    scope.push("Operator")
                    return

                checkInterface = interfaceRegex.exec(line)
                if checkInterface != null
                    scope.push("Interface")
                    #console.log "Found interface"
                    #console.log checkInterface
                    thisInterface = new MonkeyClass(checkInterface[1])

                    if nextComment != ''
                        thisInterface.description = nextComment
                        nextComment = ''
                    if thisInterface.description.search("@hidden") != -1
                        thisInterface.hidden = true

                    scope.push(thisInterface)
                    fileData.interfaces.push(thisInterface)
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
                    thisClass.type= "Class"
                    thisClass.private = inPrivate
                    scope.push(thisClass)
                    fileData.classes.push(thisClass)
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
                    thisStruct.private = inPrivate
                    fileData.structs.push(thisStruct)
                    scope.push(thisStruct)

                checkField = fieldRegex.exec(line)
                if checkField != null
                    #console.log "found field in " + filePath
                    #console.log checkField
                    thisVar = new MonkeyVariable(checkField[1], checkField[2])
                    thisVar.fileName = filePath
                    thisVar.private = inPrivate

                    if nextComment != ''
                        thisVar.description = nextComment
                        nextComment = ''
                    if thisVar.description.search("@hidden") != -1
                        thisVar.hidden = true

                    parentClass = null
                    for scopeLevel in scope by -1
                        if scopeLevel instanceof MonkeyClass
                            parentClass = scopeLevel
                            break
                    if parentClass != null
                        parentClass.fields.push(thisVar)
                    else
                        console.log "Could not find class for field " + thisVar.name
                        console.log filePath
                        console.log line

                checkGlobal = globalRegex.exec(line)
                if checkGlobal != null
                    #console.log "found global in " + filePath
                    #console.log checkGlobal
                    thisVar = new MonkeyVariable(checkGlobal[1], checkGlobal[2])
                    thisVar.fileName = filePath
                    thisVar.private = inPrivate
                    if nextComment != ''
                        thisVar.description = nextComment
                        nextComment = ''
                    if thisVar.description.search("@hidden") != -1
                        thisVar.hidden = true

                    parentClass = null
                    for scopeLevel in scope by -1
                        if scopeLevel instanceof MonkeyClass
                            parentClass = scopeLevel
                            break
                    if parentClass != null
                        parentClass.globals.push(thisVar)
                    else
                        fileData.globals.push(thisVar)

                checkConst = constRegex.exec(line)
                if checkConst != null
                    #console.log "found const in " + filePath
                    #console.log checkConst
                    thisVar = new MonkeyVariable(checkConst[1], checkConst[2])
                    thisVar.fileName = filePath
                    thisVar.private = inPrivate
                    if nextComment != ''
                        thisVar.description = nextComment
                        nextComment = ''
                    if thisVar.description.search("@hidden") != -1
                        thisVar.hidden = true

                    parentClass = null
                    for scopeLevel in scope by -1
                        if scopeLevel instanceof MonkeyClass
                            parentClass = scopeLevel
                            break
                    if parentClass != null
                        parentClass.constants.push(thisVar)
                    else
                        fileData.constants.push(thisVar)

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
                    thisFunction.private = inPrivate
                    parentClass = null
                    for scopeLevel in scope by -1
                        if scopeLevel instanceof MonkeyClass
                            parentClass = scopeLevel
                            break
                    if parentClass != null
                        parentClass.functions.push(thisFunction)
                    else
                        fileData.functions.push(thisFunction)

                    scope.push(thisFunction)
                    return

                checkMethod = methodRegex.exec(line)
                if checkMethod != null
                    #console.log "Found method"
                    #console.log checkMethod
                    thisMethod = new MonkeyFunction(checkMethod[1].trim())
                    thisMethod.private = inPrivate
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
                            thisMethod.isConstructor = true
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
                    thisProperty.private = inPrivate
                    if nextComment != ''
                        thisProperty.description = nextComment
                        nextComment = ''
                        if thisProperty.description.search("@hidden") != -1
                            thisProperty.hidden = true

                    parentClass = null
                    for scopeLevel in scope by -1
                        if scopeLevel instanceof MonkeyClass
                            parentClass = scopeLevel
                            break
                    if parentClass != null
                        parentClass.properties.push(thisProperty)
                    else
                        console.log("Could not find a class for property " + thisProperty.name)
                        #console.log scope
                        #console.log filePath
                    scope.push(thisProperty)
                    return

                checkIfThen = ifThenRegex.exec(line)
                if checkIfThen != null
                    #console.log("hit an if then, do nothing!")
                    return

                if checkIf = ifRegex.exec(line)
                    if checkIf != null
                        scope.push("if")
                        lastLineWasIf = true
                        return


                checkStatement = statementRegex.exec(line)
                if checkStatement != null

                    #console.log "found statement"
                    #console.log checkStatement
                    scope.push("statement")
                    return

                checkEnd = endRegex.exec(line)
                if checkEnd != null

                    #console.log checkEnd

                    lastScope = scope.pop()
                    #console.log("ending scope at " + currentIndent)
                    #console.log privateIndent
                    if inPrivate and privateIndent > currentIndent
                        inPrivate = false
                        privateIndent = -1
                        #console.log("ending private at indent " + privateIndent)
                    return

        #console.log("finished", fileData)
        #if this file has already been parsed, replace it's existing data
        for existingFileData, index in @parsedFiles
            if existingFileData.filePath == filePath
                #console.log(index)
                #console.log("updating autocomplete data for " + filePath)
                #console.log fileData
                @parsedFiles[index] = fileData
                return

        #otherwise, it's new data, so add it to the parsedfiles array
        @parsedFiles.push(fileData)


    reParseVariables: () ->
        #console.log("reparse all of the broken variables")

        ### TODO parse variables again to lookup types
        for fileData in @parsedFiles
            for variable in fileData.variables
                if variable.typeNeedsParsing
                    console.log(variable.name + ":"+variable.type)
        ###

    # Required: Return a promise, an array of suggestions, or null.
    getSuggestions: ({editor, bufferPosition, scopeDescriptor, prefix, activatedManually}) ->
        # console.log @suggestions
        # console.log prefix, scopeDescriptor, bufferPosition, editor
        # console.log scopeDescriptor
        # if the first character of the prefix is a number, get out of here
        if /^\d/.test(prefix.charAt(0))
            return

        fullPrefix = editor.getTextInBufferRange( [[bufferPosition.row, 0], [bufferPosition.row, bufferPosition.column]]).trim()

        # if there is an open bracket in the prefix, this is likely a method, so don't do autocompletion
        if /\(/.test(fullPrefix)
            return

        shortlist = []
        instanceRegex = RegExp /^\s*(\w+)(\.[\w\.])?\s*$/, 'i'
        isAssignment = fullPrefix.search("=")
        isConstructor = fullPrefix.toLowerCase().search("new")


        for fileData in @parsedFiles

            # If the word 'new' is in the prefix, search for class constructors
            if fullPrefix.toLowerCase().search("new") >=0
                for c in fileData.classes
                    if not c.private and not c.hidden and c.name.toLowerCase().search(prefix.toLowerCase()) == 0
                        suggestion =
                            snippet: c.getConstructorSnippet()
                            type: 'class'
                            description: c.description
                        shortlist.push(suggestion)

            # If there is a period in the full prefix, see if it is a class name
            else if fullPrefix.search(/\./) >= 0
                #First break the line apart by white space to try to find the furthest line segment with a period in it
                segments = fullPrefix.split(' ')
                segToUse = null
                for seg in segments by -1
                    if seg.search(/\./) >= 0
                        segToUse = seg
                        break

                if segToUse != null
                    segments = segToUse.split('.')
                    #console.log(segments)
                    segments.pop() # we don't need the last element; it's already in the prefix variable
                    previousPrefix = segments.pop() # this is the first bit before the period. This should be the instance name
                    instanceType=null
                    for variable in fileData.variables
                        if variable.name == previousPrefix
                            instanceType = variable.type
                            # console.log "found instance of type: " + instanceType
                            # TODO Nested loop to look through all other files for class data for instance type. ug.
                            for fileData2 in @parsedFiles
                                for c2 in fileData2.classes
                                    if instanceType.toLowerCase() == c2.name.toLowerCase()
                                        for cm in c2.methods
                                            if not cm.private and not cm.hidden and !cm.isConstructor and cm.name.toLowerCase().search(prefix.toLowerCase()) >= 0
                                                suggestion =
                                                    snippet: cm.getSnippet()
                                                    type: 'method'
                                                    description: cm.description
                                                    leftLabel: cm.returnType
                                                shortlist.push(suggestion)
                                        for cp in c2.properties
                                            if not cp.private and not cp.hidden and cp.name.toLowerCase().search(prefix.toLowerCase()) >= 0
                                                suggestion =
                                                    text: cp.name
                                                    type: 'property'
                                                    description: cp.description
                                                    leftLabel: cp.type
                                                shortlist.push(suggestion)
                                        for cf in c2.fields
                                            if not cf.private and not cf.hidden and cf.name.toLowerCase().search(prefix.toLowerCase()) >= 0
                                                suggestion =
                                                    text: cf.name
                                                    type: 'property'
                                                    description: cf.description
                                                    leftLabel: cf.type
                                                shortlist.push(suggestion)


                    for c in fileData.classes

                        if c.name == previousPrefix
                            for cf in c.functions
                                if not cf.private and not cf.hidden and cf.name.toLowerCase().search(prefix.toLowerCase()) >= 0
                                    suggestion =
                                        snippet: cf.getSnippet()
                                        type: 'function'
                                        description: cf.description
                                        leftLabel: cf.returnType
                                    shortlist.push(suggestion)
                            for cConst in c.constants
                                if not cConst.private and not cConst.hidden cConst.name.toLowerCase().search(prefix.toLowerCase()) >= 0
                                    suggestion =
                                        text: cConst.name
                                        type: 'constant'
                                        description: cConst.description
                                        leftLabel: cConst.type
                                    shortlist.push(suggestion)
                            for cGlobal in c.globals
                                if not cGlobal.private and not cGlobal.hidden and cGlobal.name.toLowerCase().search(prefix.toLowerCase()) >= 0
                                    suggestion =
                                        text: cGlobal.name
                                        type: 'variable'
                                        description: cGlobal.description
                                        leftLabel: cGlobal.type
                                    shortlist.push(suggestion)
            else
                for f in fileData.functions
                    if not f.private and not f.hidden and f.name.toLowerCase().search(prefix.toLowerCase()) == 0
                        suggestion =
                            snippet: f.getSnippet()
                            type : 'function'
                            description: f.description
                            leftLabel: f.returnType
                        shortlist.push(suggestion)
                for c in fileData.classes
                    if not c.private and not c.hidden and c.name.toLowerCase().search(prefix.toLowerCase()) == 0
                        suggestion =
                            text: c.name
                            type: 'class'
                            description: c.description
                        shortlist.push(suggestion)

        new Promise (resolve) ->
            resolve(shortlist)
