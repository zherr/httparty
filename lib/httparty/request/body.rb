require_relative 'multipart_boundary'
require 'mimemagic'

module HTTParty
  class Request
    class Body
      def initialize(params, query_string_normalizer: nil, detect_mime_type: false)
        @params = params
        @query_string_normalizer = query_string_normalizer
        @detect_mime_type = detect_mime_type
      end

      def call
        if params.respond_to?(:to_hash)
          multipart? ? generate_multipart : normalize_query(params)
        else
          params
        end
      end

      def boundary
        @boundary ||= MultipartBoundary.generate
      end

      def multipart?
        params.respond_to?(:to_hash) && has_file?(params.to_hash)
      end

      private

      def generate_multipart
        normalized_params = params.flat_map { |key, value| HashConversions.normalize_keys(key, value) }

        multipart = normalized_params.inject('') do |memo, (key, value)|
          memo += "--#{boundary}\r\n"
          memo += %(Content-Disposition: form-data; name="#{key}")
          # value.path is used to support ActionDispatch::Http::UploadedFile
          # https://github.com/jnunemaker/httparty/pull/585
          memo += %(; filename="#{determine_file_name(value)}") if file?(value)
          memo += "\r\n"
          memo += "Content-Type: #{determine_mime_type(value)}\r\n" if file?(value)
          memo += "\r\n"
          memo += file?(value) ? value.read : value.to_s
          memo += "\r\n"
        end

        multipart += "--#{boundary}--\r\n"
      end

      def has_file?(hash)
        hash.detect do |key, value|
          if value.respond_to?(:to_hash) || includes_hash?(value)
            has_file?(value)
          elsif value.respond_to?(:to_ary)
            value.any? { |e| file?(e) }
          else
            file?(value)
          end
        end
      end

      def file?(object)
        object.respond_to?(:path) && object.respond_to?(:read) # add memoization
      end

      def includes_hash?(object)
        object.respond_to?(:to_ary) && object.any? { |e| e.respond_to?(:hash) }
      end

      def normalize_query(query)
        if query_string_normalizer
          query_string_normalizer.call(query)
        else
          HashConversions.to_params(query)
        end
      end

      def determine_file_name(object)
        object.respond_to?(:original_filename) ? object.original_filename : File.basename(object.path)
      end

      def determine_mime_type(object)
        return 'application/octet-stream' unless @detect_mime_type
        MimeMagic.by_path(object) || 'application/octet-stream'
      end

      attr_reader :params, :query_string_normalizer
    end
  end
end
