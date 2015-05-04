# Scheduler:
scheduler:  bundle exec rake resque:scheduler

# Resque-Retry and workers:
# Development: verbose:
# 1 child in development:
#gmq-workers: bundle exec rake resque:work QUEUE=prgov_cap COUNT=1 TERM_CHILD=1 VVERBOSE=1 --trace
gmq-workers: bundle exec rake resque:work QUEUE=prgov_cap COUNT=3 TERM_CHILD=1 VVERBOSE=1 --trace
#gmq-workers: bundle exec rake resque:work QUEUE=prgov_cap COUNT=3 TERM_CHILD=1 VVERBOSE=1 --trace
# Development: non-verbose:
#worker-dev: bundle exec rake resque:work QUEUE=prgov_cap COUNT=1 TERM_CHILD=1 --trace
# Only In Production uncomment this:
#worker-production:     bundle exec rake resque:work QUEUE=prgov_cap COUNT=5 TERM_CHILD=1

# Resque-web interface:
#resque-web: bundle exec rackup -p 5678 config.ru
