PATH=$PATH:/usr/local/bin:/home/forkmonitor/.rbenv/bin:/home/forkmonitor/.rbenv/shims
eval "$(rbenv init -)"
cd ~/forkmonitor/current
RAILS_ENV=production RUBYOPT='-W:no-deprecated' bundle exec rake $1
