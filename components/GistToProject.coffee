noflo = require 'noflo'
octo = require 'octo'
path = require 'path'

exports.getComponent = ->
  c = new noflo.Component
  c.inPorts.add 'in',
    datatype: 'object'
  c.outPorts.add 'graph',
    datatype: 'object'
  c.outPorts.add 'component',
    datatype: 'object'
  c.outPorts.add 'project',
    datatype: 'object'
  c.outPorts.add 'error',
    datatype: 'object'

  noflo.helpers.WirePattern c,
    out: ['graph', 'component', 'project']
    async: true
  , (data, groups, out, callback) ->
    api = octo.api()
    api.token data.state.user['github-token'] if data.state.user?['github-token']

    project =
      id: data.payload.graph
      gist: data.payload.graph

    request = api.get "/gists/#{data.payload.graph}"
    request.on 'success', (res) ->
      for name, file of res.body.files
        basename = path.basename name, path.extname name
        if path.extname(name) is '.json'
          # JSON graph
          graph = JSON.parse file.content
          graph.properties = {} unless graph.properties
          graph.properties.project = project.id
          graph.properties.id = "#{project.id}_#{basename}"
          project.main = graph.properties.id unless project.main
          project.name = graph.properties.name unless project.name
          if graph.properties?.environment?.type
            project.type = graph.properties.environment.type unless project.type
          out.graph.send graph
          continue
        # Component
        component =
          name: basename
          language: file.language
          project: project.id
          code: file.content
          tests: ''
        out.component.send component
        continue
      out.project.send project
      do callback
    request.on 'error', (err) ->
      callback err.error or err.body
    do request