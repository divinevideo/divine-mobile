#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'optparse'
require 'tempfile'

options = {}
OptionParser.new do |parser|
  parser.on('--output PATH') { |path| options[:output] = path }
  parser.on('--required') { options[:required] = true }
end.parse!
abort('ERROR: --output is required') unless options[:output]
invite = ENV.fetch('CONCORD_INVITE_URL', '')
if invite.empty?
  abort('ERROR: CONCORD_INVITE_URL is required by the original release') if options[:required]
  # Absence is part of the original release configuration, not an empty define.
  exit 0
end

# Validate with the same protocol decoder used by the app, without putting
# invitation material in arguments or command output.
validator = File.join(__dir__, 'validate_concord_release.dart')
packages = File.expand_path('../.dart_tool/package_config.json', __dir__)
unless system('dart', "--packages=#{packages}", validator, out: File::NULL, err: File::NULL)
  abort('ERROR: invalid CONCORD_INVITE_URL or CONCORD_RELAY_URL')
end

begin
  defines = JSON.parse(File.read(options[:output]))
rescue Errno::ENOENT, JSON::ParserError
  abort('ERROR: release dart-defines file is missing or invalid JSON')
end
abort('ERROR: release dart-defines must be an object') unless defines.is_a?(Hash)
defines['CONCORD_INVITE_URL'] = invite
defines['CONCORD_RELAY_URL'] = ENV.fetch('CONCORD_RELAY_URL')

# Preserve required defines and replace atomically with a private file. Neither
# the invitation nor existing credentials belong in command arguments or logs.
Tempfile.create(['concord-defines-', '.json'], File.dirname(options[:output])) do |file|
  file.chmod(0o600)
  file.write(JSON.pretty_generate(defines) + "\n")
  file.close
  File.rename(file.path, options[:output])
end
