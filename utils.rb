require 'zip'
require 'rainbow'
require 'open3'

module Utils
  # Because "puts `cmd`" doesn't stream the output as it appears
  def self.exec_puts(command)
    #Open3.popen3(command) do |_, stdout, stderr, _|
    #  puts "==> inspector: #{stdout.gets}" until stdout.eof?
    #  print "==> inspector: #{Rainbow(stderr.gets).red}" until stderr.eof?
    #end
    stdout, stderr = Open3.capture3(command)
    stdout.each_line { |line| puts "==> inspector: #{line}" }
    stderr.each_line{ |line| print "==> inspector: #{Rainbow(line).red}" }
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
