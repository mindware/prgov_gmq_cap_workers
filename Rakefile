# First, fix the paths so that every scripts used by this test is properly found and
# is in the ruby path. This way we don't have to include relative filepaths
$: << File.expand_path(File.dirname(__FILE__))

require 'lib/worker_dependencies'

# Our Procfile has to have rake resque:scheduler,
# it needs to be running for this to work

namespace :resque do
  task :setup do
    # Establish the connection the Redis Store
    # replace this later with Store class.
    # require 'config/db_connection'

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

  end

end
