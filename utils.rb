require 'zip'
require 'rainbow'
require 'open3'

module Utils
  # Because "puts `cmd`" doesn't stream the output as it appears
  def self.exec_puts(command)
    Open3.popen3(command) do |stdin, stdout, stderr, thread|
      # read each stream from a new thread
      { :out => stdout, :err => stderr }.each do |type, stream|
        Thread.new do
          until (line = stream.gets).nil? do
            case type
            when :out
              puts "==> inspector: #{line}"
            when :err
              print "==> inspector: #{Rainbow(line).red}"
            end
          end
        end
      end
      thread.join
    end
  end

  def self.timestamp
    Time.now.strftime('%Y%m%d%H%M%S')
  end

  def self.unzip(zipfile, destination)
    Zip::File.open(zipfile) do |zip|
      zip.each do |entry|
        path = File.join(destination, entry.name)
        FileUtils.mkdir_p(File.dirname(path))
        entry.extract(path) { true } # overwrites by default
      end
    end
  end

  def self.yellowify(text)
    Rainbow(text).yellow.bright
  end

  def self.yell(text)
    "echo #{yellowify(text)}"
  end
end
