# frozen_string_literal: true

task :restart_rake_tasks do
  on 'forkmonitor' do
    execute 'pkill -9 -f rake'
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
