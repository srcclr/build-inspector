
require_relative 'lib/build_inspector'
require_relative 'lib/configuration'
require_relative 'lib/evidence_collector'
require_relative 'lib/evidence_processor'
require_relative 'lib/printer'
require_relative 'lib/vagrant_whisperer'
require_relative 'lib/report_builder'

def run_inspector(options, repo_path)

  whisperer = VagrantWhisperer.new(verbose: options[:verbose])
  config = Configuration.new(options[:config], options[:package])

  if options[:only_process]
    evidence_path = options[:only_process]
    process_evidence(evidence_path, whisperer.ip_address, config.host_whitelist)
    exit 0
  end

  puts '****************************** [:] ******************************'
  puts '* Build Inspector - SRC:CLR - https://www.sourceclear.com/      *'
  puts '* Security for open-source code.                   *'
  puts '****************************** [:] ******************************'
  puts "\n"

  start_time = Time.now

  whisperer.up

  repo_name = nil
  if options[:is_url]
    repo_name = repo_path.split('/').last.chomp('.git')
  else
    repo_name = File.basename(repo_path)
    unless File.exists?(repo_path)
      puts "The repo path #{repo_path} does not exist. Did you mean to use --url ?"
      exit -1
    end
  end

  inspector = BuildInspector.new(
    whisperer: whisperer, repo_path: repo_path,
    is_url: options[:is_url], repo_branch: options[:branch],
    commands: config.commands, evidence_files: config.evidence_files
  )

  whisperer.snapshot
  inspector.inspect

  evidence_name = "evidence-#{repo_name}-#{Time.now.strftime('%Y%m%d%H%M%S')}"
  config_name = options[:config]
  collector = EvidenceCollector.new(whisperer: whisperer, evidence_name: evidence_name, config_name: config_name)
  puts Printer.yellowify('Collecting evidence ...')
  collector.collect
  whisperer.rollback if options[:rollback]

  processor = EvidenceProcessor.new(evidence_path: evidence_name,
                                    vagrant_ip: whisperer.ip_address,
                                    host_whitelist: config.host_whitelist)
  processor.process

  end_time = Time.now
  total_time = end_time - start_time
  puts Printer.yellowify("[:] Build inspector finished after #{total_time} seconds")

  ReportBuilder.build("#{evidence_name}/build-report.html", repo_path, repo_name, options, config, processor, start_time, end_time)
end
