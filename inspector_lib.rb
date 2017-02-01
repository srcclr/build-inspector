
require_relative 'lib/build_inspector'
require_relative 'lib/configuration'
require_relative 'lib/evidence_collector'
require_relative 'lib/evidence_processor'
require_relative 'lib/printer'
require_relative 'lib/vagrant_whisperer'
require_relative 'lib/report_builder'
require_relative 'lib/build_inspector_s3'


def run_inspector(options, repo_path=nil)
  config_file = options[:config]

  if !File.file?(config_file)
    puts "Config file not found. Please ensure that #{options[:config]} exists."
    exit 1
  end

  whisperer = VagrantWhisperer.new(verbose: options[:verbose])
  config = Configuration.new(config_file, options[:package])

  if options[:s3]
    process_s3(options, whisperer.ip_address, config, repo_path)
  elsif options[:only_process]
    only_process(options, whisperer.ip_address, config, repo_path)
  else
    collect_evidence_and_build_report(options, repo_path, whisperer, config)
  end
end


private

def print_header
  puts '****************************** [:] ******************************'
  puts '* Build Inspector - SRC:CLR - https://www.sourceclear.com/      *'
  puts '* Security for open-source code.                   *'
  puts '****************************** [:] ******************************'
  puts "\n"
end


def process_s3(options, ip_address, config, repo_path)
  b = BuildInspectorS3.new(options[:results], options[:script])
  b.get_evidences.each do |evidence|
    b.download(evidence)
    options[:only_process] = b.downloads_folder(evidence)
    only_process(options, ip_address, config, repo_path)
    File.delete(b.downloads_folder(evidence))
  end
end


def only_process(options, vagrant_ip, config, repo_path=nil)
  start_time = Time.now
  zipped_evidence_path = options[:only_process]
  evidence_path = zipped_evidence_path.sub(/(.*)\.zip/, '\1')
  EvidenceCollector.unzip(zipped_evidence_path, "#{evidence_path}")

  # evidence_name = "#{evidence_path}/evidence"
  should_cleanup = true

  print_header

  processor = EvidenceProcessor.new(evidence_path: evidence_path,
                                    vagrant_ip: vagrant_ip,
                                    host_whitelist: config.host_whitelist)

  if options[:script] and options[:script] != ''
    should_cleanup = !processor.process_evidence(options[:script], options[:package_manager])
  else
    processor.process
  end

  end_time = Time.now
  total_time = end_time - start_time
  puts Printer.yellowify("[:] Build inspector finished after #{total_time} seconds")

  FileUtils.rm_rf(evidence_path, :secure=>true) if should_cleanup
end


def collect_evidence_and_build_report(options, repo_path=nil, whisperer, config)
  print_header
  start_time = Time.now
  whisperer.up

  if options[:package]
    repo_name = options[:package]
  elsif options[:is_url]
    repo_name = repo_path.split('/').last.chomp('.git')
  else
    repo_name = File.basename(repo_path)
    unless File.exists?(repo_path)
      puts "The repo path #{repo_path} does not exist. Did you mean to use --url ?"
      exit -1
    end
  end

  inspector = BuildInspector.new(
      whisperer: whisperer, repo_path: repo_path, package: options[:package],
      is_url: options[:is_url], repo_branch: options[:branch],
      commands: config.commands, evidence_files: config.evidence_files
  )

  whisperer.snapshot
  inspector.inspect

  evidence_file_name = "#{options[:package_manager]}-#{repo_name}"
  evidence_name = "evidence-#{evidence_file_name}-#{Time.now.strftime('%Y%m%d%H%M%S')}"

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