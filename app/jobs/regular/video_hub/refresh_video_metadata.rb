# frozen_string_literal: true

module Jobs
  module VideoHub
    class RefreshVideoMetadata < ::Jobs::Base
      def execute(args)
        video_id = args[:video_id]
        raise Discourse::InvalidParameters.new(:video_id) if video_id.blank?

        ::VideoHub::RefreshVideoMetadata.refresh(video_id: video_id)
      end
    end
  end
end
