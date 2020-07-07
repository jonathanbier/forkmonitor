task :restart_rake_tasks do
  on "forkmonitor" do
    execute "pkill -f rake"
  end
end
