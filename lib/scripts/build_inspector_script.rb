class BuildInspectorScript

  def initialize(evidence_path:, package_manager:)
    @evidence_path = evidence_path
    @package_manager = package_manager || ''
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
    payload = {'script': script_name,
               'version': version,
               'package_manager': @package_manager,
               'file_analyzed': @file_to_analyze,
               'results': results}
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