require 'zip'

module Utils
  # Because "puts `cmd`" doesn't stream the output as it appears
  def self.exec_puts(command)
    IO.popen(command) do |f|
      puts f.gets until f.eof?
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
end
