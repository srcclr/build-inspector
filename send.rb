require 'bunny'
require 'json'

SUPPORTED_LIBRARY_TYPES = %w(npm gem)

conn = Bunny.new
conn.start
@ch = conn.create_channel
q = ch.queue('build-inspector-repos')


def generate_payload(type, library)
  return { type: type, library: library }
end

def load_libraries(type)
  libraries_folder = './libraries/'
  libraries_extension = '.csv'
  libraries_file = "#{libraries_folder}#{type}#{libraries_extension}"
  @loaded_libraries ||= []
  @loaded_libraries = File.readlines(libraries_file)
end

def send(payload)
  @ch.default_exchange.publish(payload.to_json, :routing_key => q.name)
  puts " [x] Sent '#{payload.to_json}'"
end

def send_all
  SUPPORTED_LIBRARY_TYPES.each do |type|
    load_libraries(type)
    @loaded_libraries.each do |library|
      payload = generate_payload(type, library.strip)
      send(payload)
    end
  end
end

send_all
conn.close