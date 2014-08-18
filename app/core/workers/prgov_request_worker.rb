require 'resque-retry'

class Worker
  extend Resque::Plugins::Retry

  @retry_limit = 3
  @retry_delay = 60

  def self.perform(*args)
	system "echo \"I'm an awesome worker\" >> ~/gmq/workers/DONE"
  end
end
