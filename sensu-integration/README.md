Sensu Integration
=================
This doc explains how to integration sensu into sabisu so you can use the sabisu dashboard.

In order to do this, we need to send sensu events from sensu into a cloudant database. This is done in two steps...

1. Send sensu events to a redis list
2. Read those events from redis and send them to cloudant.

The reason why we don't send to the cloudant database directly as part of a sensu extension is performance. Each cloudant api call takes on average 200ms, vs sending events to a local redis database which takes 30ms (performance may vary on your network). To ensure the time it takes sensu to process all the handlers is as low as possible, we send the sensu events to redis for temporary storage, then have a separate process(es) pull from the redis db and sending to cloudant via the sabisu uploader.

### Enabling the redis extension
Included in this directory is a handler extension to send sensu events to a list in redis. To enable this, copy it to the extensions directory (typically `/etc/sensu/extensions/`) and enable it in all your handler sets.

### Setting up Sabisu uploader
Also included in this directory is the sabisu uploader which will read items in the redis list and send them to cloudant databases. You'll need to pass the sabisu uploader a configuration file which is a json file of attributes (see `config.example.json` for an example). You can configue this to have as many threads as you feel you need and it can be run on multiple servers simultaneously.

### Setup check\_stashes.rb
In order for "Unsilence on resolve" to work, you need to setup check\_stashes.rb as a sensu check. This will run routinely to see if any silences marked to be removed when the check or client is passing to remove those silences. Here is an example of what that would look like for chef.

```ruby
sensu_check 'check-stashes' do
  command "check-stashes.rb -a https://#{api_info['host']}:#{api_info['port']} " +
          "-u '#{api_info['user']}' -p '#{api_info['password']}'"
  handlers ['default']
  interval  120
  subscribers ['monitoring_server']
end
```
