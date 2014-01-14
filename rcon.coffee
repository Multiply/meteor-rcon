dgram  = Npm.require 'dgram'
Buffer = Npm.require('buffer').Buffer

Commands =
	status :
		command : 'status'
		regex   : ///
			hostname     : \s+ (.*) \n
			version  \s+ : \s+ .* (i?n?secure) .* \n
			tcp/ip   \s+ : \s+ (.*) \n
			map      \s+ : \s+ (.*) \s+ at: .* \n
			players  \s+ : \s+ (\d+) \s+ active \s+ \((\d+) \s+ max\)
		///
		callback : (match) ->
			name           :  match[1]
			secure         :  match[2] is 'secure'
			map            :  match[4]
			currentplayers : +match[5]
			maxplayers     : +match[6]

class RCON
	constructor : (@host, @port, @password) ->
		@_challenge       = false
		@_currentQuery    = false
		@_queueProcessing = false
		@_queue           = []
		@_connect()

	command : (command, callback, errorCallback) ->
		callback      ?= ->
		errorCallback ?= ->

		# If the command exist match the regex
		if Commands[command]?
			item = Commands[command]
			@query item.command, (data) ->
				match = data.match item.regex
				callback if match isnt null then item.callback match else false
				
			, errorCallback
		
		# Error out, if said command isn't defined
		else
			throw new Exception "Command #{command} isn't defined"

	query : (command, callback, errorCallback) ->
		callback      ?= ->
		errorCallback ?= ->

		@_queue.push [command, callback, errorCallback]
		@_process() if @_challenge
	
	_process : (force = false) ->
		@_queueProcessing = false if force

		# If we don't have a challenge yet, or we're actively working on the
		# queue, or the queue is empty simply return.
		return if not @_challenge or @_queueProcessing or @_queue.length is 0

		# We're now going to process the next item in the queue
		@_queueProcessing = true
		@_currentQuery = @_queue.shift()
		
		# Send our currentQuery
		@_send @_currentQuery[0]

	# Convinience method, for calling RCON commands
	_send : (query) ->
		@_sendRaw "rcon #{@_challenge} #{@password} #{query}\n"

	# Sends the raw data over our socket
	_sendRaw : (data) ->
		buffer = new Buffer 4 + data.length
		buffer.writeInt32LE -1, 0
		buffer.write data, 4

		@_socket.send buffer, 0, buffer.length, @port, @host

	# Keep requesting a challenge token, until we get one
	_requestChallengeToken : ->
		self = @

		@_challenge = false
		@_sendRaw "challenge rcon\n"

		setTimeout ->
			self._requestChallengeToken() if not self._challenge
		, 10000

	# Handles all the dirty connection and challenge token stuff
	_connect : ->
		self = @
		
		@_socket = dgram.createSocket 'udp4'
		@_socket
			# Parse the incoming data
			.on	'message', (data) ->
				a = data.readUInt32LE 0
				if a is 0xffffffff
					str = data.toString 'utf-8', 4
					tokens = str.split ' '
					
					# If we've got a new challenge token
					if tokens.length is 3 and tokens[0] is 'challenge' and tokens[1] is 'rcon'
						self._challenge = tokens[2].substr(0, tokens[2].length - 1).trim()
						
					# Call the currentQuery's callback
					else if self._currentQuery
						self._currentQuery[1] str.substr 1, str.length - 2
					
					# Process the next item in the queue
					self._process true

				# An error happened, call the currentQuery's errorCallback
				else
					self._currentQuery[2] 'Received malformed packet' if self._currentQuery
					self._process true

			# When we've got our connection, ask for a new challenge token
			.on 'listening', ->
				self._requestChallengeToken()

			# Better error handling would be awesome
			.on 'error', (err) ->
				throw new Exception err

		# Set up the connection
		@_socket.bind 0
