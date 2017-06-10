#! /usr/bin/ruby

class JpegMarkerInfo
    attr_accessor :marker_type,
                  :with_length
    def initialize(markerTypeString, withLength)
        @marker_type = markerTypeString
        @with_length = withLength
    end
end

MARKER_INFO_TABLE = {
    ## 0xFFC
    0xFFC0 => JpegMarkerInfo.new("SOF0", true),
    0xFFC1 => JpegMarkerInfo.new("SOF1", true),
    0xFFC2 => JpegMarkerInfo.new("SOF2", true),
    0xFFC3 => JpegMarkerInfo.new("SOF3", true),
    0xFFC4 => JpegMarkerInfo.new("DHT", true),
    0xFFC5 => JpegMarkerInfo.new("SOF5", true),
    0xFFC6 => JpegMarkerInfo.new("SOF6", true),
    0xFFC7 => JpegMarkerInfo.new("SOF7", true),

    0xFFC9 => JpegMarkerInfo.new("SOF9", true),
    0xFFCA => JpegMarkerInfo.new("SOF10", true),
    0xFFCB => JpegMarkerInfo.new("SOF11", true),

    0xFFCD => JpegMarkerInfo.new("SOF13", true),
    0xFFCE => JpegMarkerInfo.new("SOF14", true),
    0xFFCF => JpegMarkerInfo.new("SOF15", true),
    ## 0xFFD
    0xFFD0 => JpegMarkerInfo.new("RST0", false),
    0xFFD1 => JpegMarkerInfo.new("RST1", false),
    0xFFD2 => JpegMarkerInfo.new("RST2", false),
    0xFFD3 => JpegMarkerInfo.new("RST3", false),
    0xFFD4 => JpegMarkerInfo.new("RST4", false),
    0xFFD5 => JpegMarkerInfo.new("RST5", false),
    0xFFD6 => JpegMarkerInfo.new("RST6", false),
    0xFFD7 => JpegMarkerInfo.new("RST7", false),
    0xFFD8 => JpegMarkerInfo.new("SOI", false),
    0xFFD9 => JpegMarkerInfo.new("EOI", false),
    0xFFDA => JpegMarkerInfo.new("SOS", true),
    0xFFDB => JpegMarkerInfo.new("DQT", true),
    0xFFDC => JpegMarkerInfo.new("DNL", true),
    0xFFDD => JpegMarkerInfo.new("DRI", true),
    ## 0xFFE
    0xFFE0 => JpegMarkerInfo.new("APP0", true),
    0xFFE1 => JpegMarkerInfo.new("APP1", true),
    0xFFE2 => JpegMarkerInfo.new("APP2", true),
    0xFFE3 => JpegMarkerInfo.new("APP3", true),
    0xFFE4 => JpegMarkerInfo.new("APP4", true),
    0xFFE5 => JpegMarkerInfo.new("APP5", true),
    0xFFE6 => JpegMarkerInfo.new("APP6", true),
    0xFFE7 => JpegMarkerInfo.new("APP7", true),
    0xFFE8 => JpegMarkerInfo.new("APP8", true),
    0xFFE9 => JpegMarkerInfo.new("APP9", true),
    0xFFEA => JpegMarkerInfo.new("APP10", true),
    0xFFEB => JpegMarkerInfo.new("APP11", true),
    0xFFEC => JpegMarkerInfo.new("APP12", true),
    0xFFED => JpegMarkerInfo.new("APP13", true),
    0xFFEE => JpegMarkerInfo.new("APP14", true),
    0xFFEF => JpegMarkerInfo.new("APP15", true),
    ## 0xFFF
    0xFFFE => JpegMarkerInfo.new("COM", true)
}

class JpegHandler
    attr_accessor :input_jpeg_path,
                  :output_jpeg_path,
                  :segment_info_array
    def initialize(inputJpegPath, outputJpegPath)
        @input_jpeg_path = inputJpegPath
        @output_jpeg_path = outputJpegPath
    end

    def is_jpeg(resolveWithSecondMarker = false)
        ret = false
        File.open(@input_jpeg_path, "r") do |input_jpeg_file|
            first_segment_info = JpegSegmentInfo.new
            first_segment_info.read_segment(input_jpeg_file)
            first_marker_info = first_segment_info.marker_info
            if first_marker_info != nil && first_marker_info.marker_type == "SOI"
                ret = true
            else
                ret = false
            end
            ## optionally check 2nd marker
            if resolveWithSecondMarker == true
                second_segment_info = JpegSegmentInfo.new
                second_segment_info.read_segment(input_jpeg_file)
                if second_segment_info.is_image_data == false
                    ret = true
                else
                    ret = false
                end
            end
        end

        if ret == true
            puts "This binary file is jpeg."
        else
            puts "This file is NOT jpeg."
        end
        return ret
    end

    def read_jpeg()
        ## reading and analyzing process
        File.open(@input_jpeg_path, "r") do |input_jpeg_file|
            @segment_info_array = Array.new
            while input_jpeg_file.eof? == false
                segment_info = JpegSegmentInfo.new
                segment_info.read_segment(input_jpeg_file)
                @segment_info_array << segment_info
            end
            #debug_print_segment_array(segment_array)
        end
    end

    def write_jpeg()
        if @output_jpeg_path == nil
            puts "NO output JPEG file path"
            return
        end
        ## writing process
        File.open(@input_jpeg_path, "r") do |input_jpeg_file|
            File.open(@output_jpeg_path, "w") do |output_jpeg_file|
                @segment_info_array.each do |segment_info|
                    current_marker_info = segment_info.marker_info
                    if current_marker_info != nil && current_marker_info.marker_type =~ /^APP/
                        puts "skipping APP marker/segment (#{current_marker_info.marker_type})"
                        input_jpeg_file.seek(segment_info.raw_length, IO::SEEK_CUR)
                    else
                        puts "writing segment..."
                        output_jpeg_file.write( input_jpeg_file.read(segment_info.raw_length) )
                    end
                end
            end
        end
    end
end

class JpegSegmentInfo
    attr_accessor :is_image_data,
                  :marker_info,
                  :segment_length,
                  :raw_length
    def initialize()
        @is_image_data = false
        @marker_info = nil
        @segment_length = 0
        @raw_length = 0
    end

    def print_marker_type(markerTypeString, twoBytesInteger)
        marker_hex_str = twoBytesInteger.to_s(16).upcase
        puts "found #{markerTypeString} (0x#{marker_hex_str})"
    end

    def is_marker_with_length(twoBytesInteger)
        @marker_info = MARKER_INFO_TABLE[twoBytesInteger]

        if @marker_info != nil
            print_marker_type(@marker_info.marker_type, twoBytesInteger)
            return @marker_info.with_length
        else
            print_marker_type("other marker or data", twoBytesInteger)
            return false
        end

        return false
    end

    def seek_one_byte_backward(jpegFile)
        ## seek 1-byte backward
        if jpegFile.seek(-1, IO::SEEK_CUR) == 0 ## TODO: eof check 
            @raw_length -= 1
        else
            puts "WARNING: seek error"
        end
    end

    def read_segment(jpegFile) ## TODO: modify reading process, should use stack
        byte_integer = jpegFile.read(1).unpack("C").pop
        if byte_integer == 0xFF ## TODO: && jpegFile.eof? == false (for 0xFF-bytes at EOF)
            @is_image_data =  false
            next_byte_integer = jpegFile.read(1).unpack("C").pop
            two_bytes_integer = (byte_integer << 8) + next_byte_integer
            if is_marker_with_length(two_bytes_integer) == true
                @segment_length = jpegFile.read(2).unpack("n").pop
                puts "Segment Length: #{@segment_length}"
                skipped = jpegFile.read(@segment_length - 2)
                @raw_length = @segment_length + 2
            else
                if two_bytes_integer == 0xFFFF
                    puts "found continuous 0xFF"
                    @raw_length = 2 ## TODO: raw_length = 1 due to 1-byte backward seeking
                    seek_one_byte_backward(jpegFile)
                else
                    ## marker bytes only or NOT marker
                    @raw_length = 2
                end
            end
        else
            @is_image_data = true
            @raw_length = 1
            ## read until next 0xFF
            while byte_integer != 0xFF && jpegFile.eof? == false
                byte_integer = jpegFile.read(1).unpack("C").pop
                @raw_length += 1
            end
            ## found next 0xFF
            if byte_integer == 0xFF
                seek_one_byte_backward(jpegFile)
            end
        end
    end
end

def debug_print_segment_array(segArray)
    segArray.each do |seg|
        p seg
    end
end

def print_usage()
    puts "usage: $#{$PROGRAM_NAME} <input_jpeg> [-o <output_jpeg>]"
end

################
## script main
if (ARGV.length == 1 || ARGV.length == 3) == false
    print_usage()
    exit
end

if ARGV.length == 1
    puts "analyzing only"
    INPUT_JPEG_PATH = ARGV[0]
    OUTPUT_JPEG_PATH = nil
end
if ARGV.length == 3
    puts "analyzing and cutting APP markers/segments"
    INPUT_JPEG_PATH = ARGV[0]
    if ARGV[1] != "-o"
        print_usage()
        exit
    end
    OUTPUT_JPEG_PATH = ARGV[2]
end

jpeg_handler = JpegHandler.new(INPUT_JPEG_PATH, OUTPUT_JPEG_PATH)
if jpeg_handler.is_jpeg() == true
    jpeg_handler.read_jpeg()
    jpeg_handler.write_jpeg()
end

