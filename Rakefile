# First, fix the paths so that every scripts used by this test is properly found and
# is in the ruby path. This way we don't have to include relative filepaths
$: << File.expand_path(File.dirname(__FILE__))

require 'resque/tasks'
require 'resque/scheduler/tasks'

#require 'resque/failure/redis'
#require 'resque-retry/server'

# require your jobs & application code.

#Resque::Failure::MultipleWithRetrySuppression.classes = [Resque::Failure::Redis]
#Resque::Failure.backend = Resque::Failure::MultipleWithRetrySuppression

# Our Procfile has to have rake resque:scheduler,
# it needs to be running for this to work

namespace :resque do
  task :setup do
    require 'resque'
    require 'resque-scheduler'

    # Establish the connection the Redis Store
    # replace this later with Store class.
    require 'config/db_connection'

    # If you want to be able to dynamically change the schedule,
    # uncomment this line.  A dynamic schedule can be updated via the
    # Resque::Scheduler.set_schedule (and remove_schedule) methods.
    # When dynamic is set to true, the scheduler process looks for
    # schedule changes and applies them on the fly.
    # Note: This feature is only available in >=2.0.0.
    # Resque::Scheduler.dynamic = true

    # The schedule doesn't need to be stored in a YAML, it just needs to
    # be a hash.  YAML is usually the easiest.
    # Resque.schedule = YAML.load_file('your_resque_schedule.yml')

    # If your schedule already has +queue+ set for each job, you don't
    # need to require your jobs.  This can be an advantage since it's
    # less code that resque-scheduler needs to know about. But in a small
    # project, it's usually easier to just include you job classes here.
    # So, something like this:
    require 'app/core/workers/prgov_request_worker'
  end

  # doesn't work
  task :server do
  	require 'resque-retry'
  	require 'resque-retry/server'
  	Resque::Server.new
  end
end
