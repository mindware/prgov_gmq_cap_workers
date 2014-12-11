# require 'app/core/workers/base_worker'
#
# class RequestWorker < BaseWorker
#   # @queue = :prgov_cap
#   def self.perform(*args)
#      super # call base worker perform
#      a = rand(10)
#     #  begin
#         raise Exception if (a >= 7)
# 	      system "echo \"I'm an awesome worker - #{Time.now.utc}\n#{args}\" >> ~/gmq/workers/log/done.log"
#     #  rescue Exception => e
#       #  system "echo \"I failed to be awesome - #{e}\" >> ~/gmq/workers/log/errors.log"
#         # logger.info e
#     #  end
#   end
# end
