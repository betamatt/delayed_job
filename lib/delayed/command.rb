require 'rubygems'
require 'daemons'
require 'optparse'

module Delayed
  class Command
    attr_accessor :worker_count
    
    def initialize(args)
      @files_to_reopen = []
      @options = {:quiet => true}
      
      @worker_count = 1
      
      opts = OptionParser.new do |opts|
        opts.banner = "Usage: #{File.basename($0)} [options] start|stop|restart|run"

        opts.on('-h', '--help', 'Show this message') do
          puts opts
          exit 1
        end
        opts.on('-e', '--environment=NAME', 'Specifies the environment to run this delayed jobs under (test/development/production).') do |e|
          STDERR.puts "The -e/--environment option has been deprecated and has no effect. Use RAILS_ENV and see http://github.com/collectiveidea/delayed_job/issues/#issue/7"
        end
        opts.on('--min-priority N', 'Minimum priority of jobs to run.') do |n|
          @options[:min_priority] = n
        end
        opts.on('--max-priority N', 'Maximum priority of jobs to run.') do |n|
          @options[:max_priority] = n
        end
        opts.on('-n', '--number_of_workers=workers', "Number of unique workers to spawn") do |worker_count|
          @worker_count = worker_count.to_i rescue 1
        end
        opts.on('--no-single-log', "Don't combine logging into delayed_job.log") do
          @options[:single_log] = false
        end
      end
      @args = opts.parse!(args)
    end
  
    def daemonize
      Delayed::Worker.backend.before_fork

      ObjectSpace.each_object(File) do |file|
        @files_to_reopen << file unless file.closed?
      end
      
      dir = "#{RAILS_ROOT}/tmp/pids"
      Dir.mkdir(dir) unless File.exists?(dir)
      
      worker_count.times do |worker_index|
        process_name = worker_count == 1 ? "delayed_job" : "delayed_job.#{worker_index}"
        Daemons.run_proc(process_name, :dir => dir, :dir_mode => :normal, :ARGV => @args) do |*args|
          run process_name
        end
      end
    end
    
    def run(worker_name = nil)
      Dir.chdir(RAILS_ROOT)
      
      # Re-open file handles
      @files_to_reopen.each do |file|
        begin
          target_log = @options[:single_log] ? File.join(RAILS_ROOT, 'log', 'delayed_job.log') : file.path
          file.reopen target_log, 'w+'
          file.sync = true
        rescue ::Exception
        end
      end
      
      Delayed::Worker.logger = Rails.logger
      if Delayed::Worker.logger.respond_to? :auto_flushing=
        Delayed::Worker.logger.auto_flushing = true
      end
      Delayed::Worker.backend.after_fork
      
      worker = Delayed::Worker.new(@options)
      worker.name_prefix = "#{worker_name} "
      worker.start
    rescue => e
      Rails.logger.fatal e
      STDERR.puts e.message
      exit 1
    end
    
  end
end
