module Fastlane
  module Actions
    module SharedValues
      UPLOAD_FOLDER_TO_S3_RESULT = :UPLOAD_FOLDER_TO_S3_RESULT
    end

    class UploadFolderToS3Action < Action
      def self.run(params)
        base_local_path   = params[:local_path]
        base_remote_path  = params[:remote_path]
        s3_region         = params[:region]
        s3_bucket         = params[:bucket]

        awscreds = {
          access_key_id:      params[:access_key_id],
          secret_access_key:  params[:secret_access_key],
          region:             s3_region
        }

        result  = ""
        bucket  = valid_bucket awscreds, s3_bucket
        files   = files_at_path base_local_path

        files.each do |file|
          local_path  = base_local_path  + file
          s3_path     = base_remote_path + file

          obj = write_file_to_bucket(local_path, bucket, s3_path)

          if obj.exists?
            next
          end

          result = "Error while uploadin file #{local_path}"
          Actions.lane_context[SharedValues::UPLOAD_FOLDER_TO_S3_RESULT] = result
          return result
        end

        Actions.lane_context[SharedValues::UPLOAD_FOLDER_TO_S3_RESULT] = result
        result
      end

      def self.files_at_path(path)
        files = Dir.glob(path + "/**/*")
        to_remove = []

        files.each do |file|
          if File.directory?(file)
            to_remove.push file
          else
            file.slice! path
          end
        end

        to_remove.each do |file|
          files.delete file
        end

        files
      end

      def self.write_file_to_bucket(local_path, bucket, s3_path)
        obj = bucket.objects[s3_path]
        obj.write(file: local_path, content_type: content_type_for_file(local_path))
        obj
      end

      def self.valid_s3(awscreds, s3_bucket)
        loaded_original_gem = load_from_original_gem_name

        if !loaded_original_gem || !v1_sdk_module_present?
          load_from_v1_gem_name
          UI.verbose("Loaded AWS SDK v1.x from the `aws-sdk-v1` gem")
        else
          UI.verbose("Loaded AWS SDK v1.x from the `aws-sdk` gem")
        end

        s3 = AWS::S3.new(awscreds)

        if s3.buckets[s3_bucket].location_constraint != awscreds[:region]
          s3 = AWS::S3.new(awscreds.merge(region: s3.buckets[s3_bucket].location_constraint))
        end

        s3
      end

      def self.load_from_original_gem_name
        begin
          Gem::Specification.find_by_name('aws-sdk')
          require 'aws-sdk'
        rescue Gem::LoadError => e
          UI.verbose("The 'aws-sdk' gem is not present")
          return false
        end
        
        UI.verbose("The 'aws-sdk' gem is present")
        true
      end

      def self.load_from_v1_gem_name
        Actions.verify_gem!('aws-sdk-v1')
        require 'aws-sdk-v1'
      end

      def self.v1_sdk_module_present?
        begin
          # Here we'll make sure that the `AWS` module is defined. If it is, the gem is the v1.x API.
          Object.const_get("AWS")
        rescue NameError
          UI.verbose("Couldn't find the needed `AWS` module in the 'aws-sdk' gem")
          return false
        end

        UI.verbose("Found the needed `AWS` module in the 'aws-sdk' gem")
        true
      end

      def self.valid_bucket(awscreds, s3_bucket)
        s3 = valid_s3 awscreds, s3_bucket
        s3.buckets[s3_bucket]
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        %q{Upload a folder to S3}
      end

      def self.details
        [
          "If you want to use regex to exclude some files, please contribute to this action.",
          "Else, just do like me and from your artifacts/builds/product folder,",
          "create the subset you want to upload in another folder and upload it using this action."
        ].join("\n")
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :access_key_id,
                                       env_name: "FL_UPLOAD_FOLDER_TO_S3_ACCESS_KEY_ID",
                                       description: "Access key ID",
                                       verify_block: proc do |value|
                                         UI.user_error!(UploadFolderToS3Action.no_access_key_id_error_message) if value.to_s.length == 0
                                       end),

          FastlaneCore::ConfigItem.new(key: :secret_access_key,
                                      env_name: "FL_UPLOAD_FOLDER_TO_S3_SECRET_ACCESS_KEY",
                                      description: "Secret access key",
                                      verify_block: proc do |value|
                                        UI.user_error!(UploadFolderToS3Action.no_secret_access_key_error_message) if value.to_s.length == 0
                                      end),

          FastlaneCore::ConfigItem.new(key: :region,
                                      env_name: "FL_UPLOAD_FOLDER_TO_S3_REGION",
                                      description: "The region",
                                      verify_block: proc do |value|
                                        UI.user_error!(UploadFolderToS3Action.no_region_error_message) if value.to_s.length == 0
                                      end),

          FastlaneCore::ConfigItem.new(key: :bucket,
                                      env_name: "FL_UPLOAD_FOLDER_TO_S3_BUCKET",
                                      description: "Bucket",
                                      verify_block: proc do |value|
                                        UI.user_error!(UploadFolderToS3Action.no_bucket_error_message) if value.to_s.length == 0
                                      end),

          FastlaneCore::ConfigItem.new(key: :local_path,
                                      env_name: "FL_UPLOAD_FOLDER_TO_S3_LOCAL_PATH",
                                      description: "Path to local folder to upload",
                                      verify_block: proc do |value|
                                        UI.user_error!(UploadFolderToS3Action.invalid_local_folder_path_message) if value.to_s.length == 0
                                      end),

          FastlaneCore::ConfigItem.new(key: :remote_path,
                                       env_name: "FL_UPLOAD_FOLDER_TO_S3_REMOTE_PATH",
                                       description: "The remote base path",
                                       verify_block: proc do |value|
                                         UI.user_error!(UploadFolderToS3Action.invalid_remote_folder_path_message) if value.to_s.length == 0
                                       end)
        ]
      end

      def self.output
        [
          ['UPLOAD_FOLDER_TO_S3_RESULT', 'An empty string if everything is fine, a short description of the error otherwise']
        ]
      end

      def self.return_value
        [
          "The return value is an empty string if everything went fine,",
          "or an explanation of the error encountered."
        ].join("\n")
      end

      def self.authors
        [%q{teriiehina}]
      end

      def self.is_supported?(platform)
        true
      end

      def self.content_type_for_file(file)
        require 'mime/types'

        mime_type = MIME::Types.type_for(file).first

        return "application/octet-stream" if mime_type.nil?

        mime_type.content_type
      end

      @no_access_key_id_error_message     = "No Access key ID for upload_folder_to_s3 given, pass using `access_key_id: 'key_id'`"
      @no_secret_access_key_error_message = "No Secret access key for upload_folder_to_s3 given, pass using `secret_access_key: 'access_key'`"
      @no_region_error_message            = "No region for upload_folder_to_s3 given, pass using `region: 'region'`"
      @no_bucket_error_message            = "No bucket for upload_folder_to_s3 given, pass using `bucket: 'bucket'`"
      @invalid_local_folder_path_message  = "Invalid local folder path"
      @invalid_remote_folder_path_message = "Invalid remote folder path"

      class << self
        attr_accessor :no_access_key_id_error_message
        attr_accessor :no_secret_access_key_error_message
        attr_accessor :no_region_error_message
        attr_accessor :no_bucket_error_message
        attr_accessor :invalid_local_folder_path_message
        attr_accessor :invalid_remote_folder_path_message
      end

    end
  end
end
