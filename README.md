# DBX

Database eXtras for working with CSV files in a Postgres database.

We currently only support Postgres database, but others will be supported soon.

## Usage Examples

### Import CSV file into database

Column type detection is performed based on column contents. By default the new table name will be the file name minus its extension, indexes are added to column ending with `_id$`.

```sh
dbx import path/to/data.csv --name data_v1 --db postgres://localhost/scratch --column-patterns _ref$:string
# --db   : Used to define where to put the table.
# --column-patterns : [] Override the detected column type.
# --name : [data] Optional override to default table name of file's base name without extension.
# --sample : [100] Number of rows to sample during column detection.
# --force : [false] Drops the destination table if it exists.
# --auto-index-pattern : [^(\w+_id|id)$] Creates indexes for columns matching the pattern
```

### Create diff table of two tables in a database

+ The new table will be named `diff_data_v1_data_v2`.
+ It will contains column_a, column_b, column_diff. Where column is every `column_` from `data_v1` and `column_diff` is a simple difference representation of columns `_a` and `_b`.
  + Columns `_a` and `_b` can be omitted with `--no-a-b`

```sh
dbx diff data_v1 data_v2 --db postgres://localhost/scratch --using id
# --db   : Used to define where to put the table.
# --using : Space delimited list of join columns.
# --no-a-b: [false] Omit the `_a` and `_b` columns showing the source data.
# --force : [false] Drops the destination diff table if it exists.
```

### Import and diff two CSV files

Do the import and diff all at once!!!

```sh
dbx import_diff /path/to/data_v1.csv /path/to/data_v2.csv --db postgres://localhost/scratch --using id
# --db   : Used to define where to put the table.
# --column-patterns : [] Override the detected column type.
# --sample : [100] Number of rows to sample during column detection.
# --auto-index-pattern : [^(\w+_id|id)$] Creates indexes for columns matching the pattern
# --using : Space delimited list of join columns.
# --no-a-b: [false] Omit the `_a` and `_b` columns showing the source data.
# --force : [false] Drops the destination diff table if it exists.
```

### List of Commands `dbx help`

```sh
Commands:
  dbx create SRC               # Create a table with types from SRC CSV file
  dbx diff TABLE_A TABLE_B     # Create diff table between TABLE_A and TABLE_B.
  dbx help [COMMAND]           # Describe available commands or one specific command
  dbx import SRC               # Import SRC CSV into table
  dbx import_diff SRC_A SRC_B  # Import then diff between SRC_A CSV and SRC_B CSV files.
  dbx types SRC                # Detect column types give a SRC CSV file

Options:
  [--db=Database URL: adapter://user:pass@host:port/db_name]
  [--column-patterns=List of column patterns to override type info]
  [--sample=Number of rows to sample for type detection]
                                                                     # Default: 100
  [--auto-index-pattern=Add index when column matches pattern]
                                                                     # Default: ^(\w+_id|id)$
```

## Configuration

If the current path contains a `dbx.yml` file, it will be read first. Settings in the config file can still be overridden by command line arguments.

```yaml
# Database receiving the imported and diff data.
db: postgres://localhost/scratch

# Column patterns are used to override column detection based on the a matched pattern in the name.
# This is useful for things like phone numbers and zip codes where they look like numbers, but should be strings.
column_patterns:
  phone_number: :string
  zipcode:      :string
  zip_code:     :string
  external_ref: :string

# Number of rows to sample for type detection
sample: 100

# Add index if column matches this pattern.
auto_index_pattern: _id$
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
