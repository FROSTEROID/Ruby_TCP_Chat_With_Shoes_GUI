require 'socket'

$CLIENTS_COUNT_MAX = 10

$PORT_SERVICE = 5599
$PORT_FIRST_MSG = $PORT_SERVICE + 1
$PORT_FIRST_FT = $PORT_FIRST_MSG + $CLIENTS_COUNT_MAX

#0-close; 1-open; 2-connected;
$clientsState = 0


$MsgPort = 0 #Port for text messages (just to make it available for dbg, not using as global in routines)
$FtPort = 0#Port for file transfering (just to make it available for dbg, not using as global in routines)

$FtSocket = nil
$MsgSocket = nil


 Shoes.app do
    @el_ipaddress = edit_line "127.0.0.1"
        @el_ipaddress.style :width=>256
    @el_port = edit_line $PORT_SERVICE
        @el_port.style :width=>256
    @btn_connect = button "Connect"
    @eb_dialog = edit_box
        @eb_dialog.style :width=>600, :height=>400
    @el_msg = edit_line
        @el_msg.style :width=>600
    
        
    #The procedure that is ran(in a separate thread) when the client tries to connect to a server
    def SessionInitialisationProc (hostname, port)
        $clientsState = 1
        DebugLog("TRYING TO CONNECT TO #{hostname}:#{port}.")
        @initSocket = TCPSocket.open(hostname, port)

        DebugLog("CONNECTED TO SERVICE!")
        @gotMsgPort = false;
        @gotFtPort = false;
        while msg = @initSocket.gets    # Read lines from socket
            if(!@gotMsgPort)
                $MsgPort = msg.to_i
                DebugLog("GOT PORT #{$MsgPort} FOR MESSAGES")
                @gotMsgPort = true
            else
                $FtPort = msg.to_i
                DebugLog("GOT PORT #{$FtPort} FOR FILES")
            break
			end
        end
        # Close the socket when done
        @initSocket.close()
        
        #Let the tcp magic happen and let the server get the listeners up
        sleep 1
        
        @sessionMsgThread = Thread.new{
            SessionMsgThreadProc(hostname, $MsgPort)
        }        
        @sessionFtThread = Thread.new{
            SessionFtThreadProc(hostname, $FtPort)
        }
    end

    def SessionMsgThreadProc(hostname, port)
        $MsgSocket= TCPSocket.open(hostname, port)
        $clientsState = 2
        DebugLog("CONNECTED TO THE MESSAGE CHAT!")
        while msg = $MsgSocket.gets # Read lines from socket
            @eb_dialog.text = msg + @eb_dialog.text
        end
        $MsgSocket.close()
        $clientsState = 0
    end

    def SessionFtThreadProc(hostname, port)
        begin
        DebugLog("Trying to connect to FT port "+port.to_s)
        # Create a server for listening
        $FtSocket = TCPSocket.open(hostname, port)
        # Log the connection event
        DebugLog("FT CONNECTED.")
        info ($FtSocket.addr(false))
        # Await for files to come and die
        while msg = $FtSocket.gets    # Read lines from socket
            info(msg)
            streamLength = msg.to_i
            acquiredLength = 0
            DebugLog("FileTransfer incoming! Size is #{streamLength}")
            
            filename = $FtSocket.gets
            info(filename)
            filename = filename.gsub!("\n", " ").squeeze(' ')
            DebugLog("Saving to "+filename+".")
            
            f = File.new(filename, "w")
            while(acquiredLength < streamLength)
                filePart= $FtSocket.gets
                DebugLog("Got a string! #{filePart}")
                acquiredLength += filePart.size
                f.write(filePart)
                
                #DebugLog("FileTransfer has died sending the stream.")
                #$MsgSocket.close()
                #$clientsState = 0
                
            end
            f.flush()
            f.close()
        
            DebugLog("FileTransfer has died trying to send a filename.")
            $MsgSocket.close()
            $clientsState = 0
            break
            
        
            #DebugLog("FileTransfer has died trying to send a filename.")
            #$MsgSocket.close()
            #$clientsState = 0
            #break
            
        end
        rescue errorr
           info(errorr) 
        end
        DebugLog("FileTransfer has died.")
        # Aaaaand close the socket
        @SessionFtSocket.close()
    end

    @btn_connect.click {
        sessionSocketThread = Thread.new{
            SessionInitialisationProc(@el_ipaddress.text, @el_port.text)
        }                                    
    }
    
    @el_msg.finish = proc { 
        $MsgSocket.puts @el_msg.text
        @eb_dialog.text = "(me) " + @el_msg.text + "\n" + @eb_dialog.text
        @el_msg.text = ""
    }
    
    def DebugLog(line)
        @eb_dialog.text = "##### " + line + " #####\n" + @eb_dialog.text
    end
    
 end
 
