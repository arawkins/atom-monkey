
fs = require 'fs'
path = require 'path'
readline = require 'readline'
dir = require 'node-dir'
execFile = require('child_process').execFile

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
    fileDataCache: {}

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
                continue
        )

    parseFile: (filePath) ->
        execFile "/home/arawkins/.local/share/monkey2/bin/mx2cc_linux",
            ['makeapp', '-parse', '-geninfo', filePath],
            {
                maxBuffer: 2000 * 1024
            },
            (error, stdout, stderr) =>

                message = stdout.toString()
                #console.log(message)
                if /.*Build\serror.*/.test(message)
                    return
                else
                    message = message.split('\n');
                    message = message.splice(6);
                    message.pop()
                    message = message.join('\n');
                    if message != ''
                        fileData = JSON.parse(message)
                        fileData.path = filePath
                        for file, i in @parsedFiles
                            if file.ident == fileData.ident
                                @parsedFiles[i] = fileData
                                return

                        @parsedFiles.push(fileData)


    reParseVariables: () ->
        return


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

        if fullPrefix.toLowerCase().search("new") >=0
            for file in @parsedFiles
                if file.members != undefined
                    for member in file.members
                        if member.kind == "class" and member.members != undefined
                            for classMember in member.members
                                if classMember.kind == "method" and classMember.ident == "new"
                                    if member.ident.toLowerCase().search(prefix.toLowerCase()) == 0
                                        suggestion =
                                            snippet: @buildConstructorSnippet(member.ident, classMember)
                                            type: 'class'
                                        shortlist.push(suggestion)
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

                for file in @parsedFiles
                    if file.members != undefined
                        for member in file.members
                            if (member.kind == 'const' or member.kind == 'global') and member.ident == previousPrefix
                                instanceType = member.type.ident
                                break
                            else if member.kind == 'class' and member.members != undefined
                                for classMember in member.members
                                    if (classMember.kind == 'field' or classMember.kind == 'property') and classMember.ident == previousPrefix
                                        if classMember.kind == 'property'
                                            instanceType = classMember.getFunc.type.retType.ident
                                        else
                                            instanceType = classMember.type.ident
                                        break


                if instanceType != null
                    for file in @parsedFiles
                        if file.members != undefined
                            for member in file.members
                                if member.kind == 'class' and member.ident == instanceType
                                    if member.members != undefined
                                        for classMember in member.members
                                            if classMember.ident != 'new' and classMember.ident.toLowerCase().search(prefix.toLowerCase()) >= 0
                                                suggestion = @getSuggestion(classMember, member.ident)
                                                if suggestion != null
                                                    shortlist.push(suggestion)


                else
                    for file in @parsedFiles
                        if file.members != undefined
                            for member in file.members
                                if member.kind == 'class' and member.ident == previousPrefix
                                    if member.members != undefined
                                        for classMember in member.members
                                            if classMember.kind == 'function' or classMember.kind == 'global' or classMember.kind == 'const'
                                                suggestion = @getSuggestion(classMember, member.ident)
                                                if suggestion != null
                                                    shortlist.push(suggestion)



        ###
        for fileData in @parsedFiles

            # If the word 'new' is in the prefix, search for class constructors
            if fullPrefix.toLowerCase().search("new") >=0
                for c in fileData.classes
                    if c.name.toLowerCase().search(prefix.toLowerCase()) == 0
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
                                            if !cm.isConstructor and cm.name.toLowerCase().search(prefix.toLowerCase()) >= 0
                                                suggestion =
                                                    snippet: cm.getSnippet()
                                                    type: 'method'
                                                    description: cm.description
                                                    leftLabel: cm.returnType
                                                shortlist.push(suggestion)
                                        for cp in c2.properties
                                            if cp.name.toLowerCase().search(prefix.toLowerCase()) >= 0
                                                suggestion =
                                                    text: cp.name
                                                    type: 'property'
                                                    description: cp.description
                                                    leftLabel: cp.type
                                                shortlist.push(suggestion)
                                        for cf in c2.fields
                                            if cf.name.toLowerCase().search(prefix.toLowerCase()) >= 0
                                                suggestion =
                                                    text: cf.name
                                                    type: 'property'
                                                    description: cf.description
                                                    leftLabel: cf.type
                                                shortlist.push(suggestion)


                    for c in fileData.classes

                        if c.name == previousPrefix
                            for cf in c.functions
                                if cf.name.toLowerCase().search(prefix.toLowerCase()) >= 0
                                    suggestion =
                                        snippet: cf.getSnippet()
                                        type: 'function'
                                        description: cf.description
                                        leftLabel: cf.returnType
                                    shortlist.push(suggestion)
                            for cConst in c.constants
                                if cConst.name.toLowerCase().search(prefix.toLowerCase()) >= 0
                                    suggestion =
                                        text: cConst.name
                                        type: 'constant'
                                        description: cConst.description
                                        leftLabel: cConst.type
                                    shortlist.push(suggestion)
                            for cGlobal in c.globals
                                if cGlobal.name.toLowerCase().search(prefix.toLowerCase()) >= 0
                                    suggestion =
                                        text: cGlobal.name
                                        type: 'variable'
                                        description: cGlobal.description
                                        leftLabel: cGlobal.type
                                    shortlist.push(suggestion)
            else
                for f in fileData.functions
                    if not f.hidden and f.name.toLowerCase().search(prefix.toLowerCase()) == 0
                        suggestion =
                            snippet: f.getSnippet()
                            type : 'function'
                            description: f.description
                            leftLabel: f.returnType
                        shortlist.push(suggestion)
                for c in fileData.classes
                    if not c.hidden and c.name.toLowerCase().search(prefix.toLowerCase()) == 0
                        suggestion =
                            text: c.name
                            type: 'class'
                            description: c.description
                        shortlist.push(suggestion)
        ###
        new Promise (resolve) ->
            resolve(shortlist)

    getSuggestion: (parsedObject, className) ->
        suggestion = null

        switch parsedObject.kind
            when "field", "global", "const"
                suggestion =
                    text: parsedObject.ident
                    type: 'variable'
                if parsedObject.type != undefined
                    suggestion.leftLabel = parsedObject.type.ident
            when "property"
                suggestion =
                    text: parsedObject.ident
                    type: 'property'
                if parsedObject.getFunc == undefined
                    suggestion.rightLabel = "Write only"
                else if parsedObject.setFunc == undefined
                    suggestion.rightLabel = "Read only"
                propType = ""
                if parsedObject.getFunc != undefined
                    suggestion.leftLabel = parsedObject.getFunc.type.retType.ident
                else if parsedObject.setFunc != undefined
                    suggestion.leftLabel = parsedObject.setFunc.type.retType.ident

            when "method"
                if parsedObject.ident == "new" and className != undefined
                    suggestion =
                        snippet: @buildConstructorSnippet(className, parsedObject)
                        type: 'method'
                        leftLabel: parsedObject.type.retType.ident
                else
                    suggestion =
                        snippet: @buildSnippet(parsedObject)
                        type: 'method'
                        leftLabel: parsedObject.type.retType.ident

            when "function"
                suggestion =
                    snippet: @buildSnippet(parsedObject)
                    type: 'function'
                    leftLabel: parsedObject.type.retType.ident



        return suggestion


    buildSnippet: (parsedObject) ->
        snippet = ""

        if parsedObject != null and parsedObject != undefined
            if (parsedObject.kind == "method" or parsedObject.kind == "function") and parsedObject.type.params != undefined and parsedObject.type.params.length > 0
                snippet = parsedObject.ident + "("
                for paramObject, index in parsedObject.type.params
                    snippet += "${"+(index+1)+":"+paramObject.ident+":"+paramObject.type.ident+"}"
                    if index < parsedObject.type.params.length-1
                        snippet += ","
                    else
                        snippet += ")$" + (index+2)
            else
                snippet = parsedObject.ident + "()"

        return snippet

    buildConstructorSnippet : (className, methodObject) ->
        snippet = className + "("

        if methodObject != null and methodObject != undefined and methodObject.ident.toLowerCase() == 'new'

            if methodObject.type.params != undefined and methodObject.type.params.length > 0
                for paramObject, index in methodObject.type.params
                    snippet += "${"+(index+1)+":"+paramObject.ident+":"+paramObject.type.ident+"}"
                    if index < methodObject.type.params.length-1
                        snippet += ","
                    else
                        snippet += ")$" + (index+2)
            else
                snippet = methodObject.ident + "()"

            ###
            if methodObject.parameters.length > 0
                snippet = @name + "("
                for param, index in methodObject.parameters
                    if param != ''
                        snippet += "${"+(index+1)+":"+param+"}"
                    if index < constructorMethod.parameters.length-1
                        snippet += ","
                    else
                        snippet += ")$" + (index+2)
            else
                snippet = @name + "()"
        ###
        else
            snippet = @name


        return snippet
