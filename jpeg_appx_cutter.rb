#! /usr/bin/ruby

class JpegSegment
    attr_accessor :is_image_data,
                  :marker_hex_str,
                  :segment_length,
                  :raw_length
    def initialize()
        @is_image_data = false
        @marker_hex_str = nil
        @segment_length = 0
        @raw_length = 0
    end

    def print_and_update_marker_type(markerTypeString, twoBytesHexString)
        puts "found #{markerTypeString} (0x#{twoBytesHexString})"
        @marker_hex_str = twoBytesHexString
    end

    def is_marker_with_length(twoBytesHexString)
        case twoBytesHexString
        when /^FFC/
            if twoBytesHexString == "FFC4"
                print_and_update_marker_type("DHT", twoBytesHexString)
            else
                print_and_update_marker_type("SOF", twoBytesHexString)
            end
            return true
        when /^FFD/ 
            case twoBytesHexString
            when "FFD8"
                print_and_update_marker_type("SOI", twoBytesHexString)
                puts "no length field"
                return false
            when "FFD9"
                print_and_update_marker_type("EOI", twoBytesHexString)
                puts "no length field"
                return false
            when "FFDA"
                print_and_update_marker_type("SOS", twoBytesHexString)
                return true
            when "FFDB"
                print_and_update_marker_type("DQT", twoBytesHexString)
                return true
            when "FFDC"
                print_and_update_marker_type("DNL", twoBytesHexString)
                return true
            when "FFDD"
                print_and_update_marker_type("DRI", twoBytesHexString)
                return true
            else ## 0xFFD0..0xFFD7
                print_and_update_marker_type("RST", twoBytesHexString)
                puts "no length field"
                return false
            end
        when /^FFE/
            print_and_update_marker_type("APP", twoBytesHexString)
            return true
        when "FFFE"
            print_and_update_marker_type("COM", twoBytesHexString)
            return true
        else
            print_and_update_marker_type("other marker or data", twoBytesHexString)
            return false
        end
        return false
    end

    def read_segment(jpegFile)
        byte = jpegFile.read(1)
        byte_hex_str = byte.unpack("H*").pop.upcase
        if byte_hex_str == "FF"
            @is_image_data =  false
            next_byte = jpegFile.read(1)
            next_byte_hex_str = next_byte.unpack("H*").pop.upcase
            two_bytes_hex_str = byte_hex_str + next_byte_hex_str
            if is_marker_with_length(two_bytes_hex_str) == true
                @segment_length = jpegFile.read(2).unpack("n").pop
                puts "Segment Length: #{@segment_length}"
                skipped = jpegFile.read(@segment_length - 2)
                @raw_length = @segment_length + 2
            else
                ## marker bytes only or NOT marker
                @raw_length = 2
            end
        else
            @is_image_data = true
            @raw_length = 1
            ## read until next 0xFF
            while byte_hex_str != "FF"
                byte = jpegFile.read(1)
                byte_hex_str = byte.unpack("H*").pop.upcase
                @raw_length += 1
            end
            ## seek 1-byte backward
            if jpegFile.seek(-1, IO::SEEK_CUR) == 0
                @raw_length -= 1
            else
                puts "WARNING: seek error"
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

File.open(INPUT_JPEG_PATH, "r") do |input_jpeg_file|
    ## reading and analyzing process
    segment_array = Array.new
    while input_jpeg_file.eof? == false
        segment = JpegSegment.new
        segment.read_segment(input_jpeg_file)
        segment_array << segment
    end
    #debug_print_segment_array(segment_array)

    ## writing process
    if OUTPUT_JPEG_PATH != nil
        if input_jpeg_file.seek(0, IO::SEEK_SET) != 0
            puts "WARNING: seek error"
        end
        File.open(OUTPUT_JPEG_PATH, "w") do |output_jpeg_file|
            segment_array.each do |segment|
                if segment.marker_hex_str =~ /^FFE/
                    puts "skipping APP marker/segment (#{segment.marker_hex_str})"
                    input_jpeg_file.seek(segment.raw_length, IO::SEEK_CUR)
                else
                    puts "writing segment..."
                    output_jpeg_file.write( input_jpeg_file.read(segment.raw_length) )
                end
            end
        end
    end
end

