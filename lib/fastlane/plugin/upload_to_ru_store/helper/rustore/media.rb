require_relative 'errors'
require_relative 'image_info'

module Fastlane
  module Helper
    module Rustore
      # RuStore rules for the icon and screenshots of a version.
      module Media
        module_function

        ICON_MAX_BYTES = 3 * 1024 * 1024
        ICON_SIZE = [512, 512].freeze
        SCREENSHOT_MAX_BYTES = 5 * 1024 * 1024
        SCREENSHOT_SIDES = (320..3840)
        SCREENSHOT_SLOTS = 10
        SCREENSHOTS_TO_PUBLISH = 3
        ORIENTATIONS = %w[PORTRAIT LANDSCAPE].freeze
        SCREENSHOT_TYPES = %w[SCREENSHOT TABLET_SCREENSHOT TV_SCREENSHOT].freeze
        MIME_TYPES = { png: 'image/png', jpeg: 'image/jpeg' }.freeze

        def icon!(path)
          content_type = image!(path, ICON_MAX_BYTES, 'иконка')
          size = ImageInfo.dimensions(path)
          if size && size != ICON_SIZE
            raise ConfigurationError, "иконка должна быть #{ICON_SIZE.join('×')} px, а #{File.basename(path)} #{size.join('×')} px"
          end

          content_type
        end

        def screenshot!(path)
          content_type = image!(path, SCREENSHOT_MAX_BYTES, 'скриншот')
          size = ImageInfo.dimensions(path)
          if size&.any? { |side| !SCREENSHOT_SIDES.cover?(side) }
            raise ConfigurationError, "стороны скриншота от #{SCREENSHOT_SIDES.min} до #{SCREENSHOT_SIDES.max} px, " \
                                      "а #{File.basename(path)} #{size.join('×')} px"
          end

          content_type
        end

        # Checks one device type's screenshots and returns their orientation.
        def screenshot_set!(type, paths, orientation = nil)
          type!(type)
          if paths.size > SCREENSHOT_SLOTS
            raise ConfigurationError, "#{type}: не больше #{SCREENSHOT_SLOTS} скриншотов, передано #{paths.size}"
          end

          paths.each { |path| screenshot!(path) }
          orientation!(paths, orientation)
        end

        # PORTRAIT or LANDSCAPE from the image size; nil when it cannot be read.
        def orientation_of(path)
          width, height = ImageInfo.dimensions(path)
          return nil if width.nil?

          height >= width ? 'PORTRAIT' : 'LANDSCAPE'
        end

        # RuStore refuses screenshots of mixed orientation within one version.
        def orientation!(paths, given = nil)
          return one_of!(given.to_s.upcase, ORIENTATIONS, 'screenshots_orientation') if given

          found = paths.filter_map { |path| orientation_of(path) }.uniq
          raise ConfigurationError, 'скриншоты разной ориентации, RuStore примет только одну' if found.size > 1

          found.first || 'PORTRAIT'
        end

        def ordinal!(value)
          number = Integer(value, exception: false)
          return number if number&.between?(0, SCREENSHOT_SLOTS - 1)

          raise ConfigurationError, "ordinal скриншота от 0 до #{SCREENSHOT_SLOTS - 1}, получено #{value}"
        end

        def type!(value)
          one_of!(value, SCREENSHOT_TYPES, 'тип скриншота')
        end

        def one_of!(value, allowed, name)
          return value if allowed.include?(value)

          raise ConfigurationError, "неизвестный #{name}: #{value}. Допустимы: #{allowed.join(', ')}"
        end

        def image!(path, max_bytes, name)
          raise ConfigurationError, "файл не найден (#{name}): #{path}" unless File.file?(path)

          format = ImageInfo.format(path)
          raise ConfigurationError, "#{name} должен быть PNG или JPEG: #{path}" unless format
          raise ConfigurationError, "#{name} больше #{max_bytes / 1024 / 1024} МБ: #{path}" if File.size(path) > max_bytes

          MIME_TYPES.fetch(format)
        end
      end
    end
  end
end
