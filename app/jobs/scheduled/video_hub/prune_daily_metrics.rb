# frozen_string_literal: true

module Jobs
  module VideoHub
    class PruneDailyMetrics < ::Jobs::Scheduled
      every 1.day

      def execute(args)
        cutoff = ::VideoHub::DailyMetric::RETENTION_DAYS.days.ago.to_date
        ::VideoHub::DailyMetric.where("day < ?", cutoff).delete_all
      end
    end
  end
end
