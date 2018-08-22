require 'dbx/version'
require 'yaml'
require 'csv'
require 'pg'
require 'active_support/all'
require 'active_record'
require 'time'
require 'pp'

require 'dbx/model_base'
require 'dbx/differ'

# Collection of database utility methods
#
# #rubocop:disable all
module DBX
  module_function

  CONFIG_PATH = 'dbx.yml'

  def config
    @config ||= config_from_yaml
  end

  def config_from_yaml
    if File.file?(CONFIG_PATH)
      YAML.load(IO.read(CONFIG_PATH))
    else
      {}
    end
  end

  def config_sample_rows
    config['sample_rows'] || 100
  end

  def config_db
    ENV['DATABASE_URL'] || config['db'] || raise('`db` not set as command line option or `dbx.yml`')
  end

  # TODO what about windows?!
  def tty
    @tty ||= File.open('/dev/tty', 'a')
  end

  def info(msg)
    tty.puts("\e[33m#{msg}\e[0m")
  end

  def connection(db_url: config_db, &block)
    # ENV['DATABASE_URL'] = db_url
    # @pool ||= ModelBase.establish_connection(db_url)
    @pool ||= begin
      ModelBase.establish_connection(db_url)
      ModelBase.logger = Logger.new(tty)
    end
    ModelBase.connection_pool.with_connection(&block)
  end

  def parse_table_name(src)
    File.basename(src).sub(File.extname(src), '')
  end

  def create_table(src, name: nil, force: false, sample_rows: config_sample_rows, csv_options: {})
    name ||= parse_table_name(src)
    types = column_types(src, sample_rows: sample_rows, csv_options: csv_options)
    connection do |conn|
      conn.create_table name, force: force, id: false do |t|
        types.each do |column, type|
          t.send(type, column, nulls: true)
        end
      end
    end
  end

  # TODO parse CSV options into Postgres
  def import_table(src, name: nil, force: false, sample_rows: config_sample_rows, csv_options: {})
    name ||= parse_table_name(src)
    connection do |conn|
      create_table(src, name: name, force: force, sample_rows: sample_rows, csv_options: csv_options)
      # TODO only postgres is support at the moment
      pg = conn.instance_variable_get(:@connection)
      types = column_types(src).keys.map{|m| %("#{m}")}

      pg_stmt = "COPY #{name}(#{types.join(',')}) FROM STDIN CSV"
      conn.logger.debug(pg_stmt)
      pg.copy_data(pg_stmt) do
        first = true
        IO.foreach(src) do |line|
          if first
            first = false
            next
          end
          pg.put_copy_data(line)
        end
      end
      index_table(name)
    end
    name
  end

  def index_table(table_name)
    connection do |conn|
      conn.columns(table_name).each_with_index do |column, i|
        conn.add_index(table_name, [column.name], name: "idx_#{table_name}_#{i.to_s.rjust(2,'0')}")
      end
    end
  end

  # Read source as CSV and detect types based on `sample_rows`
  # Types returns match with ActiveRecord column types.
  # Types are memory cached by `src`.
  #
  # @return [Hash<String, Symbol>] column name to type symbols
  def column_types(src, sample_rows: config_sample_rows, csv_options: {})
    headers = nil
    count = 0
    csv_options[:headers] = false
    @types ||= {}

    types = @types[src]
    return types if types
    types = []

    CSV.foreach(src, **csv_options) do |row|
      unless headers
        headers = row
        next
      end

      headers.each_with_index do |header, i|
        next if types[i] == :string

        pattern_type = config['column_patterns'].detect{ |pat, _| header =~ /#{pat}/ }
        if pattern_type
          types[i] = pattern_type.last
          next
        end

        type = detect_type(row[i])
        next if type.nil?
        if types[i] == :decimal && type == :integer
          # keep decimal
        elsif types[i] == :datetime && type == :date
          # keep datetime
        else
          # assign the new type
          types[i] = type
        end
      end
      # stop after max rows reached
      break if (count += 1) > sample_rows
    end
    # any remaining nil types are assigned as :string
    types.size.times{|i| types[i] ||= :string }
    @types[src] = Hash[headers.zip(types)]
  end

  # Detect the column type given a value.
  # May return nil if the value is blank.
  def detect_type(value)
    if value.blank?
      nil
    elsif value =~ /^\d+\.\d+$/
      :decimal
    elsif value =~ /^\d{1,10}$/
      :integer
    elsif value =~ /^\h{8}-\h{4}-\h{4}-\h{4}-\h{12}$/
      :uuid
    elsif value =~ /^\d{4}(\D)\d{2}\1\d{2}$/ && (Date.parse(value) rescue false)
      :date
    elsif (Time.parse(value) rescue false)
      :datetime
    else
      :string
    end
  end
end
# #rubocop:enable all
