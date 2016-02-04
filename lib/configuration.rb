require 'yaml'

class Configuration
  def initialize(config = '.inspect.yml')
    @config = YAML.load_file(config) if File.exist?(config)
    @config ||= {}
    @config['evidence_files'] ||= {}
    @excluded = @config['evidence_files'].fetch('exclude', [])
    @included = @config['evidence_files'].fetch('include', [])
  end

  def method_missing(sym, *args, &block)
    @config[sym.to_s]
  end

  # Returns evidence_files configuration as a string in
  # rdiff-backup's --include-filelist format
  def evidence_files
    @excluded.map { |x| "- #{x}" }
             .concat(@included)
             .join("\n")
  end
end
