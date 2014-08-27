require 'lib/dependencies'
require 'resque/tasks'
require 'resque/scheduler/tasks'
require 'resque/failure/redis'

# require modules
Resque::Failure::MultipleWithRetrySuppression.classes = [Resque::Failure::Redis]
Resque::Failure.backend = Resque::Failure::MultipleWithRetrySuppression
