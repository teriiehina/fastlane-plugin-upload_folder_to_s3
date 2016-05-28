module Fastlane
  module Helper
    class UploadFolderToS3Helper
      # class methods that you define here become available in your action
      # as `Helper::UploadFolderToS3Helper.your_method`
      #
      def self.show_message
        UI.message("Hello from the upload_folder_to_s3 plugin helper!")
      end
    end
  end
end
