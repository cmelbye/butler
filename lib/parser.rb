class Parser
  class Command
    def initialize(message)
      @message = message
    end
    
    def message
      @message
    end
  end
  
  def command(e, name, admin_only = false)
    params = e.message.split
    @event = e
    if e.message =~ /^`#{name}(?: (.*))?/
      c = Parser::Command.new($1)
      if admin_only && !is_admin?
        return false
      end
      yield c, params
    else
      return false
    end
  end
  
  def is_admin?
    config = Configuration.new
    return config.is_admin?( @event.sender.nick, @event.sender.host )
  end
end
