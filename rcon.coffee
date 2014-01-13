Rcon = Npm.require 'rcon'

Rcon.prototype._queue = []

Rcon.prototype._connect = Rcon.prototype.connect
Rcon.prototype._send    = Rcon.prototype.send

Rcon.prototype.connect = ->
	@on 'auth', ->
		if @_queue.length > 0
			@send queue_item for queue_item in @_queue
			@queue = []
	@_connect.call @

Rcon.prototype.send = (str) ->
	if @challenge and not @_challengeToken
		@_queue.push str
	else
		@_send.call @, str


