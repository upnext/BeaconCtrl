###
# Copyright (c) 2015, Upnext Technologies Sp. z o.o.
# All rights reserved.
#
# This source code is licensed under the BSD 3-Clause License found in the
# LICENSE.txt file in the root directory of this source tree. 
###

module BeaconControl
  module DwellTimeExtension
    class LeaveEvent
      include BeaconControl::SidekiqLogger

      def initialize(event, redis = $redis)
        self.event = event
        self.redis = redis
      end

      delegate :beacon, to: :event

      #
      # Cancels execution of all delayed ActiveJob jobs for given event.
      #
      def call
        triggers.each do |trigger|
          cancel_job(Identifier.new(event, trigger.id).to_s, trigger.id)
        end
      end

      private

      attr_accessor :event, :redis

      #
      # Removes Sidekiq job from queue, if it didn't run yet. Also removes job reference ID
      # from redis.
      #
      # ==== Parameters
      #
      # * +unique_activity_id+ - ID of job in redis, generated by +Identifier+ class
      # * +trigger_id+         - ID of action's trigger to be cancelled
      #
      def cancel_job(unique_activity_id, trigger_id) # :doc:
        sidekiq_id = redis[unique_activity_id]

        if sidekiq_id.present?
          BeaconControl::BaseJob.cancel(sidekiq_id).tap do |res|
            if res
              logger.info "[#{unique_activity_id}] User left beacon before trigger #{trigger_id} - push cancelled"
            else
              logger.info "[#{unique_activity_id}] Scheduled trigger not found in sidekiq (could be triggered or cancelled earlier)"
            end
          end
        end
      ensure
        $redis.delete(unique_activity_id)
      end

      def triggers
        @triggers ||= beacon.triggers
      end
    end
  end
end
