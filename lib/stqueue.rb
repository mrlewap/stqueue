# frozen_string_literal: true

require "English"
require 'stqueue/version'
require 'stqueue/error'
require 'stqueue/runner'
require 'stqueue/monitor'
require 'stqueue/store/base'
require 'stqueue/store/redis_store'
require 'stqueue/store/file_store'
require 'stqueue/base'

module STQueue # :nodoc:
  WRONG_STORE_TYPE         = 'Wrong store type'.freeze
  WRONG_LOG_DIR_TYPE_ERROR = 'STQueue log_dir must be a `Pathname`. Use `Rails.root.join(...)` to define it.'.freeze
  QUEUE_PREFIX             = 'stqueue'.freeze
  AVAILABLE_STORES         = %i[redis file].freeze

  @config = ::OpenStruct.new

  class << self
    delegate :log_dir, :store, :enabled, :enabled=, to: :@config

    def configure
      yield self
      enabled &&= !Rails.env.test?
      return unless enabled && defined?(::Rails) && sidekiq_connected?
      monitor.health_check
    end

    def sidekiq_connected?
      Rails.application.config.active_job.queue_adapter == :sidekiq
    rescue StandardError
      false
    end

    def log_dir=(dir)
      return unless STQueue.enabled
      raise Error, WRONG_LOG_DIR_TYPE_ERROR unless dir.is_a? Pathname
      @config.log_dir = dir
    end

    def monitor
      return unless STQueue.enabled
      @monitor ||= STQueue::Monitor.new
    end

    def store=(store_type)
      return unless STQueue.enabled
      raise Error, WRONG_STORE_TYPE unless AVAILABLE_STORES.include? store_type.to_sym
      @config.store = "STQueue::Store::#{store_type.to_s.capitalize}Store".safe_constantize
    end
  end
end
