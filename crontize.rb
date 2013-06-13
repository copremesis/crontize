#!/usr/bin/env ruby
require 'rubygems'
require 'rufus/verbs'
require 'optparse'
require 'cgi'
require 'open3'
require 'net/http'



class RLog
  def self.log(msg)
    File.open('/tmp/roberr', 'a') {|fd| fd.puts([Time.new.to_s, msg].join(': ')) } rescue nil
  end
end



module Crontize
  class Crontize

    include Open3

    def parse_options(argv)
      opts = OptionParser.new
      opts.on("-c", "--command COMMAND", String) { |v| @options[:process] = v}
      opts.on("-d", "--description DESCRIPTION", String) { |v| @options[:description] = v}
      if(argv.size == 0) 
        puts opts.to_s
        exit 1
      end
      opts.parse(*argv)
    end

    def initialize(opts = {})
      @options = {}

      #@cronboss_address = 'http://localhost:3000/api'
      #@cronboss_address = 'http://172.31.20.37:3000/api/'
      @cronboss_address = 'http://172.20.131.190/api/'
      @messenger = Messenger.new(:url => @cronboss_address)
      if(opts[:run_as_lib]) 
        @options = opts
      else
        parse_options(ARGV) 
      end
      @command = @options[:process] || "sleep 13"
      @params = {
        :process => @command
      }

      #todo
      #filter out any options that don't belong in the get params
      @params.merge!(@options)
    end

    def started
      puts 'process started'
      puts @cronboss_address 
      @messenger.send(@params.merge({:status => 'started'}))
    end

    def failed(meta = {})
      @messenger.send(@params.merge({:status => 'failed'}.merge(meta)))
    end

    def stopped
      puts 'process stopped'
      puts @cronboss_address 
      @messenger.send(@params.merge({:status=>'stopped'}))
    end

    #a more robust system call to give us the stack trace info we could use to determine what's breaking in our code

    def backtick(cmd)
      h = {}
      popen3(cmd) { |stdin, stdout, stderr|
        h[:stdout] = stdout.readlines
        h[:stderr] = stderr.readlines
        h[:success] = (h[:stderr].size == 0)
      }
      return h
    end
#DEPRECATED: this idea as intent on calling from the client code into resque yet didn't perform as expected since
#resque does some funky things when a process fails ... so instead we will have 3 class methods that are placed into
#the worker so that it can track the start/stop/fail of a job
    def yield_process
      h = {}
      begin
        started
        h[:stdout] = yield
        stopped
      rescue => e
        failed(:stderr => [e.to_s, e.backtrace.to_s].join("\n")) 
        raise RuntimeError, e.to_s #inspite of the our monitoring we want the program to crash normally so that 
                 #other processes can handle the excemption namely resque
      end
    end

    def run_commandline()
      started
      meta = backtick(@command)
      if(meta[:success])
        stopped
      else
        failed(meta)
      end
    end

    def run
      if(block_given?)
        yield_process { yield }
      else
        run_commandline()
      end
    end

    #make sure a hash is converted into a avpair
    def self.test_get_parameters
      t = self.new(:process => 'sleep 10', :description => 'pause for 10 seconds')   
    end
  
    #DEPRECATED: 
    #class method only intended for use as a library 
    #would be nice if you could take the pass in a block
    #and have that populate the :process attribute as a string
    #yet the only way I know how to do this would be to use eval which should be aliased to evil
    #as it runs arbitrary ruby code ....
    #rather a commandline for now we redundantly define the block and the process param
    #of course the two don't have to match
    #example:
    #Crontize::Crontize.run(:run_as_lib => true, :description => 'resque testing in devruby', :process => 'sleep(5)') { sleep(5) }

    def self.run(options = {})
      c = self.new(options)      
      c.run { yield } if block_given?
    end
  end

  class Messenger
    include Rufus::Verbs
    def initialize(options = {})
      @url = options[:url] 
    end

    def addmethods(hash_object)
      def hash_object.toavpair
        keypairs = []
        self.each {|k,v|
          keypairs << [k.to_s, CGI::escape(v.to_s)].join('=') 
        }
        keypairs.join('&')
      end
    end

    def send(params)
      addmethods(params)
      begin
        uri = URI.parse(@url)

        puts [@url, params.toavpair()].join('?')
        r = [@url, params.toavpair()].join('?')
        #res = get([@url, params.toavpair()].join('?'))
        req = Net::HTTP::Get.new(r)
        req.basic_auth('USERNAME', 'PASSWORD')
        res = Net::HTTP.new(uri.host, uri.port).start {|http| http.request(req) }
        puts res
      rescue => e
        puts e
      end
    end
  end
  #was an interesting idea inspired by Yehuda Katz yet overriding objects
  #seems to be a bit sketchy ... so this is just a brain exercise
  class Hijack
    def self.monitorize(klass, args, attributes)
      raise "must pass in a description" if attributes[:description].to_s.size == 0
      raise "must pass in a process call" if attributes[:process].to_s.size == 0
      new_klass = "Bar_#{rand(1<<20).to_s(base=16)}" 
      Object.class_eval <<-RUBY
        class #{new_klass} < #{klass}
          def self.perform(#{args.join(',')})
            crontizer = Crontize::Crontize.new(:run_as_lib => true, :description => '#{attributes[:description]}', :process => '#{attributes[:process]}') 
            crontizer.run {
              super(#{args.join(',')})
            }
          end
        end
      RUBY
    
      return eval(new_klass)
    end

    def self.suppress_warnings
      original_verbosity = $VERBOSE
      $VERBOSE = nil
      result = yield
      $VERBOSE = original_verbosity
      return result
    end

    def self.constant_assignment(&block)
      self.suppress_warnings {
        yield
      }
    end
  end
end

if $0 == __FILE__
  task = Crontize::Crontize.new();
  task.run
end
