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

require 'erb'
require 'json'
require_relative 'build_inspector'

class ReportBuilder
  def self.build(output_file, repo_path, repo_name, options, config, processor, start_time, end_time)
    title = "Build Inspector Report - #{repo_name}"

    options_json = JSON.pretty_generate(options)
    config_json = JSON.pretty_generate(config.config)

    file_changes = processor.get_filesystem_changes * "\n"
    network_activity = processor.get_connections * "\n"
    insecure_network_activity = processor.get_insecure_connections * "\n"
    running_processes = processor.get_running_processes * "\n"
    executed_commands = processor.get_processes * "\n"
    all_commands = processor.get_unfiltered_processes * "\n"

    template = IO.read("#{File.dirname(__FILE__)}/report_template.html.erb")
    renderer = ERB.new(template)
    output = renderer.result(binding)
    File.open(output_file, 'w') { |f| f.write(output) }
  end
end
