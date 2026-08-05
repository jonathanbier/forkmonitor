#!/bin/sh

ulimit -n "${FORKMONITOR_NOFILE_LIMIT:-8192}"
PATH=$PATH:/usr/local/bin:/home/forkmonitor/.rbenv/bin:/home/forkmonitor/.rbenv/shims
eval "$(rbenv init -)"
cd ~/forkmonitor/current || exit 1
RAILS_ENV=production RUBYOPT='-W:no-deprecated' exec bundle exec rake "$@"
