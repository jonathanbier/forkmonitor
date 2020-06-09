namespace :deploy do

  desc 'Automatically skip asset compile if possible'
  task :auto_skip_assets do
    asset_locations = %r(^(Gemfile\.lock|app/assets|lib/assets|vendor/asset))

    revisions = []
    on roles :app do
      within current_path do
        revisions << capture(:cat, 'REVISION').strip
      end
    end

    # Never skip asset compile when servers are running on different code
    next if revisions.uniq.length > 1

    changed_files = `git diff --name-only #{revisions.first}`.split
    if changed_files.grep(asset_locations).none?
      puts Airbrussh::Colors.green('** Assets have not changed since last deploy.')
      invoke 'deploy:skip_assets'
    end
  end

  desc 'Skip asset compile'
  task :skip_assets do
    puts Airbrussh::Colors.yellow('** Skipping asset compile.')
    Rake::Task['deploy:assets:precompile'].clear_actions
  end

end
