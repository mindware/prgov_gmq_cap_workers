exec /bin/bash <<'EOT'
	source /etc/profile.d/rbenv.sh
	# ruby /home/gmq/prgov/cap_workers/systems/prgov/validated_but_not_received.rb
	# ruby /home/gmq/prgov/cap_workers/systems/prgov/validated_but_not_received.rb > /home/gmq/cron/retry_fetch_certs.log 2>&1
	ruby /home/gmq/prgov/cap_workers/systems/prgov/retry_not_received.rb > /home/gmq/cron/retry_fetch_certs.log 2>&1
EOT
