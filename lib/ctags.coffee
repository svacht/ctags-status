{BufferedProcess} = require 'atom'
Q = require 'q'

module.exports =
class Ctags
    constructor: ->
        # TODO: Adopt Least-recently-used Cache
        @cache = {}

    parseTags: (lines) ->
        parse = (line) ->
            line = line.trim()
            if line == ''
                return []

            parts = line.split '\t'
            [tag, path, snippet, type, lineno] = parts
            lineno = lineno.replace 'line:', ''
            lineno = parseInt lineno, 10

            [tag, type, lineno]

        tags = (parse line for line in lines.split '\n')
        (tag for tag in tags when tag.length > 0)

    generateTags: (path) ->
        presets = require.resolve('./.ctagsrc')

        command = 'ctags'

        args = []
        args.push("--options=#{presets}", '--fields=+KSn', '--excmd=p')
        args.push('-R', '-f', '-', path)

        stdout = (lines) =>
            sorter = (x, y) ->
                [xtag, xtype, xlineno] = x
                [ytag, ytype, ylineno] = y
                return xlineno > ylineno  # Sort lineno by asc order

            tags = this.parseTags lines
            tags.sort(sorter)

            @cache[path] = tags
            @deferred.resolve()

        stderr = (lines) =>
            console.warn lines
            @deferred.reject()

        subprocess = new BufferedProcess({command, args, stdout, stderr})

    getTags: (path, consumer) ->
        @deferred = Q.defer([path])

        @deferred.promise.then =>
            tags = @cache[path]
            consumer tags

        if not @cache[path]?
            @generateTags path
        else
            @deferred.resolve()
