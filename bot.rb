$LOAD_PATH << './lib'
puts "Loading IRC..."
require 'irc'
puts "Loading Configuration Class..."
require 'configuration'
puts "Loading the IRC Parser..."
require 'parser'
puts "Loading RubyGems..."
require 'rubygems'
puts "Loading Activerecord..."
require 'activerecord'
puts "Loading models and connecting to database..."
require 'models'
puts "Loading HPricot, OpenURI and ERB..."
require 'hpricot'
require 'open-uri'
require 'erb'
require 'chronic'

$b = binding()

nick = 'butler'

irc = IRC.new( :server => 'irc.freenode.org',
                 :port => 6667,
                 :nick => nick,
                :ident => 'butler',
             :realname => 'on_irc Ruby IRC library',
              :options => { :use_ssl => false } )

parser = Parser.new

irc.on_001 do
	irc.join '##charlie'
end

irc.on_all_events do |e|
	p e
end

irc.on_privmsg do |e|
  
  parser.command(e, 'eval', true) do |c, params|
    begin
      irc.msg(e.recipient, eval(c.message, $b, 'eval', 1))
    rescue Exception => error
      irc.msg(e.recipient, 'compile error')
    end
  end
  
  parser.command(e, 'join', true) do |c, params|
    irc.join(c.message)
  end
  
  parser.command(e, 'calc') do |c, params|
    url = "http://www.google.com/search?q=#{ERB::Util.u(c.message)}"
    doc = Hpricot(open(url))
    calculation = (doc/'/html/body//#res/p/table/tr/td[3]/h2/font/b').inner_html
    if calculation.empty?
      irc.msg(e.recipient, 'Invalid Calculation.')
    else
      irc.msg(e.recipient, calculation)
    end
  end
  
  if e.message =~ /^hey[:,] remind ([^\s]+)(.+?) to (.*)$/
    title = $3
    person = $1
    time = Chronic.parse( $2 )
    
    if person == 'me'
      person = e.sender.nick
    end
    
    if !time.nil? || !title.nil?
      begin
        Event.create( :title => title, :creator => person, :channel => e.recipient, :time => time )
        irc.msg(e.recipient, "OK, #{e.sender.nick}, I'll send the reminder on #{time.strftime( '%A, %B %d, %Y at %I:%M:%S%p' )}.")
      rescue
        irc.msg(e.recipient, "Error while saving event, sorry!")
      end
    else
      irc.msg(e.recipient, "Unable to parse event. Tell my owner about this so he can fix it!")
    end
  end
  
  if e.message =~ /^assign task to ([^:]+): (.*)$/
    assigner = e.sender.nick
    assignee = $1
    title = $2
    
    if assignee == 'me'
      assignee = assigner
    end
    
    if !assigner.nil? && !assignee.nil? && !title.nil?
      begin
        task = Task.create( :title => title, :assigner => assigner, :assignee => assignee, :complete => false )
        irc.msg(e.recipient, "OK, #{e.sender.nick}, I've added that task to #{assignee}'s task list. (TID #{task.id})")
      rescue
        irc.msg(e.recipient, "Oops, I encountered an error while trying to save the task. Sorry!")
      end
    else
      irc.msg(e.recipient, "Unable to parse task, tell my owner!")
    end
    
    unless assignee == assigner
      irc.msg(assignee, "#{assigner} has added a new item to your task list: #{title} (TID #{task.id})")
      irc.msg(assignee, "Say 'show me my task list' to get more information")
    end
  end
  
  if e.message =~ /^show me my (tasks|task list)$/
    user = e.sender.nick
    tasks = Task.find_all_by_assignee_and_complete( user, false )
    irc.msg(e.sender.nick, 'Here are your currently open tasks and their TID\'s (Task IDs)')
    for task in tasks
      irc.msg(e.sender.nick, "#{task.id}. #{task.title} (Assigned by #{task.assigner})")
    end
    irc.msg(e.sender.nick, '--END--')
  end
  
  if e.message =~ /^info (\d+)$/
    task = Task.find_by_id( $1 )
    if task.nil?
      irc.msg(e.sender.nick, 'That task does not exist, sorry!')
    else
      if task.assignee == e.sender.nick || task.assigner == e.sender.nick
        irc.msg(e.sender.nick, "Information about Task #{task.id}")
        irc.msg(e.sender.nick, "---------------------------------")
        irc.msg(e.sender.nick, task.title)
        irc.msg(e.sender.nick, ' ')
        irc.msg(e.sender.nick, "Assigned To: #{task.assignee}")
        irc.msg(e.sender.nick, "Assigned By: #{task.assigner}")
        if task.complete
          irc.msg(e.sender.nick, "This task has been marked as completed")
        else
          irc.msg(e.sender.nick, "This task is not completed yet")
        end
        irc.msg(e.sender.nick, '--END--')
      else
        irc.msg(e.sender.nick, 'That task does not belong to you!')
      end
    end
  end
  
  if e.message =~ /^update task (\d+): (.*)$/
    task = Task.find_by_id($1)
    new_description = $2
    if task.nil?
      irc.msg(e.sender.nick, 'That task does not exist, sorry!')
    elsif new_description.nil?
      irc.msg(e.sender.nick, 'Please make sure you provide a new description to use!')
    else
      if task.assignee == e.sender.nick || task.assigner == e.sender.nick
        irc.msg(e.sender.nick, 'Updating description for Task ' + task.id.to_s + '... Please Wait.')
        task.update_attribute(:title, new_description)
        irc.msg(e.sender.nick, 'Done!')
        if task.assignee != e.sender.nick
          irc.msg(task.assignee, "#{e.sender.nick} has updated Task #{task.id.to_s} with the following description:")
          irc.msg(task.assignee, task.title)
        end
        if task.assigner != e.sender.nick
          irc.msg(task.assigner, "#{e.sender.nick} has updated Task #{task.id.to_s} with the following description:")
          irc.msg(task.assigner, task.title)
        end
      else
        irc.msg(e.sender.nick, 'That task does not belong to you!')
      end
    end
  end
  
  if e.message =~ /^complete task (\d+)$/
    task = Task.find_by_id( $1 )
    if task.nil?
      irc.msg(e.sender.nick, 'That task does not exist, sorry!')
    else
      if task.assignee == e.sender.nick
        irc.msg(e.sender.nick, 'Updating Status of Task ' + task.id.to_s + '... Please Wait.')
        task.update_attribute( :complete, true )
        irc.msg(e.sender.nick, 'Done!')
        if task.assigner != e.sender.nick
          irc.msg(task.assigner, "#{e.sender.nick} has marked the following task as completed (TID #{task.id}):")
          irc.msg(task.assigner, task.title)
        end
      else
        irc.msg(e.sender.nick, 'That task does not belong to you!')
      end
    end
  end
  
  if e.message =~ /^cancel task (\d+)$/
    task = Task.find( $1 )
    if task.nil?
      irc.msg(e.sender.nick, 'That task does not exist, sorry!')
    else
      if task.assignee == e.sender.nick || task.assigner == e.sender.nick
        irc.msg(e.sender.nick, 'Deleting Task ' + task.id.to_s + '... Please Wait.')
        task.destroy
        irc.msg(e.sender.nick, 'Done!')
        if task.assignee != e.sender.nick
          irc.msg(task.assignee, "#{e.sender.nick} has cancelled Task #{task.id.to_s}.")
        end
        if task.assigner != e.sender.nick
          irc.msg(task.assigner, "#{e.sender.nick} has cancelled Task #{task.id.to_s}.")
        end
      else
        irc.msg(e.sender.nick, 'That task does not belong to you!')
      end
    end
  end
  
  if e.message =~ /^reassign task (\d+) to (.*)$/
    task = Task.find( $1 )
  end
  
  ## karma
  if e.message =~ /^([^\+\+]+)\+\+$/
    person = Person.find_by_name($1)n
    
  end
  
  if e.message =~ /^([^--]+)--$/
    person = Person.find_by_name($1)
    if person.nil?
      
    else
      
    end
  end
end

irc_pid = Thread.new do
  irc.connect
end

while 1
  if !Event.count.zero?
    events = Event.find_all_by_time( Chronic.parse('6 seconds ago')..Time.now )
    if !events.length.zero?
      for event in events
        title = event.title.gsub(/your/, 'my')
        irc.msg( event.channel, "#{event.creator}: You have a reminder: #{title}" )
        event.destroy
      end
    end
  end
  sleep 5
end
