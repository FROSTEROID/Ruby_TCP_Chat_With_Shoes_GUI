require 'socket'


$PORT_SERVICE = 5599
$PORT_FIRST= 5600
$CLIENTS_COUNT_MAX = 10

#0-close; 1-open; 2-connected;
$clientsState = []
1.upto($CLIENTS_COUNT_MAX){$clientsState.push(0)}

$SessionSocketThreads = []
1.upto($CLIENTS_COUNT_MAX){$SessionSocketThreads.push(nil)}

$SessionSockets = []
1.upto($CLIENTS_COUNT_MAX){$SessionSockets.push(nil)}

 Shoes.app :width => 600, :height => 500 do
	@btn_listen = button "Listen"
	@eb_dialog = edit_box
		@eb_dialog.style :width=>600, :height=>400
	@el_msg = edit_line
		@el_msg.style :width=>600
	@btn_tst = button "test"
	
	@btn_listen.click proc{
		serviceSocketThread = Thread.new{
			ServiceSocketThreadProc()
		}
	}
	
	# The procedure of TCP server on PORT_SERVICE.
	def ServiceSocketThreadProc ()
		@socket_server = TCPServer.new $PORT_SERVICE
		@eb_dialog.text = "##### STARTED LISTENING ON " + $PORT_SERVICE.to_s + " TCP #####\n" + @eb_dialog.text
			loop do
				_socket = @socket_server.accept    # Wait for a client to connect
				@clientNumber = 0			
				while @clientNumber < $CLIENTS_COUNT_MAX do
					if $clientsState[@clientNumber] == 0 then
						$clientsState[@clientNumber] = 1
						break
					end
					@clientNumber += 1
				end

				if @clientNumber < $CLIENTS_COUNT_MAX
					@eb_dialog.text = "##### GOT A CLIENT FROM "+_socket.peeraddr().to_s+". ASSIGNED PORT IS " + ($PORT_FIRST + @clientNumber).to_s + ". #####\n" + @eb_dialog.text
					_socket.puts ($PORT_FIRST + @clientNumber).to_s
					Thread.new {
						SessionSocketThreadProc(@clientNumber)
					}
				else
					@eb_dialog.text = "##### GOT A CLIENT FROM "+_socket.peeraddr[:numeric]+". ASSIGNED PORT IS " + ($PORT_FIRST + @clientNumber).to_s + ". NO SLOTS AVAILABLE! #####\n" + @eb_dialog.text
					_socket.puts "0"
				end
				_socket.close
		end
	end	
	
	#The procedure that is ran for every connected client. Uses ports from PORT_FIRST to PORT_FIRST + CLIENTS_COUNT_MAX - 1
	def SessionSocketThreadProc (clientNumber)
		info("lal! " + clientNumber.to_s + "!\n")
		@eb_dialog.text = "##### Opened the port for the client. #####\n" + @eb_dialog.text
		# Create a server for listening
		@socket_session_server = TCPServer.new $PORT_FIRST + clientNumber	
		# Wait for a client to connect
		$SessionSockets[clientNumber] = @socket_session_server.accept    	
		# Mark the client number as connected
		$clientsState[clientNumber] = 2								
		# Log the connection event
		@eb_dialog.text = "##### A CLIENT CONNECTED TO " + ($PORT_FIRST + clientNumber).to_s + ". #####\n" + @eb_dialog.text
		# Await for msgs to come and die
		while msgFromClient = $SessionSockets[clientNumber].gets 	# Read lines from socket
			# Output the message along with the client number
			@eb_dialog.text = "("+clientNumber.to_s+") "+msgFromClient + @eb_dialog.text
			BroadcastMessage(msgFromClient, clientNumber)
		end
		# No moar messages - the connections died. Mark the client number as close
		$clientsState[clientNumber] = 0
		# Aaaaand close the socket
		$SessionSockets[clientNumber].close()
		return nil
	end
	
	# This will send the message to every client excepting the sourceClient
	def BroadcastMessage(message, sourceClient)
		@curClientID = 0
		$SessionSockets.each do |curSock|
			if(@curClientID != sourceClient && $clientsState[@curClientID] == 2)
				curSock.puts "(#{sourceClient}) #{message}"
			end
			@curClientID += 1
		end
	end

	
	@btn_tst.click {
		
	}

	@el_msg.finish = proc {
		BroadcastMessage(@el_msg.text, -1)
		@eb_dialog.text = "(-1) " + @el_msg.text + "\n" + @eb_dialog.text
		@el_msg.text = ""
	}
 end