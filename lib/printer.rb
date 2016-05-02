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

require 'open3'
require 'rainbow'

module Printer
  # Because "puts `cmd`" doesn't stream the output as it appears
  def self.exec_puts(command)
    Open3.popen3(command) do |stdin, stdout, stderr, thread|
      # read each stream from a new thread
      { out: stdout, err: stderr }.each do |type, stream|
        Thread.new do
          until (line = stream.gets).nil? do
            case type
            when :out
              puts "==> inspector: #{line}"
            when :err
              print "==> inspector: #{Rainbow(line).red}"
            end
          end
        end
      end
      thread.join
    end
  end

  def self.yellowify(text)
    Rainbow(text).yellow.bright
  end

  def self.yell(text)
    "echo #{yellowify(text)}"
  end
end
