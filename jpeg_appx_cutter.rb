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

    def print_and_update_marker_type(markerTypeString, twoBytesInteger)
        @marker_hex_str = twoBytesInteger.to_s(16).upcase
        puts "found #{markerTypeString} (0x#{@marker_hex_str})"
    end

    def is_marker_with_length(twoBytesInteger)
        case twoBytesInteger
        ## 0xFFC
        when 0xFFC0..0xFFC3, 0xFFC5..0xFFC7, 0xFFC9..0xFFCB, 0xFFCD..0xFFCF
            print_and_update_marker_type("SOF", twoBytesInteger)
            return true
        when 0xFFC4
            print_and_update_marker_type("DHT", twoBytesInteger)
            return true
        ## 0xFFD
        when 0xFFD0..0xFFD7
            print_and_update_marker_type("RST", twoBytesInteger)
            puts "no length field"
            return false
        when 0xFFD8
            print_and_update_marker_type("SOI", twoBytesInteger)
            puts "no length field"
            return false
        when 0xFFD9
            print_and_update_marker_type("EOI", twoBytesInteger)
            puts "no length field"
            return false
        when 0xFFDA
            print_and_update_marker_type("SOS", twoBytesInteger)
            return true
        when 0xFFDB
            print_and_update_marker_type("DQT", twoBytesInteger)
            return true
        when 0xFFDC
            print_and_update_marker_type("DNL", twoBytesInteger)
            return true
        when 0xFFDD
            print_and_update_marker_type("DRI", twoBytesInteger)
            return true
        ## 0xFFE
        when 0xFFE0..0xFFEF
            print_and_update_marker_type("APP", twoBytesInteger)
            return true
        ## 0xFFF
        when 0xFFFE
            print_and_update_marker_type("COM", twoBytesInteger)
            return true
        ## others
        else
            print_and_update_marker_type("other marker or data", twoBytesInteger)
            return false
        end
        return false
    end

    def seek_one_byte_backward(jpegFile)
        ## seek 1-byte backward
        if jpegFile.seek(-1, IO::SEEK_CUR) == 0
            @raw_length -= 1
        else
            puts "WARNING: seek error"
        end
    end

    def read_segment(jpegFile)
        byte_integer = jpegFile.read(1).unpack("C").pop
        if byte_integer == 0xFF
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
                    @raw_length = 2
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

