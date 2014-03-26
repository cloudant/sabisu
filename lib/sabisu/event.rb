# class of events in sensu
module Sabisu
  class Server
    # class for sensu events
    class Event
      # return all docs
      def self.all(options = {})
        options = { skip: 0, limit: nil, sort: [] }.merge(options)
        options.delete_if { |k, v| v.nil? || v == [] }

        CURRENT_DB.all_docs(options.merge(include_docs: true, start_key: '"a"'))
      end

      # Example: Event.search("client:cheftest* AND status:1", :bookmark => 'ABCD36',
      #                       :limit => 10,
      #                       :sort => [ 'status<string>', '-client<string>', '-issued<number>' ])
      def self.search(query, options = {})
        # define facet range params for status attribute
        ranges = { status: {} }
        ranges[:status][:OK] = '[0 TO 0]'
        ranges[:status][:Warning] = '[1 TO 1]'
        ranges[:status][:Critical] = '[2 TO 2]'
        ranges[:status][:Unknown] = '[3 TO 3]'
        # define facet count param
        counts = FIELDS.map do |field|
          field[:name] if field.key?(:facet) && field[:facet] == true
        end.compact
        options = {
          bookmark: nil,
          limit: nil,
          sort: [],
          include_docs: true,
          ranges: ranges.to_json,
          counts: counts
        }.merge(options)
        options.delete_if { |k, v| v.nil? || v == [] }
        # because couchrest doesn't handle arrays correctly
        options[:counts] = options[:counts].to_s unless options[:counts].nil?
        options[:sort] = options[:sort].to_s unless options[:sort].nil?

        CURRENT_DB.view('_design/sabisu/_search/all_fields', options.merge(q: query))
      end

      def self.update_design_doc
        # create search indexes
        fields = FIELDS.map do |field|
          next if field.key?(:index) && field[:index] == false
          field[:facet] == true ? facet = ", { 'facet': true }" : ''
          "
    if (typeof(doc.event.#{field[:path]}) !== 'undefined' && doc.event.#{field[:path]} !== null){
      index('#{field[:name]}', doc.event.#{field[:path]}#{facet});
    }"
        end
        search_function = "
    function(doc) {
      index('default', doc._id);
    #{fields.join(' ')}
    }"
        search_indexes = { all_fields: { analyzer: 'whitespace', index: search_function } }

        # save the design doc only if it has changed or doesn't exist
        begin
          doc = CURRENT_DB.get('_design/sabisu')
          if doc[:indexes] != search_indexes
            doc[:languages] = 'javascript'
            doc[:indexes] = search_indexes
            CURRENT_DB.save_doc(doc)
          end
        rescue RestClient::Conflict
          # ignore this
          puts 'doc conflict'
        rescue RestClient::ResourceNotFound
          CURRENT_DB.save_doc(
            '_id' => '_design/sabisu',
            :language => 'javascript',
            :indexes => search_indexes
          )
        end
      end

      def self.stale(params)
        # get cloudant events and put them into a hash
        cloudant_events = {}
        cloudant_events_tmp = all['rows']
        cloudant_events_tmp.each do |event|
          event = event['doc']['event']
          client = event['client']['name']
          check = event['check']['name']
          cloudant_events[client] = {} unless cloudant_events.key?(client)
          cloudant_events[client][check] = {
            status: event['check']['status'],
            output: event['check']['output']
          }
        end
        ##############################################

        # get sensu event and put them into a hash
        sensu = Sensu.new
        rawdata = sensu.request(method: 'GET', ssl: true, path: '/events')
        sensu_events_tmp = JSON.parse(rawdata.body)
        sensu_events = {}
        sensu_events_tmp.each do |event|
          client = event['client']
          check = event['check']
          sensu_events[client] = {} unless sensu_events.key?(client)
          sensu_events[client][check] = {
            status: event['status'],
            output: event['output']
          }
        end
        ##############################################

        stale = cloudant_events.deep_diff(sensu_events)

        # get list of cloudant docs to be deleted (marked as recovered by sensu)
        # this is done by iterating over the deep_diff and finding places where
        # there is no sensu alert for a client/check (ie nil)
        if params.key?('clear_recovered') && params['clear_recovered'].to_s == 'true'
          clear_list = cloudant_events_tmp.each.map do |event|
            client = event['doc']['event']['client']['name']
            check = event['doc']['event']['check']['name']
            unless sensu_events.key?(client) && sensu_events[client].key?(check)
              { client: client, check: check }
            end
          end.compact

          clear_events(clear_list)
        end

        stale
      end

      def clear_events(events)
        events.each do |event|
          puts "Deleting #{event[:client]}/#{event[:check]}"
          begin
            doc = CURRENT_DB.get("#{event[:client]}/#{event[:check]}")
            doc.destroy
          rescue RestClient::Conflict
            # there been a conflict, ignore
            puts 'doc conflict'
          rescue RestClient::ResourceNotFound
            # looks like its already deleted, noop
            puts 'doc not found'
          end
        end
      end

      def to_hash
        hash = {}
        instance_variables.each do |var|
          hash[var.to_s.delete('@')] = instance_variable_get(var)
        end
        hash
      end

      def to_json
        JSON.pretty_generate(to_hash)
      end

      # takes a hash and maps it to the fields defined in FIELDS
      def initialize(fields)
        fields.each { |k, v| send("#{k}=", v) } if fields
      end
    end
  end
end

# extend hash class
class Hash
  def deep_diff(b)
    a = self
    (a.keys | b.keys).reduce({}) do |diff, k|
      if a[k] != b[k]
        if a[k].respond_to?(:deep_diff) && b[k].respond_to?(:deep_diff)
          diff[k] = a[k].deep_diff(b[k])
        else
          diff[k] = [a[k], b[k]]
        end
      end
      diff
    end
  end
end
