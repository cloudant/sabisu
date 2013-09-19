class Event
  # these are all the fields we care about. the key is how we want to
  # refer to it (e.g. event.client). the value is where it is stored in
  # the database under doc.event.
  FIELDS = {
    :client => 'client.name', :check => 'check.name', :status => 'check.status',
    :occurences => 'occurrences', :action => 'action', :issued => 'check.issued', :output => 'check.output'
  }
  attr_accessor(*FIELDS.keys)

  # return all docs
  def self.all(options = {})
    options = { :skip => 0, :limit => nil, :sort => [] }.merge(options)
    options.delete_if { |k,v| v.nil? || v == [] }

    results = CURRENT_DB.all_docs(options.merge(:include_docs => true))

    { 
      :count => results['total_rows'], # TODO: this includes design docs
      :events => results['rows'].reject { |r| 
        # ignore docs that begin with _ (like design docs)
        r['doc']['_id'][0] == '_'
      }.collect { |r|
        # extract fields from doc
        fields = {}
        FIELDS.each { |k,v| 
          fields[k] = eval("r['doc']['event']" + v.split('.').collect { |vv| "['#{vv}']" }.join) 
        }
        Event.new(fields)
      } 
    }
  end

  # Example: Event.search("client:*cheftest001 AND status:warning", :bookmark => 'ABCD36',
  #                       :limit => 10, :sort => [ 'status<string>', '-client<string>', '-issued<number>' ])
  def self.search(query, options = {})
    options = { :bookmark => nil, :limit => nil, :sort => [] }.merge(options)
    options.delete_if { |k,v| v.nil? || v == [] }
    options[:sort] = options[:sort].to_s # because couchrest doesn't handle arrays correctly

    results = CURRENT_DB.view("_design/sabisu/_search/all_fields", options.merge(:q => query))

    { :count => results['total_rows'],
      :bookmark => results['bookmark'],
      :events => results['rows'].collect { |r| Event.new(r['fields']) } }
  end

  def self.update_design_doc
    # create search indexes
    fields = FIELDS.collect { |k,v|
      "if (doc.event.#{v}) index('#{k}', doc.event.#{v}, { 'store': 'yes' });"
    }
    search_function = "function(doc) { index('default', doc._id); #{fields.join(' ')} }"
    search_indexes = { :all_fields => { :index => search_function } }

    # save the design doc only if it has changed or doesn't exist
    begin
      doc = CURRENT_DB.get('_design/sabisu')
      if doc[:indexes] != search_indexes
        doc[:languages] = 'javascript'
        doc[:indexes] = search_indexes
        CURRENT_DB.save_doc(doc)
      end
    rescue RestClient::Conflict
      # ignore conflicts
    rescue RestClient::ResourceNotFound
      CURRENT_DB.save_doc({ '_id' => '_design/sabisu', :language => 'javascript', :indexes => search_indexes })
    end
  end

  # takes a hash and maps it to the fields defined in FIELDS
  def initialize(fields)
    fields.each { |k,v| self.send("#{k}=", v) } if fields
  end
end

