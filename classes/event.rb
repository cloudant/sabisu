# class of events in sensu
class Event
  # these are all the fields we care about. the key is how we want to
  # refer to it (e.g. event.client). the value is where it is stored in
  # the database under doc.event.
  FIELDS = {
    client: 'client.name', check: 'check.name', status: 'check.status',
    occurences: 'occurrences', action: 'action', issued: 'check.issued', output: 'check.output'
  }
  attr_accessor(*FIELDS.keys)

  # return all docs
  def self.all(options = {})
    options = { skip: 0, limit: nil, sort: [] }.merge(options)
    options.delete_if { |k, v| v.nil? || v == [] }

    results = CURRENT_DB.all_docs(options.merge(include_docs: true, start_key: '"a"'))

    # TODO: sorting

    {
      count: results['total_rows'],
      events: results['rows'].map do |r|
        # extract fields from doc
        fields = {}
        FIELDS.each do |k, v|
          fields[k] = eval("r['doc']['event']" + v.split('.').map { |vv| "['#{vv}']" }.join)
        end
        Event.new(fields)
      end
    }
  end

  # Example: Event.search("client:*cheftest001 AND status:warning", :bookmark => 'ABCD36',
  #                       :limit => 10,
  #                       :sort => [ 'status<string>', '-client<string>', '-issued<number>' ])
  def self.search(query, options = {})
    options = { bookmark: nil, limit: nil, sort: [] }.merge(options)
    options.delete_if { |k, v| v.nil? || v == [] }
    # because couchrest doesn't handle arrays correctly
    options[:sort] = options[:sort].to_s unless options[:sort].nil?

    results = CURRENT_DB.view('_design/sabisu/_search/all_fields', options.merge(q: query))

    # TODO: sorting

    { count: results['total_rows'],
      bookmark: results['bookmark'],
      events: results['rows'].map { |r| Event.new(r['fields']) } }
  end

  def self.update_design_doc
    # create search indexes
    fields = FIELDS.map do |k, v|
      "
  if (typeof(doc.event.#{v}) !== 'undefined' && doc.event.#{v} !== null){
    index('#{k}', doc.event.#{v}, { 'store': 'yes' });
  };"
    end
    search_function = "
function(doc) {
  index('default', doc._id);
#{fields.join(' ')}
}"
    search_indexes = { all_fields: { index: search_function } }

    # save the design doc only if it has changed or doesn't exist
    begin
      doc = CURRENT_DB.get('_design/sabisu')
      if doc[:indexes] != search_indexes
        doc[:languages] = 'javascript'
        doc[:indexes] = search_indexes
        CURRENT_DB.save_doc(doc)
      end
    # rubocop:disable HandleExceptions
    rescue RestClient::Conflict
      # ignore conflicts
    # rubocop:enable HandleExceptions
    rescue RestClient::ResourceNotFound
      CURRENT_DB.save_doc(
        '_id' => '_design/sabisu',
        :language => 'javascript',
        :indexes => search_indexes
      )
    end
  end

  def to_hash
    hash = {}
    instance_variables.each do |var|
      hash[var.to_s.delete("@")] = instance_variable_get(var)
    end
    hash
  end

  def to_json
    JSON.pretty_generate(self.to_hash)
  end

  # takes a hash and maps it to the fields defined in FIELDS
  def initialize(fields)
    fields.each { |k, v| send("#{k}=", v) } if fields
  end
end
