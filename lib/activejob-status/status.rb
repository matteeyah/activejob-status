# frozen_string_literal: true

module ActiveJob
  module Status
    class Status
      delegate :[], :to_s, :to_json, :inspect, to: :read
      delegate :queued?, :working?, :completed?, :failed?, to: :status_inquiry

      def initialize(job, options = {})
        options = ActiveJob::Status.options.merge(options)
        @defaults = options.fetch(:includes, [])
        @storage = ActiveJob::Status::Storage.new(options.without(:includes))
        @job = job
      end

      def []=(key, value)
        update({key => value}, force: true)
      end

      def read
        @storage.read(@job)
      end
      alias_method :to_h, :read

      def update(payload, options = {})
        @job.progress.instance_variable_set(:@progress, payload[:progress]) if payload.include?(:progress)
        @job.progress.instance_variable_set(:@total, payload[:total]) if payload.include?(:total)

        @storage.update(@job, payload, **options)
      end

      def delete
        @storage.delete(@job)
      end

      def job_id
        @storage.job_id(@job)
      end

      def status
        read[:status]
      end

      def progress
        read[:progress].to_f / read[:total].to_f
      end

      def present?
        read.present?
      end

      def status_inquiry
        status.to_s.inquiry
      end

      # Update default data

      def update_defaults(status_key)
        payload = {}
        payload[:status] = status_key if @defaults.include?(:status)
        payload[:serialized_job] = @job.serialize if @defaults.include?(:serialized_job)
        update(payload, force: true)
      end

      def catch_exception(e)
        payload = {}
        payload[:status] = :failed if @defaults.include?(:status)
        payload[:serialized_job] = @job.serialize if @defaults.include?(:serialized_job)
        payload[:exception] = {class: e.class.name, message: e.message} if @defaults.include?(:exception)
        update(payload, force: true)
      end
    end
  end
end
