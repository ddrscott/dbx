# #rubocop:disable all
module DBX
  module Differ
    module_function

    # Compare `src_a` with `src_b`.
    # Numeric types will be diffed by subtracting the values.
    # Dates will contain difference by day.
    # Datetime will contain difference by seconds.
    # Everything else can only return a boolean true/false that it is different.
    #
    # @param [String] table A Should be the initial state table.
    # @param [String] table B Should be newer than table A, but doesn't have to be.
    # @param [Array<String>] using is the join criteria between the 2 tables.
    # @param [Array<String>] exclude_columns are excluded from the diff comparison.
    def diff(table_a:, table_b:, force: false, using: ['id'], exclude_columns: nil, no_a_b: false)
      table_diff = "diff_#{table_a}_#{table_b}"
      exclude_columns ||= []
      using = using.map(&:downcase)
      DBX.info("Creating diff table #{table_diff}")
      DBX.connection do |conn|
        conn.execute("DROP TABLE IF EXISTS #{table_diff}") if force
        conn.execute(<<-SQL)
        CREATE TABLE #{table_diff} AS
        SELECT
          #{using.join(', ')},
          #{select_columns(table_a, exclude_columns: using + exclude_columns, no_a_b: no_a_b)}
        FROM #{table_a} AS a
        FULL OUTER JOIN #{table_b} b USING (#{using.join(',')})
        WHERE
          #{where_columns(table_a, exclude_columns: using + exclude_columns)}
        SQL
        DBX.info(conn.exec_query(<<-SQL).as_json)
        SELECT
          (SELECT COUNT(*) FROM #{table_a}) count_table_a,
          (SELECT COUNT(*) FROM #{table_b}) count_table_b,
          (SELECT COUNT(*) FROM #{table_diff}) diffs
        SQL
      end
      DBX.info("Creating diff stats: #{table_diff}")
      create_diff_stats(table_diff, force: force)

      DBX.info("Diff complete. Results details in:   #{table_diff}")
    end

    def import_and_diff(src_a:, src_b:, force: false, using: ['id'], exclude_columns: nil, no_a_b: false)
      DBX.info("Importing #{src_a}")
      table_a = DBX.import_table(src_a, force: force)


      DBX.info("Importing #{src_b}")
      table_b = DBX.import_table(src_b, force: force)

      diff(table_a: table_a, table_b: table_b, force: force, using: using, exclude_columns: exclude_columns, no_a_b: no_a_b)
    end

    def create_diff_stats(diff_table, force: false)
      DBX.connection do |conn|
        diff_stats = "#{diff_table}_stats"
        conn.execute("DROP TABLE IF EXISTS #{diff_stats}") if force
        selects = conn.columns(diff_table).map do |column|
          header, type = column.name, column.type
          col = header[/(.*)_diff$/, 1]
          next unless col

          if column.sql_type == 'interval'
            %{SUM(#{header}) AS #{col}_sum}
          else
            case type
            when :decimal, :integer, :date, :datetime
              %{SUM(#{header}) AS #{col}_sum}
            else
              %{COUNT(#{header}) AS #{col}_count}
            end
          end
        end.compact.join(",\n")
        conn.execute(<<-SQL)
          CREATE TABLE #{diff_stats} AS
          SELECT
            #{selects}
          FROM #{diff_table}
        SQL
      end
    end

    def select_columns(table, exclude_columns: nil, no_a_b: false)
      exclude_columns ||= []
      DBX.connection do |conn|
        conn.columns(table).map do |column|
          header, type = column.name, column.type
          next if exclude_columns.include?(header)
          case type
          when :decimal, :integer
            select_difference(header, no_a_b: no_a_b)
          when :date
            select_difference_as_int(header, no_a_b: no_a_b)
          when :datetime
            select_difference_as_interval(header, no_a_b: no_a_b)
          else
            select_boolean(header, no_a_b: no_a_b)
          end
        end.compact.join(',')
      end
    end

    def where_columns(table, exclude_columns: nil)
      exclude_columns ||= []
      DBX.connection do |conn|
        conn.columns(table).map do |column|
          header, type = column.name, column.type
          next if exclude_columns.include?(header)
          %((a.#{header} <> b.#{header}))
        end
      end.compact.join('OR')
    end

    def select_difference(column, no_a_b: false)
      a = "a.#{column}"
      b = "b.#{column}"
      a_b = no_a_b ? '' : "#{a} AS #{column}_a, #{b} AS #{column}_b, "
      %(#{a_b}(CASE WHEN #{a} = #{b} THEN NULL WHEN #{a} IS NULL THEN #{b} WHEN #{b} IS NULL THEN #{a} ELSE NULLIF(#{b} - #{a}, 0) END) AS #{column}_diff)
    end

    def select_difference_as_int(column, no_a_b: false)
      a = "a.#{column}"
      b = "b.#{column}"
      a_b = no_a_b ? '' : "#{a} AS #{column}_a, #{b} AS #{column}_b, "
      %(#{a_b}(CASE WHEN #{a} = #{b} THEN NULL::bigint WHEN #{a} IS NULL THEN 1 WHEN #{b} IS NULL THEN -1 ELSE (#{b} - #{a}) END) AS #{column}_diff)
    end

    def select_difference_as_interval(column, no_a_b: false)
      a = "a.#{column}"
      b = "b.#{column}"
      a_b = no_a_b ? '' : "#{a} AS #{column}_a, #{b} AS #{column}_b, "
      %(#{a_b}(CASE WHEN #{a} = #{b} THEN NULL::interval WHEN #{a} IS NULL THEN '1 day'::interval WHEN #{b} IS NULL THEN '-1 day'::interval ELSE (#{b} - #{a})::interval END) AS #{column}_diff)
    end

    def select_difference_as_text(column, no_a_b: false)
      a = "a.#{column}"
      b = "b.#{column}"
      a_b = no_a_b ? '' : "#{a} AS #{column}_a, #{b} AS #{column}_b, "
      %(#{a_b}(CASE WHEN #{a} = #{b} THEN NULL WHEN #{a} IS NULL THEN #{b}::text WHEN #{b} IS NULL THEN #{a}::text ELSE (#{b} - #{a})::text END) AS #{column}_diff)
    end

    def select_boolean(column, no_a_b: false)
      a = "a.#{column}"
      b = "b.#{column}"
      a_b = no_a_b ? '' : "#{a} AS #{column}_a, #{b} AS #{column}_b, "
      %(#{a_b}NULLIF(#{a} <> #{b}, FALSE) AS #{column}_diff)
    end
  end
end
