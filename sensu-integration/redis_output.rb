module Sensu
  module Extension
    # redis output extension
    class RedisOutput < Handler
      require 'sensu/redis'

      def definition
        {
          type: 'extension',
          name: 'redis_output'
        }
      end

      def name
        definition[:name]
      end

      def description
        'outputs events output to a redis list or channel'
      end

      def post_init
        @redis = Sensu::Redis.connect(
          host: @settings['redis_output']['host'] || 'localhost',
          port: @settings['redis_output']['port'] || 6379,
          database: @settings['redis_output']['db'] || 0
        )
      end

      def run(event)
        now = Time.now
        opts = @settings['redis_output']

        case opts['data_type']
        when 'list'
          @redis.lpush(opts['key'], event)
        when 'channel'
          @redis.publish(opts['key'], event)
        end

        yield("redis_output execution time: #{Time.now - now}", 0)
      end
    end
  end
end
