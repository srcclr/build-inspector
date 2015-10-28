require 'celluloid'
require 'sys/proctable'
require 'yaml'
class GetProcessesJob
  include Celluloid
  include Sys
  def start
    old_value = ProcTable.ps.map(&:cmdline)
    new_value = []
    every(0.01) do
      new_value = ProcTable.ps.map(&:cmdline)
      if !((new_value - old_value).empty?)
        File.open("/evidence/ps/#{Time.now.strftime('%Y%m%d%H%M%S')}-ps", 'w') do |f|
          puts 'Writing ...'
          f.write((new_value - old_value).to_yaml)
        end
        old_value = new_value
      end
    end
  end
end
job = GetProcessesJob.new
job.start
`mkdir /evidence/ps/`
# hack to ensure the script doesn't quit
loop {}
