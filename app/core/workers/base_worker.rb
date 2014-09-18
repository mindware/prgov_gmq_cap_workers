# Base worker class
# This worker is the one where all other workers will inherit basic
# capabilities.
# For: Government Message Queue
# By: Andres Colón Pérez
# Updated: September 15 2014

# add the global config helper
require 'app/helpers/config'
# add resque-retry modules
require 'resque-retry'
# perform any variable rewrite as necessary by using the definitions file
require 'app/core/definitions/definitions'
# add the global library of helper functions
require "app/helpers/library"
# add the errors definitions
require 'app/helpers/errors'

# include all files in the helpers library, they're depencies of the transaction
# model that is used.
# Dir["app/helpers/*.rb"].each {|file| require file }

# Design tip:
# If you have a worker doing multiple things, you're doing it wrong.
# You need to break a task into two workers, and enqueue them using a pipeline
# so that both command are queued in an atomic fashion. This is meant to have
# workers be able to fail at their task and recover. If a worker is doing
# multiple things, they could fail half way (say after sending an email but
# doing x task), in which case when we retry the job the first part of the task
# which has already been done, would be repeated (in our example, an email loop)
# and that is not something you want. Aim to make all work indempotent and you
# should break tasks into the their most individual parts.
module GMQ
  module Workers
    class BaseWorker
      extend Resque::Plugins::ExponentialBackoff
      extend LibraryHelper

      def self.queue
        # @queue
        :prgov_cap
      end

      # The number of retries is equal to the size of the backoff_strategy array
      # automatically, unless we set retry_limit ourselves. If we ever need to set
      # it manually, we'd modify and uncomment the following lines. We've decided
      # not to set it manually, but the line remains here for future reference.
      # @retry_limit = 25
      # @retry_limit = 3
      # @retry_delay = 60

      # The first delay will be 0 seconds, the 2nd will be 60 seconds, etc.
      # The backoff strategy basically means, for example [0, 10, 600, etc..]:
      #                   10s, 1m, 10m,   1h,    3h,    6h. etc.
      # Vamos a hacerlo a dos meses.
      @backoff_strategy = [10, 60, 600, 3600, 10800, 21600]

      # The delay values will be multiplied by a random Float value between
      # retry_delay_multiplicand_min and retry_delay_multiplicand_max (both have a
      # default of 1.0). The product (delay_multiplicand) is recalculated on every
      # attempt. This feature can be useful if you have a lot of jobs fail at the
      # same time (e.g. rate-limiting/throttling or connectivity issues) and you
      # don't want them all retried on the same schedule.
      # These float values are multiplicands, not seconds to be added but
      # multipliers of seconds to be added.
      @retry_delay_multiplicand_min = 1.0
      @retry_delay_multiplicand_max = 2.0

      # if we wanted retries only based on a specific errors:
      # ErrorException -> amount of seconds to try after given error. IF array
      # try first one, then try x amount later.
      # @retry_exceptions = { NetworkError => 30, SystemCallError => [120, 240] }

      # We can also fail immediately with no retry for these specific exceptions
      @fatal_exceptions = [ItemNotFound, TransactionNotFound,
                           MissingTransactionId]

      def self.perform(*args)
        # our magic/heavy lifting goes here.
        # redefine this for each worker
      end
    end # end of class
  end # end of worker
end # end of gmq module
