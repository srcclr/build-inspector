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

class BuildInspectorScript

  def initialize(evidence_path:, package_manager:, host_whitelist:)
    @evidence_path = evidence_path
    @package_manager = package_manager || ''
    @host_whitelist = host_whitelist
    @file_to_analyze = analysis_file_name
    @results = load_results
  end

  def run
  end

  def version
    '0'
  end


  private

  def add_results(results)
    positive = (results and !results.empty?)
    payload = {'script': script_name,
               'version': version,
               'package_manager': @package_manager,
               'file_analyzed': @file_to_analyze,
               'results': results,
               'positive': positive}
    @results[@evidence_path] = payload
  end

  def load_results
    {}
  end

  def save_results
  end

  def script_name
    self.class.name
  end

  def analysis_file_name
    ''
  end

  def self.template_file_name
    'build_inspector_template.html.erb'
  end

  def self.results_file_name
    'build_inspector_results.json'
  end

end