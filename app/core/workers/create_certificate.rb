# First, fix the paths so that every scripts used by this test is properly found and
# is in the ruby path. This way we don't have to include relative filepaths
$: << File.expand_path(File.dirname(__FILE__) +"../../")
puts $:
require 'resque-retry'

require 'models/certificate'
require 'app/core/definitions/definitions'
require "app/helpers/library"
Dir["app/helpers/*.rb"].each {|file| require file }


class CreateCertificate
  # extend Resque::Plugins::Retry
  extend Resque::Plugins::ExponentialBackoff
  @queue = :create_certificate_queue

  # The first delay will be 0 seconds, the 2nd will be 60 seconds, etc.
  # The backoff strategy basically means:
  #             no delay, 1m, 10m,   1h,    3h,    6h. etc.
  # Vamos a hacerlo a dos meses.
  @backoff_strategy = [0, 60, 600, 3600, 10800, 21600]

  # The number of retries is equal to the size of the backoff_strategy array,
  # unless we set retry_limit ourselves.
  # @retry_limit = 25

  # The delay values will be multiplied by a random Float value between
  # retry_delay_multiplicand_min and retry_delay_multiplicand_max (both have a
  # default of 1.0). The product (delay_multiplicand) is recalculated on every
  # attempt. This feature can be useful if you have a lot of jobs fail at the
  # same time (e.g. rate-limiting/throttling or connectivity issues) and you
  # don't want them all retried on the same schedule.
  @retry_delay_multiplicand_min = 1.0
  @retry_delay_multiplicand_max = 1.0

  # if we wanted retries only based on a specific errors:
  # ErrorException -> amount of seconds to try after given error. IF array
  # try first one, then try x amount later.
  @retry_exceptions = { NetworkError => 30, SystemCallError => [120, 240] }

  def self.perform(*args)
    # our magic/heavy lifting goes here.
  end
end
