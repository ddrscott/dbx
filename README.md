# DBX

Misc database utilities

## Usage

```sh
dbx type items.csv

./exe/dbx import data.csv --force --db postgres://localhost/scratch --column-patterns external_id:string

# 

# import CSV as table
DATABASE_URL=postgres:///foo dbx import foo.csv
```

## Configuration

If the current path contains a `dbx.yml` file, it will be read first. Settings in the config file can still be overridden by command line arguments.

```yaml
# Column patterns are used to override column detection based on the a matched pattern in the name.
# This is useful for things like phone numbers and zip codes where they look like numbers, but should be strings.
column_patterns:
  phone_number: :string
  zipcode:      :string
  zip_code:     :string
  external_ref: :string
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'dbx'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install dbx

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ddrscott/dbx.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
