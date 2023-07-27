# frozen_string_literal: true

task :restart_rake_tasks do
  on 'forkmonitor' do
    execute 'if pgrep rake; then pkill rake; fi'
    sleep 10
    execute 'if pgrep rake; then pkill -9 rake; fi'
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
