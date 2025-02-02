module Rugalytics

  class Report

    include MorphLessMethodMissing

    attr_reader :base_url, :report_name, :start_date, :end_date

    def initialize csv=''
      return if csv.empty?
      lines = csv.split("\n")
      set_attributes lines
      handle_graphs lines
      handle_tables lines
    end

    def attribute_names
      Report.morph_methods.select {|m| m[/[a-z]$/]}.select {|m| send(m.to_sym)}
    end

    def method_missing symbol, *args
      if is_writer = symbol.to_s[/=$/]
        morph_method_missing(symbol, *args)

      elsif symbol.to_s.match(/(.*)_(total|by_day)/)
        graph = "#{$1}_graph".to_sym

        if respond_to?(graph)
          $2 == 'total' ? send(graph).sum_of_points : send(graph).points_by_day
        else
          super
        end

      else
        super
      end
    end

    private

    def set_attributes lines
      @base_url = lines[1]
      @report_name = lines[2].chomp(',')
      dates = lines[3].include?('","') ? lines[3].split('","') : lines[3].split(',')
      @start_date = Rugalytics.i18n_date_parse(dates[0])
      @end_date = Rugalytics.i18n_date_parse(dates[1])
    end

    def handle_graphs lines
      index = 5
      while index < lines.size
        while (lines[index][/^# Graph/].nil? || lines[index].strip.size == 0)
          index = index.next
          return if index == lines.size
        end
        index = index + 2
        graph_period = lines[index]
        index = index.next
        name = lines[index]
        index = index.next

        points = []
        while (point = lines[index]) && point.strip.size > 0
          points << point.tr('",','').to_i
          index = index.next
        end

        graph = Graph.new name, graph_period, points, start_date, end_date
        morph("#{name.sub(/page views/i,'pageviews')} graph", graph)
      end
    end

    def handle_tables lines
      index = 5
      while index < lines.size
        while (lines[index][/^# .*Table/].nil? || lines[index].strip.size == 0)
          index = index.next
          return if index == lines.size
        end
        type = lines[index][/^# (.*)MiniTable/,1]
        index = index + 2
        attributes = lines[index].split(',')
        index = index.next

        items = []
        items_attribute = (type && type.size > 0) ? "#{type.gsub(/([a-z])([A-Z])/, '\1_\2').downcase}_items" : 'items'
        morph(items_attribute, items)

        while (values = lines[index]) && values[/^# -/].nil? && values.strip.size > 0
          items << Item.new(attributes, values.split(','), base_url)
          index = index.next
        end
      end
    end
  end
end