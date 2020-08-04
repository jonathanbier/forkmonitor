task :restart_rake_tasks do
  on "forkmonitor" do
    execute "pkill -f rake"
  end
end

desc 'Runs rake cache:clear'
task :clear_cache => [:set_rails_env] do
  on primary fetch(:migration_role) do
    within release_path do
      with rails_env: fetch(:rails_env) do
        execute :rake, "cache:clear"
      end
    end
  end
end
