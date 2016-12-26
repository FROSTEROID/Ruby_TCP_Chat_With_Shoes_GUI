#!/usr/bin/ruby

load("ChatSession.rb")

class ChatSessionProxy < ChatSession
    
    def initialize msgSocket=nil, ftSocket=nil
        super
    end
    
    def SendMessage (msg)
        puts "The message #{msg} is being sent!"
        super
    end
    
end

