#!/bin/bash
set -e
rm -f /myapp/tmp/pids/server.pid
service cron start

bundle exec rails db:migrate

exec "$@"