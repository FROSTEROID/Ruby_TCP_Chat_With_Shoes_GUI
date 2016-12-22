#!/usr/bin/ruby
require 'socket'

$RELEASE = true

load("ChatSession.rb")

$PORT_SERVICE = 5599

#0-close; 1-open; 2-connected;
$clientsState = 0


$MsgPort = 0 #Port for text messages (just to make it available for dbg, not using as global in routines)
$FtPort = 0#Port for file transfering (just to make it available for dbg, not using as global in routines)

$MsgSocket = nil
$FtSocket = nil

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
        
        $MsgSocket= TCPSocket.open(hostname, $MsgPort)
        
        $FtSocket = TCPSocket.open(hostname, $FtPort)
        
        $session = ChatSession.new $MsgSocket, $FtSocket
        
        $session.OnMsgReceived = lambda{
            |msg|  
            @eb_dialog.text = msg + @eb_dialog.text
        }
        $session.OnFileSavePathNeeded =  lambda { 
            |filename, fileLength|
            DebugLog("A file incoming! #{filename} of #{fileLength} bytes!")
            return File.open(filename, "w")
        }
        $session.OnFileReceived = lambda {
            DebugLog("Downloaded the file!")
        }
        $session.OnMsgConnectionLost = lambda {
            DebugLog("MSG died. :(")
        }
        $session.OnFtConnectionLost = lambda {
            DebugLog("FT died. :(")
        }
        $session.OnShitHappened = lambda {
            |ex|
            DebugLog(ex)
        }
        
        $session.StartTheWork()
    end

    @btn_connect.click {
        sessionSocketThread = Thread.new{
            SessionInitialisationProc(@el_ipaddress.text, @el_port.text)
        }                                    
    }
    
    @el_msg.finish = proc {
        msg = @el_msg.text
        $session.SendMessage(msg)
        @eb_dialog.text = "(me) " + msg + "\n" + @eb_dialog.text
        @el_msg.text = ""
    }
    
    def DebugLog(line)
        @eb_dialog.text = "##### " + line + " #####\n" + @eb_dialog.text
    end
    
 end
 
