require 'zip'

module Utils
  def timestamp
    Time.now.strftime('%Y%m%d%H%M%S')
  end

  def unzip(zipfile, destination)
    Zip::File.open(zipfile) do |zip|
      zip.each do |entry|
        path = File.join(destination, entry.name)
        FileUtils.mkdir_p(File.dirname(path))
        entry.extract(path) { true } # overwrites by default
      end
    end
  end
end
