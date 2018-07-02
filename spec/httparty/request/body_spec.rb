require 'tempfile'

describe HTTParty::Request::Body do
  describe '#call' do
    subject { described_class.new(params).call }

    context 'when params is string' do
      let(:params) { 'name=Bob%20Jones' }

      it { is_expected.to eq params }
    end

    context 'when params is hash' do
      let(:params) { { people: ["Bob Jones", "Mike Smith"] } }
      let(:converted_params) { "people[]=Bob%20Jones&people[]=Mike%20Smith"}

      it { is_expected.to eq converted_params }

      context 'when params has file' do
        before do
          allow(HTTParty::Request::MultipartBoundary)
            .to receive(:generate).and_return("------------------------c772861a5109d5ef")
        end

        let(:file) { File.open('spec/fixtures/tiny.gif') }
        let(:params) do
          {
            user: {
              avatar: file,
              first_name: 'John',
              last_name: 'Doe',
              enabled: true
            }
          }
        end
        let(:expected_file_name) { 'tiny.gif' }
        let(:expected_file_contents) { "GIF89a\u0001\u0000\u0001\u0000\u0000\xFF\u0000,\u0000\u0000\u0000\u0000\u0001\u0000\u0001\u0000\u0000\u0002\u0000;" }
        let(:expected_content_type) { 'application/octet-stream' }
        let(:multipart_params) do
          "--------------------------c772861a5109d5ef\r\n" \
          "Content-Disposition: form-data; name=\"user[avatar]\"; filename=\"#{expected_file_name}\"\r\n" \
          "Content-Type: #{expected_content_type}\r\n" \
          "\r\n" \
          "#{expected_file_contents}\r\n" \
          "--------------------------c772861a5109d5ef\r\n" \
          "Content-Disposition: form-data; name=\"user[first_name]\"\r\n" \
          "\r\n" \
          "John\r\n" \
          "--------------------------c772861a5109d5ef\r\n" \
          "Content-Disposition: form-data; name=\"user[last_name]\"\r\n" \
          "\r\n" \
          "Doe\r\n" \
          "--------------------------c772861a5109d5ef\r\n" \
          "Content-Disposition: form-data; name=\"user[enabled]\"\r\n" \
          "\r\n" \
          "true\r\n" \
          "--------------------------c772861a5109d5ef--\r\n"
        end

        it { is_expected.to eq multipart_params }

        context 'file object responds to original_filename' do
          let(:some_temp_file) { Tempfile.new('some_temp_file.gif') }
          let(:expected_file_name) { "some_temp_file.gif" }
          let(:expected_file_contents) { "Hello" }
          let(:file) { double(:mocked_action_dispatch, path: some_temp_file.path, original_filename: 'some_temp_file.gif', read: expected_file_contents) }

          before { some_temp_file.write('Hello') }

          it { is_expected.to eq multipart_params }
        end

        context 'detect_mime_type is true' do
          subject { described_class.new(params, detect_mime_type: true).call }
          let(:expected_content_type) { 'image/gif' }

          it { is_expected.to eq multipart_params }

          context 'mime type cannot be determined' do
            let(:file) { File.open('spec/fixtures/unknown_file_type') }
            let(:expected_file_name) { 'unknown_file_type' }
            let(:expected_file_contents) { "???\n" }
            let(:expected_content_type) { 'application/octet-stream' }

            it { is_expected.to eq multipart_params }
          end
        end
      end
    end
  end
end
