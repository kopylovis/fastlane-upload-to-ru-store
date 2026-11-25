module Fastlane
  module Helper
    module Rustore
      # Reads the pixel size of a PNG or JPEG from its header, enough to check
      # RuStore's image rules and pick the screenshot orientation.
      module ImageInfo
        module_function

        PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b
        JPEG_SOF = [0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF].freeze

        # [width, height], or nil when the format is not recognised.
        def dimensions(path)
          File.open(path, 'rb') do |io|
            head = io.read(8).to_s.b
            next png_size(io) if head == PNG_SIGNATURE
            next jpeg_size(io) if head.start_with?("\xFF\xD8".b)

            nil
          end
        end

        def format(path)
          File.open(path, 'rb') do |io|
            head = io.read(8).to_s.b
            next :png if head == PNG_SIGNATURE
            next :jpeg if head.start_with?("\xFF\xD8".b)

            nil
          end
        end

        def png_size(io)
          io.read(8) # IHDR length and type
          data = io.read(8)
          data&.bytesize == 8 ? data.unpack('NN') : nil
        end

        def jpeg_size(io)
          io.seek(2)
          loop do
            marker = next_marker(io)
            return nil if marker.nil? || marker == 0xD9

            length = io.read(2)&.unpack1('n')
            return nil if length.nil? || length < 2
            return sof_size(io) if JPEG_SOF.include?(marker)

            io.seek(length - 2, IO::SEEK_CUR)
          end
        end

        def next_marker(io)
          byte = io.readbyte
          byte = io.readbyte while byte != 0xFF
          byte = io.readbyte while byte == 0xFF
          byte
        rescue EOFError
          nil
        end

        def sof_size(io)
          data = io.read(5)
          return nil unless data&.bytesize == 5

          height, width = data.unpack('xnn')
          [width, height]
        end
      end
    end
  end
end
