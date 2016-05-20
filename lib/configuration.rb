=begin
Copyright 2016 SourceClear Inc

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
=end

require 'yaml'

class Configuration
  attr_reader :config

  def initialize(config = 'config.yml')
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
    @excluded.map { |x| "- #{x}" }.concat(@included) * "\n"
  end
end
