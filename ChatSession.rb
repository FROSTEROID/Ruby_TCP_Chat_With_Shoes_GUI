#!/usr/bin/ruby

# This is the class that's handling the chat connection after the connection is up.
# The same class is used on the server and the client side.

# On initialization 
#  it needs to be passed two sockets for messages and for files
#  and also handlers for 
#   accepting messages,
#   accepting files,
#   losing connection,
#   maybe something else later...

class ChatSession
    
    attr_writer :OnMsgReceived
    attr_writer :OnFileSaveHandlerNeeded
    attr_writer :OnFileReceived
    attr_writer :OnMsgConnectionLost
    attr_writer :OnFtConnectionLost
    attr_writer :OnShitHappened
    
    def initialize msgSocket=nil, ftSocket=nil
        if (msgSocket == nil)
            raise "ChatSession initialization faild. msgSocket is nil!"
        end
        if (ftSocket == nil)
            raise "ChatSession initialization faild. ftSocket is nil!"
        end
        @msgSocket = msgSocket
        @ftSocket = ftSocket
    end

    def StartTheWork
        @msgThread = Thread.new{
            MsgThreadProc()
        }
        @ftThread = Thread.new{
            FtThreadProc()
        }
    end

    def MsgThreadProc
        while msg = @msgSocket.gets # Read lines from socket
            @OnMsgReceived.call(msg)
        end
        @msgSocket.close()
        @OnMsgConnectionLost.call()
    end

    def FtThreadProc
        begin
            while msg = @ftSocket.gets    # Read lines from socket
                
                # the 1st line brings the size
                fileLength = msg.to_i
                
                # the 2nd line brings the name
                if (!(filename = @ftSocket.gets))
                    raise "FileTransfer has died right after sending the length."
                end
                
                filename = filename.gsub!("\n", " ").squeeze(' ')
                f = @OnFileSaveHandlerNeeded.call(filename, fileLength)
                
                acquiredLength = 0
                while (acquiredLength < fileLength)
                    if (!(filePart= @ftSocket.gets))
                        break
                    end
                    acquiredLength += filePart.size
                    f.write(filePart)
                end
                f.flush()
                f.close()
                
                if(acquiredLength < fileLength)
                    @ftSocket.close()
                    raise "FileTransfer has died trying to send a filename."
                    break
                end
                @OnFileReceived.call()
            end
            @ftSocket.close()
            @OnFtConnectionLost.call()
            
        rescue StandardError => ex
            OnShitHappened.call(ex)
        end
    end
    
    def SendMessage (msg)
        @msgSocket.puts msg
    end
    
    def SendFile (file)
        @fSize = File.stat(filePath).size
        @fName = File.basename(filePath)
        @f = File.new(filePath, "r")
        @fContent = IO.readlines(filePath)
        @ftSocket.puts fSize
        @ftSocket.puts fName.to_s
        @ftSocket.flush
        fContent.each do |fline|
            @ftSocket.puts fline
        end
    end

end

if($RELEASE != "True")
    begin      
        #0-close; 1-open; 2-connected;
        $clientsState = 0
        require 'socket'
        $PORT_SERVICE = 5599
        
        @MsgPort = 0 #Port for text messages (just to make it available for dbg, not using as global in routines)
        @FtPort = 0  #Port for file transfering (just to make it available for dbg, not using as global in routines)

        @FtSocket = nil
        @MsgSocket = nil
    
        hostname = "127.0.0.1"
        
        $clientsState = 1
        @initSocket = TCPSocket.open(hostname, $PORT_SERVICE)
        @gotMsgPort = false;
        @gotFtPort = false;
        while msg = @initSocket.gets    # Read lines from socket
            if(!@gotMsgPort)
                @MsgPort = msg.to_i
                @gotMsgPort = true
            else
                @FtPort = msg.to_i
            break
            end
        end
        # Close the socket when done
        @initSocket.close()
        
        #Let the tcp magic happen and let the server get the listeners up
        sleep 1
        
        @MsgSocket= TCPSocket.open(hostname, @MsgPort)
        @FtSocket = TCPSocket.open(hostname, @FtPort)
        
        
        $session = ChatSession.new @MsgSocket, @FtSocket
        $session.OnMsgReceived = lambda{|msg| puts msg}
        $session.StartTheWork()
        
    rescue StandardError => ex
        puts ex
    end
    

    puts $session
end


#PORT_SERVICE_DEFAULT = 5599
#Read on:
# http://zetcode.com/lang/rubytutorial/oop2/
# http://awaxman11.github.io/blog/2013/08/05/what-is-the-difference-between-a-block/
# http://ruby-doc.org/docs/ruby-doc-bundle/Manual/man-1.4/function.html