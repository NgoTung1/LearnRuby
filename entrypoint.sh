#!/bin/bash
set -e
rm -f /myapp/tmp/pids/server.pid
service cron start
bundle exec whenever --update-crontab

bundle exec rails db:migrate

exec "$@"