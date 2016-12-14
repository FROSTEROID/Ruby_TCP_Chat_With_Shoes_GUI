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
    attr_writer :OnFileSavePathNeeded
    attr_writer :OnFileReceived
    attr_writer :OnConnectionLost
    
    public def initialize msgSocket=nil, ftSocket=nil
        if (msgSocket == nil)
            raise "ChatSession initialization faild. msgSocket is nil!"
        end
        if (ftSocket == nil)
            raise "ChatSession initialization faild. ftSocket is nil!"
        end
        @msgSocket = msgSocket
        @ftSocket = ftSocket
        puts "looks legit!"
    end
    
    public def StartTheWork
        @msgThread = Thread.new{
            MsgThreadProc()
        }
        @ftThread = Thread.new{
            FtThreadProc()
        }
    end
    
    def MsgThreadProc()
        while msg = @msgSocket.gets # Read lines from socket
            OnMsgReceived(msg)
        end
        @msgSocket.close()
        
        OnConnectionLost()
    end
    
    def FtThreadProc()
        while msg = @ftSocket.gets    # Read lines from socket
            info(msg)
            streamLength = msg.to_i
            acquiredLength = 0
            DebugLog("FileTransfer incoming! Size is #{streamLength}")
            
            filename = @ftSocket.gets
            info(filename)
            filename = filename.gsub!("\n", " ").squeeze(' ')
            DebugLog("Saving to "+filename+".")
            
            f = File.new(filename, "w")
            while(acquiredLength < streamLength)
                filePart= @ftSocket.gets
                DebugLog("Got a string! #{filePart}")
                acquiredLength += filePart.size
                f.write(filePart)
            end
            f.flush()
            f.close()
        
            DebugLog("FileTransfer has died trying to send a filename.")
            $clientsState = 0
            break
        end
        @ftSocket.close()
    end
    
end



if($RELEASE != "True")
    begin
    session = ChatSession.new
    rescue StandardError => ex
        puts ex
    end
    

    puts session
end


    #PORT_SERVICE_DEFAULT = 5599
#Read on:
# http://zetcode.com/lang/rubytutorial/oop2/
# http://awaxman11.github.io/blog/2013/08/05/what-is-the-difference-between-a-block/
# http://ruby-doc.org/docs/ruby-doc-bundle/Manual/man-1.4/function.html