# frozen_string_literal: true

task :install_rake_launcher do
  on 'forkmonitor' do
    execute :install, '-m', '0755', "#{current_path}/deploy/home/forkmonitor/rake.sh", '/home/forkmonitor/rake.sh'
  end
end

task :restart_rake_tasks do
  on 'forkmonitor' do
    rake_task_pattern = '[r]ake nodes:(poll_repeat|heavy_checks_repeat|rollback_checks_repeat)'
    execute "if pgrep -f '#{rake_task_pattern}'; then pkill -TERM -f '#{rake_task_pattern}'; fi"
    sleep 10
    execute "if pgrep -f '#{rake_task_pattern}'; then pkill -KILL -f '#{rake_task_pattern}'; fi"
  end
end

rake_roles = fetch(:rake_roles, :app)
desc 'Clear Rails cache'
task :clear_cache do
  on roles(rake_roles) do
    within current_path do
      with rails_env: fetch(:rails_env) do
        execute :rake, 'cache:clear'
      end
    end
  end
end
