#!/usr/bin/ruby
require 'socket'

$CLIENTS_COUNT_MAX = 10

$PORT_SERVICE = 5599
$PORT_FIRST_MSG = $PORT_SERVICE + 1
$PORT_FIRST_FT = $PORT_FIRST_MSG + $CLIENTS_COUNT_MAX

#0-close; 1-open; 2-connected;
$clientsState = []
1.upto($CLIENTS_COUNT_MAX){$clientsState.push(0)}

$SessionSocketThreads = []
1.upto($CLIENTS_COUNT_MAX){$SessionSocketThreads.push(nil)}

$SessionMsgSockets = []
1.upto($CLIENTS_COUNT_MAX){$SessionMsgSockets.push(nil)}

$SessionFtSockets = []
1.upto($CLIENTS_COUNT_MAX){$SessionFtSockets.push(nil)}



 Shoes.app :width => 600, :height => 500 do
    @btn_listen = button "Listen"
    @eb_dialog = edit_box
        @eb_dialog.style :width=>600, :height=>400
    @el_msg = edit_line
        @el_msg.style :width=>600
    @btn_sendFile = button "sendFile"
    
    
    #The start of the server. On the button "listen" being clicked.
    @btn_listen.click proc{
        serviceSocketThread = Thread.new{
            ServiceSocketThreadProc()
        }
    }
    
    # The procedure of TCP server on PORT_SERVICE.
    def ServiceSocketThreadProc ()
        @socket_server = TCPServer.new $PORT_SERVICE
        DebugLog("STARTED LISTENING ON " + $PORT_SERVICE.to_s + " TCP")
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
                    @eb_dialog.text = "GOT A CLIENT FROM "+_socket.peeraddr().to_s+
                                        ". ASSIGNED PORT IS " + ($PORT_FIRST_MSG + @clientNumber).to_s + 
                                        "." + @eb_dialog.text
                    _socket.puts ($PORT_FIRST_MSG + @clientNumber).to_s
                    _socket.puts ($PORT_FIRST_FT + @clientNumber).to_s
                    Thread.new {
                        SessionMsgThreadProc(@clientNumber)
                    }
                    Thread.new {
                        SessionFtThreadProc(@clientNumber)
                    }
                else
                    @eb_dialog.text = "GOT A CLIENT FROM "+_socket.peeraddr[:numeric]+
                                        ". NO SLOTS AVAILABLE!" + @eb_dialog.text
                    _socket.puts "0"
                end
                _socket.close
        end
    end
    
    # The procedure that is ran for every connected client for messages exchanging.
    # Uses ports from $PORT_FIRST_MSG to $PORT_FIRST_MSG + CLIENTS_COUNT_MAX - 1
    def SessionMsgThreadProc (clientNumber)
        DebugLog("Opened the msg port for the client.")
        # Create a server for listening
        @socket_session_server = TCPServer.new $PORT_FIRST_MSG + clientNumber    
        # Wait for a client to connect
        $SessionMsgSockets[clientNumber] = @socket_session_server.accept        
        # Mark the client number as connected
        $clientsState[clientNumber] = 2
        # Log the connection event
        DebugLog("MSG CLIENT CONNECTED TO " + ($PORT_FIRST_MSG + clientNumber).to_s + ".")
        # Await for msgs to come and die
        while msgFromClient = $SessionMsgSockets[clientNumber].gets     # Read lines from socket
            # Output the message along wi9th the client number
            @eb_dialog.text = "("+clientNumber.to_s+") "+msgFromClient + @eb_dialog.text
            BroadcastMessage(msgFromClient, clientNumber)
        end
        # No moar messages - the connections died. Mark the client number as close
        $clientsState[clientNumber] = 0
        # Aaaaand close the socket
        $SessionMsgSockets[clientNumber].close()
        return nil
    end
    
    # The procedure that is ran for every connected client for files exchanging.
    # Uses ports from $PORT_FIRST_FT to $PORT_FIRST_FT + CLIENTS_COUNT_MAX - 1
    def SessionFtThreadProc (clientNumber)
        DebugLog("Opened the ft port for the client.")
        # Create a server for listening
        @socket_session_server = TCPServer.new $PORT_FIRST_FT + clientNumber
        # Wait for a client to connect
        $SessionFtSockets[clientNumber] = @socket_session_server.accept
        # Log the connection event
        DebugLog("FT CLIENT CONNECTED TO " + ($PORT_FIRST_FT + clientNumber).to_s + ".")
        # Await for files to come and die
        while msg = $SessionFtSockets[clientNumber].gets    # Read lines from socket
            streamLength = msg.to_i
            if(filename = $SessionFtSockets[clientNumber].gets)
                if(filename = ($SessionFtSockets[clientNumber].gets).gsub!("/", ""))
                    f = File.new(filename, "w")
                    while(streamLength > 0)
                        if(filePart= $SessionFtSockets[clientNumber].gets)
                            streamLength -= filePart.size
                            f.write(filePart)
                        else
                            DebugLog("FT CLIENT ON " + ($PORT_FIRST_FT + clientNumber).to_s + " has died sending the stream.")
                            $SessionMsgSockets[clientNumber].close()
                            $clientsState[clientNumber] = 0
                            break
                        end
                    end
                    f.flush()
                    f.close()
                else
                    DebugLog("FT CLIENT ON " + ($PORT_FIRST_FT + clientNumber).to_s + " has died trying to send a filename.")
                    $SessionMsgSockets[clientNumber].close()
                    $clientsState[clientNumber] = 0
                    break
                end
            else
                
            end
            # Output the message along with the client number
            @eb_dialog.text = "("+clientNumber.to_s+") "+msgFromClient + @eb_dialog.text
            BroadcastMessage(msgFromClient, clientNumber)
        end
        # Aaaaand close the socket
        $SessionFtSockets[clientNumber].close()
    end
    
    # This will send the message to every client excepting the sourceClientID
    def BroadcastMessage(message, sourceClientID)
        @curClientID = 0
        $SessionMsgSockets.each do |curSock|
            if(@curClientID != sourceClientID && $clientsState[@curClientID] == 2)
                begin
                curSock.puts "(#{sourceClientID}) #{message}"
                rescue
                    DebugLog("Client #{@curClientID} died")
                    $clientsState[@curClientID] = 0
                end
            end
            @curClientID += 1
        end
    end
    
    # This will send the file to every client excepting the sourceClientID
    def BroadcastFile(filePath, sourceClientID)
        @curClientID = 0
        fSize = File.stat(filePath).size
        fName = File.basename(filePath)
        f = File.new(filePath, "r")
        fContent = IO.readlines(filePath)
        $SessionFtSockets.each do |curSock|
            if(@curClientID != sourceClientID && $clientsState[@curClientID] == 2)
                DebugLog("Sending the size (#{fSize}) to client "+ @curClientID.to_s + "")
                curSock.puts fSize
                DebugLog("Sending the name #{fName} to client "+ @curClientID.to_s + "")
                curSock.puts fName.to_s
                curSock.flush
                fContent.each do |fline|
                   #DebugLog("Sending data(#{fline.size}) to client "+ @curClientID.to_s + "")
                   curSock.puts fline
                end
            else
                DebugLog("Ignoring client #{@curClientID.to_s}, #{$clientsState[@curClientID]}")
            end
            @curClientID += 1
        end
    end
    
    @btn_sendFile.click {
        filename = ask_open_file;
        Thread.new { BroadcastFile(filename, -1) }
    }

    @el_msg.finish = proc {
        BroadcastMessage(@el_msg.text, -1)
        @eb_dialog.text = "(-1) " + @el_msg.text + "\n" + @eb_dialog.text
        @el_msg.text = ""
    }
    
    def DebugLog(line)
        @eb_dialog.text = "#####" + line + "#####\n" + @eb_dialog.text
    end
    
 end