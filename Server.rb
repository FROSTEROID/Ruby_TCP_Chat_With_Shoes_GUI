require 'socket'


$PORT_SERVICE = 5599
$PORT_FIRST= 5600
$CLIENTS_COUNT_MAX = 10
$clientsState = []
1.upto($CLIENTS_COUNT_MAX){$clientsState.push(0)}


 Shoes.app :width => 600, :height => 500 do
 
	#@el_address = edit_line "10"
	#	@el_address.style :width=>512
	@btn_listen = button "Listen"
	@eb_dialog = edit_box
		@eb_dialog.style :width=>600, :height=>400
	@el_msg = edit_line
		@el_msg.style :width=>600
	@btn_tst = button "test"
	
	@btn_listen.click {
		serviceSocketThread = Thread.new{
			@eb_dialog.text += "###### STARTED LISTENING ON " + $PORT_SERVICE.to_s + " TCP ######\n"
			_socket_server = TCPServer.new $PORT_SERVICE
			loop do
				_socket = _socket_server.accept    # Wait for a client to connect
				@clientNumber = 0				
				while @clientNumber < $CLIENTS_COUNT_MAX do
					if clientsState[@clientNumber] == 0
						clientsState[@clientNumber] = 1
						break
					end
					@clientNumber += 1
				end
				if @clientNumber < CLIENTS_COUNT_MAX
					@eb_dialog.text += "##### GOT A CLIENT. ASSIGNED PORT IS " + (PORT_FIRST + @clientNumber).to_s + "#####\n"
					_socket.puts (PORT_FIRST + @clientNumber).to_s
				else
					@eb_dialog.text += "##### GOT A CLIENT. NO SLOTS AVAILABLE. #####\n"
					_socket.puts "0"
				end
				_socket.close
			end
		}
	}
	
	@btn_tst.click {
		this.width = 888
	}

	@el_msg.finish = proc {
		@eb_dialog.text = @eb_dialog.text + @el_msg.text + "\n"
		@el_msg.text = ""
	}
 end