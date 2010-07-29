$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'rubygems'
require 'spec'
require 'logger'

gem 'activerecord', ENV['RAILS_VERSION'] if ENV['RAILS_VERSION']

require 'delayed_job'
require 'sample_jobs'

Delayed::Worker.logger = Logger.new('/tmp/dj.log')
RAILS_ENV = 'test'

# determine the available backends
BACKENDS = []
Dir.glob("#{File.dirname(__FILE__)}/setup/*.rb") do |backend|
  begin
    backend = File.basename(backend, '.rb')
    require "setup/#{backend}"
    require "backend/#{backend}_job_spec"
    BACKENDS << backend.to_sym
  rescue Exception => e
    # Allow specs to run when not all of the databases are installed.  Other exceptions should
    # still bomb the spec run so that problems are not hidden by accident.  
    # Classes are referenced by name rather than directly since they may have been the class
    # triggering a load error when the Mongo or DM gems aren't present.
    raise unless %w(MissingSourceFile LoadError DataObjects::SQLError Mongo::ConnectionFailure).include?(e.class.name)
    puts "Unable to load #{backend} backend! #{$!}"
  end
end

Delayed::Worker.backend = BACKENDS.first

# Add this directory so the ActiveSupport autoloading works
ActiveSupport::Dependencies.load_paths << File.dirname(__FILE__)
