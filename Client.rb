require 'socket'

$PORT_SERVICE = 5599
$PORT_FIRST= 5600
$CLIENTS_COUNT_MAX = 10

#0-close; 1-open; 2-connected;
$clientsState = 0

$SessionSocket = nil

 Shoes.app do
	@el_ipaddress = edit_line "127.0.0.1"
		@el_ipaddress.style :width=>256
	@el_port = edit_line "5599"
		@el_port.style :width=>256
	@btn_connect = button "Connect"
	@eb_dialog = edit_box
		@eb_dialog.style :width=>600, :height=>400
	@el_msg = edit_line
		@el_msg.style :width=>600
	
		
	#The procedure that is ran(in a separate thread) when the client tries to connect to a server
	def SessionSocketThreadProc (hostname, port)
		$clientsState = 1
		@eb_dialog.text = "##### TRYING TO CONNECT TO #{hostname}:#{port}. #####\n" + @eb_dialog.text
		$SessionSocket = TCPSocket.open(hostname, port)

		@eb_dialog.text = "##### CONNECTED TO SERVICE! #####\n" + @eb_dialog.text
		while msg = $SessionSocket.gets	# Read lines from socket
			sessionPort = msg
			break
		end	# Close the socket when done
		$SessionSocket.close()
		@eb_dialog.text = "##### GOT PORT #{sessionPort.to_i} #####\n" + @eb_dialog.text
		sleep 1
		$SessionSocket = TCPSocket.open(hostname, sessionPort.to_i)
		$clientsState = 2
		@eb_dialog.text = "##### CONNECTED TO THE CHAT! #####\n" + @eb_dialog.text
		while msg = $SessionSocket.gets	# Read lines from socket
			@eb_dialog.text = msg + @eb_dialog.text
		end
		
		$SessionSocket.close()
		$clientsState = 0
		return nil
	end
	
	@btn_connect.click {
		sessionSocketThread = Thread.new{
			SessionSocketThreadProc(@el_ipaddress.text, @el_port.text)
	    }
	
	                                    
	}
	
	@el_msg.finish = proc { 
		$SessionSocket.puts @el_msg.text
		@eb_dialog.text = "(me) " + @el_msg.text + "\n" + @eb_dialog.text
		@el_msg.text = ""
	}
 end