# Fork Monitor

## Development

Install Ruby 2.5.3 through a version manager such as [RVM](https://rvm.io). Install
the bundler and foreman gems, then run bundler:

```
gem install bundler foreman
bundle install --without production
```

Run the server:

```
foreman start -f Procfile.dev -p 3000
```
