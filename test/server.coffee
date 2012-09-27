fs      = require 'fs'
exec    = require('child_process').exec
coffee  = require 'coffee-script'
express = require 'express'
app     = express()
path    = require 'path'

module.exports = app

project_root = path.resolve(__dirname, '..')
app.use express.static(project_root)
app.use express.static(project_root + 'node_modules/mocha')
app.use express.static(project_root + 'node_modules/chai')

app.use express.bodyParser()

mime = (req) ->
  type = req.headers['content-type'] or ''
  type.split(';')[0]

dump = (obj) ->
  obj = '' unless obj
  obj = JSON.stringify(obj) if obj and typeof obj isnt "string"
  obj

cleanTrace = (traceStr) ->
  trace = traceStr.split("\n")
  filtered = []
  for line in trace
    if /\.html:/.test line
      line = line.replace(/^.+?@/, '')
      line = line.replace(/http:\/\/.+?\//, '')
      line = line.replace(/(:\d+):\d+$/, '$1')
      filtered.push line
  filtered

browser = (ua) ->
  if m = ua.match /(Android .+?);/
    m[1]
  else if m = ua.match /(iPhone|iPad|iPod).*?OS ([\d_]+)/
    'iOS ' + m[2].replace(/_/g, '.')
  else if m = ua.match /(Chrome\/[\d.]+)/
    m[1].replace '/', ' '
  else if m = ua.match /(Safari\/[\d.]+)/
    m[1].replace '/', ' '
  else if m = ua.match /(Firefox\/[\d.]+)/
    m[1].replace '/', ' '
  else if m = ua.match /\bMS(IE [\d.]+)/
    m[1]
  else
    ua

app.all '/', (req, res) ->
  res.redirect '/test'

app.all '/test/echo', (req, res) ->
  res.set 'Cache-Control', 'no-cache'
  res.send """
           #{req.method} ?#{dump(req.query)}
           content-type: #{mime(req)}
           accept: #{req.headers['accept']}
           #{dump(req.body)}
           """

app.get '/test/jsonp', (req, res) ->
  res.jsonp
    query: req.query
    hello: 'world'

# send JSONP response despite callback not being set
app.get '/test/jsonpBlah', (req, res) ->
  res.set 'Content-Type', 'text/javascript'
  res.send 'blah()'

app.get '/test/json', (req, res) ->
  res.set 'Cache-Control', 'no-cache'
  if /json/.test req.headers['accept']
    if req.query.invalid
      res.set 'Content-Type', 'application/json'
      res.send 'invalidJSON'
    else
      res.json
        query: req.query
        hello: 'world'
  else
    res.send 400, 'FAIL'

app.all '/test/slow', (req, res) ->
  setTimeout ->
    res.send 'DONE'
  , 200

app.get '/test/cached', (req, res) ->
  res.set 'Cache-Control', 'max-age=2'
  res.set 'Expires', new Date(Date.now() + 2000).toUTCString()
  now = new Date()
  res.send now.getTime().toString()

app.get '/test/auth', (req, res) ->
  if req.headers.authorization is 'Basic emVwdG86ZG9nZQ=='
    res.send 200
  else
    res.set 'WWW-Authenticate', "Basic realm=\"#{req.query.realm}\""
    res.send 401

app.post '/test/log', (req, res) ->
  params = req.body
  trace = cleanTrace params.trace
  console.log "[%s] %s: %s", browser(req.headers['user-agent']), params.name, params.message
  console.log trace.join("\n").replace(/^/mg, '  ') if trace.length
  res.send 200

app.all '/test/error', (req, res) ->
  res.send 500, 'BOOM'

app.get /^\/src-git\//, (req, res) ->
  file = req.path.replace('/src-git/', 'src/')
  exec "git cat-file blob #{req.query.rev}:#{file}", (error, stdout, stderr) ->
    res.set 'content-type', 'application/javascript'
    res.send stdout

app.get /\.js$/, (req, res) ->
  file = project_root + req.path.replace(/\.js$/, '.coffee')
  js = coffee.compile fs.readFileSync(file, 'utf-8')

  res.set 'content-type', 'application/javascript'
  res.send js

app.get '/test/bench', (req, res) ->
  file = project_root + "/test/performance/#{req.query.name}.coffee"
  fileContents = fs.readFileSync(file, 'utf-8') + """
  setup()
  run(name, bench, plain)
  """

  js = coffee.compile fileContents
  res.set 'content-type', 'application/javascript'
  res.send js

if process.argv[1] is __filename
  port = process.argv[2]
  unless port
    port = 3000
    console.log "Listening on port #{port}"
  app.listen port
