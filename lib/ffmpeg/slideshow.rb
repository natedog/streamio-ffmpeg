

module FFMPEG
  class Slideshow
    def initialize(imagedirectory, output_file, number_of_frames, options = EncodingOptions.new, transcoder_options = {})
      @imagedirectory = imagedirectory
      @output_file = output_file
      @number_of_frames = number_of_frames
      
      if options.is_a?(String) || options.is_a?(EncodingOptions)
        @raw_options = options
      elsif options.is_a?(Hash)
        @raw_options = EncodingOptions.new(options)
      else
        raise ArgumentError, "Unknown options format '#{options.class}', should be either EncodingOptions, Hash or String."
      end
      
      @transcoder_options = transcoder_options
      @errors = []
      
      #apply_transcoder_options
    end
    
    # ffmpeg -f image2 -i public/images/frame_%d.jpg -sameq  test.mpg
    
    # ffmpeg <  0.8: frame=  413 fps= 48 q=31.0 size=    2139kB time=16.52 bitrate=1060.6kbits/s
    # ffmpeg >= 0.8: frame= 4855 fps= 46 q=31.0 size=   45306kB time=00:02:42.28 bitrate=2287.0kbits/
    
    # ffmpeg version 0.9 : frame=   48 fps= 22 q=2.0 Lsize=    3648kB time=00:00:01.88 bitrate=15896.0kbits/s    
    # ffmpeg version 0.9: video:3633kB audio:0kB global headers:0kB muxing overhead 0.405811%
    
    
    def run
      #command = "#{FFMPEG.ffmpeg_binary} -y -i #{Shellwords.escape(@movie.path)} #{@raw_options} #{Shellwords.escape(@output_file)}"
      command = "#{FFMPEG.ffmpeg_binary} -f image2 -i #{Shellwords.escape(@imagedirectory)}%d.jpg -sameq  -y #{@raw_options} #{Shellwords.escape(@output_file)}"
      
      FFMPEG.logger.info("Running transcoding...\n#{command}\n")
      output = ""
      last_output = nil
      Open3.popen3(command) do |stdin, stdout, stderr|
        yield(0) if block_given?
        stderr.each("r") do |line|
          fix_encoding(line)
          output << line
          if line.include?("frame=")
            if line =~ /frame=(\d+)/
               frame = $1.to_i
              else
               frame = 1
              end
            progress = frame / number_of_frames
            yield(progress) if block_given?  
          #output << line
          #if line.include?("time=")
          #  if line =~ /time=(\d+):(\d+):(\d+.\d+)/ # ffmpeg 0.8 and above style
          #    time = ($1.to_i * 3600) + ($2.to_i * 60) + $3.to_f
          #  elsif line =~ /time=(\d+.\d+)/ # ffmpeg 0.7 and below style
          #    time = $1.to_f
          #  else # better make sure it wont blow up in case of unexpected output
          #    time = 0.0
          #  end
          #  progress = time / 1#@movie.duration
          #  yield(progress) if block_given?
          end
          if line =~ /Unsupported codec/
            FFMPEG.logger.error "Failed encoding...\nCommand\n#{command}\nOutput\n#{output}\n"
            raise "Failed encoding: #{line}"
          end
        end
      end

      if encoding_succeeded?
        yield(1) if block_given?
        FFMPEG.logger.info "Transcoding of #{@imagedirectory} to #{@output_file} succeeded\n"
      else
        errors = @errors.empty? ? "" : " Errors: #{@errors.join(", ")}. "
        FFMPEG.logger.error "Failed encoding...\n#{command}\n\n#{output}\n#{errors}\n"
        raise "Failed encoding.#{errors}Full output: #{output}"
      end
      
      encoded
    end
    
    def encoding_succeeded?
      unless File.exists?(@output_file)
        @errors << "no output file created"
        return false
      end
      
      unless encoded.valid?
        @errors << "encoded file is invalid"
        return false
      end
      
      
      true
    end
    
    def encoded
      @encoded ||= Movie.new(@output_file)
    end
    
    def fix_encoding(output)
      output[/test/]
    rescue ArgumentError
      output.force_encoding("ISO-8859-1")
    end
    
 
  end
end
