#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'couchrest'
require 'json'

# sensu handler that sends results to cloudant db
class Cloudant < Sensu::Handler
  # override filter method so nothing gets filtered (ie silenced)
  def filter
  end

  def send_history(event_data, opts)
    db_history = CouchRest.database!(
      "https://#{opts["username"]}:#{opts["password"]}@#{opts["url"]}/#{opts["history_db"]}"
    )
    db_history.save_doc('event' => event_data)
  end

  # rubocop:disable MethodLength
  def send_current(event_data, opts)
    current_id = "#{event_data['client']['name']}/#{event_data['check']['name']}"
    db_current = CouchRest.database!(
      "https://#{opts["username"]}:#{opts["password"]}@#{opts["url"]}/#{opts["current_db"]}"
    )
    tries = 0
    begin
      # only update the current state if the event is newer than what was last written
      tries += 1
      current_event = db_current.get(current_id)
      if current_event['check'].nil? ||
        current_event['check']['issued'].to_i > event_data['check']['issued'].to_i
        db_current.save_doc(
          '_id' => current_id,
          '_rev' => current_event['_rev'],
          'event' => event_data
        )
      end
    rescue RestClient::Conflict
      # Due to sensu check results are on an interval (ie 60 secs)
      # the odds of a conflict is extremely low, (in that the doc
      # gets update/changed in the less than a sec operation of .get
      # the .save_doc
      # In addition this updating a doc only occurs when there is a
      # state change, making it even less likely.
      retry if tries <= 3
    rescue RestClient::ResourceNotFound
      # The current_id doesn't exist yet, so create it
      db_current.save_doc('_id' => current_id, 'event' => event_data)
    end
  end
  # rubocop:enable MethodLength

  def handle
    opts = settings['cloudant_output']
    event_data = @event
    # only send events on state change
    if event_data.key?('check') && event_data['check'].key?('history') &&
       (
         event_data['check']['history'].length <= 1 ||
         event_data['check']['history'][-2] != event_data['check']['history'][-1]
       )
      send_history(event_data, opts) unless opts['history_enabled'] == false
      send_current(event_data, opts)
    end
  end
end
