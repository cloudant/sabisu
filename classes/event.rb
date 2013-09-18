class Event
  # these are all the fields we care about. the key is how we want to
  # refer to it (e.g. event.client). the value is where it is stored in
  # the database under doc.event.
  FIELDS = { 
    :client => 'client.name', :check => 'check.name', :status => 'check.status', 
    :occurences => 'occurrences', :action => 'action', :issued => 'check.issued', :output => 'check.output' 
  }
  attr_accessor(*FIELDS.keys)
  
  def self.all(options = {})
    self.search(nil, options)
  end

  # Example: Event.search("client:*cheftest001 AND status:warning", :bookmark => 'ABCD36', 
  #                       :limit => 10, :sort => [ 'status<string>', '-client<string>', '-issued<number>' ])
  def self.search(query, options = {})
    options = { :bookmark => nil, :start => 0, :limit => nil, :sort => [] }.merge(options)
    raise "Cannot specify :start with searches" if query && options[:start]
    raise "Cannot specify :bookmark when returning all events" if query.nil? && options[:bookmark]

    db_options = { :include_docs => true }
    db_options[:limit] = options[:limit] if options[:limit]
    db_options[:skip] = options[:start] if options[:start]
    db_options[:bookmark] = options[:bookmark] if options[:bookmark]
    db_options[:sort] = options[:sort] if options[:sort] && !options[:sort].empty?

    results = if query.nil?
      # return all docs
      CURRENT_DB.all_docs(db_options)
    else
      # perform a search
      CURRENT_DB.view('_design/sabisu/_search/all_fields', db_options.merge(:q => query))
    end
puts results.inspect
    { :count => results['total_rows'], 
      :bookmark => results['bookmark'],
      :events => results['rows'].collect { |r| Event.new(r['fields']) } }
  end

  def self.update_design_doc
    # create search indexes
    fields = FIELDS.collect { |k,v| 
      "if (doc.event.#{v}) index('#{k}', doc.event.#{v}, { 'store': 'yes' });" 
    }
    search_indexes = { :all_fields => "function(doc) { index('default', doc._id); #{fields.join("\n")} }" }

    # save the design doc only if it has changed or doesn't exist
    begin
      doc = CURRENT_DB.get('_design/sabisu')
      if doc[:views] != search_indexes
        CURRENT_DB.save_doc({ '_id' => '_design/sabisu', :indexes => search_indexes })
      end
    rescue RestClient::Conflict
      # ignore conflicts
    rescue RestClient::ResourceNotFound
      CURRENT_DB.save_doc({ '_id' => '_design/sabisu', :indexes => search_indexes })
    end
  end

  # takes a hash and maps it to the fields defined in FIELDS
  def initialize(fields)
    fields.each { |k,v| self.send("#{k}=", v) } if fields
  end
end

