#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'openssl'
require 'optparse'
require 'open3'

SCHEMA_VERSION = 1
HEX_SHA = /\A[0-9a-f]{40}\z/
PUBLIC_PEOPLE_LIST_POLICY = 'DIVINE_PUBLIC_PEOPLE_LIST_EXCLUDED_D_TAGS'

def abort_with(message)
  warn("ERROR: #{message}")
  exit 1
end

def read_json(path, description)
  JSON.parse(File.read(path))
rescue Errno::ENOENT
  abort_with("#{description} is missing")
rescue JSON::ParserError => error
  abort_with("#{description} is malformed: #{error.message}")
end

def required_env(name)
  value = ENV.fetch(name, '')
  abort_with("#{name} is required") if value.empty?

  value
end

def fingerprint_key
  key = required_env('SHOREBIRD_PROVENANCE_HMAC_KEY')
  abort_with('SHOREBIRD_PROVENANCE_HMAC_KEY must contain at least 32 bytes') if key.bytesize < 32

  key
end

PUBLIC_KEY_PEM = /\A-----BEGIN PUBLIC KEY-----\n.+\n-----END PUBLIC KEY-----\z/m
SHA256_HEX = /\A[0-9a-f]{64}\z/

# Digest of the patch-signing public key baked into the release binary.
#
# Shorebird verifies a patch signature on-device against the key linked into
# the release, so a rotated key produces patches the installed app silently
# refuses. This is a plain digest, not the keyed fingerprint used for
# dart-defines: the key is public, and a digest anyone can recompute from the
# PEM is what makes the mismatch diagnosable.
def patch_public_key_digest
  pem = required_env('SHOREBIRD_PATCH_PUBLIC_KEY').gsub('\\n', "\n").strip
  abort_with('SHOREBIRD_PATCH_PUBLIC_KEY is not a public-key PEM') unless pem.match?(PUBLIC_KEY_PEM)

  OpenSSL::Digest::SHA256.hexdigest(pem)
end

def fingerprints(defines, key)
  defines.sort.to_h do |name, value|
    abort_with("dart-define #{name} must be a string") unless value.is_a?(String)

    payload = "shorebird-provenance-v#{SCHEMA_VERSION}\0#{name}\0#{value}"
    [name, OpenSSL::HMAC.hexdigest('SHA256', key, payload)]
  end
end

def canonical_json(value)
  case value
  when Hash
    '{' + value.keys.sort.map { |key| "#{JSON.generate(key)}:#{canonical_json(value.fetch(key))}" }.join(',') + '}'
  when Array
    '[' + value.map { |item| canonical_json(item) }.join(',') + ']'
  else
    JSON.generate(value)
  end
end

def record_hmac(record, key)
  OpenSSL::HMAC.hexdigest('SHA256', key, canonical_json(record.reject { |name, _| name == 'record_hmac' }))
end

def secure_compare(left, right)
  return false unless left.is_a?(String) && left.bytesize == right.bytesize

  difference = 0
  left.bytes.zip(right.bytes) { |left_byte, right_byte| difference |= left_byte ^ right_byte }
  difference.zero?
end

def git(*arguments)
  stdout, stderr, status = Open3.capture3('git', *arguments)
  abort_with("git #{arguments.join(' ')} failed: #{stderr.strip}") unless status.success?

  stdout.strip
end

def parse_options(arguments)
  options = {}
  parser = OptionParser.new do |opts|
    opts.on('--platform VALUE') { |value| options[:platform] = value }
    opts.on('--release-version VALUE') { |value| options[:release_version] = value }
    opts.on('--source-commit VALUE') { |value| options[:source_commit] = value }
    opts.on('--patch-baseline-commit VALUE') { |value| options[:patch_baseline_commit] = value }
    opts.on('--flutter-version VALUE') { |value| options[:flutter_version] = value }
    opts.on('--shorebird-cli-version VALUE') { |value| options[:shorebird_cli_version] = value }
    opts.on('--shorebird-cli-revision VALUE') { |value| options[:shorebird_cli_revision] = value }
    opts.on('--defines PATH') { |value| options[:defines] = value }
    opts.on('--record PATH') { |value| options[:record] = value }
    opts.on('--output PATH') { |value| options[:output] = value }
    opts.on('--env-output PATH') { |value| options[:env_output] = value }
    opts.on('--release-commit VALUE') { |value| options[:release_commit] = value }
  end
  parser.parse!(arguments)
  options
end

def require_options(options, *names)
  missing = names.select { |name| options.fetch(name, '').empty? }
  abort_with("missing option(s): #{missing.map { |name| "--#{name.to_s.tr('_', '-')}" }.join(', ')}") unless missing.empty?
end

def authenticated_record(options)
  record = read_json(options[:record], 'release provenance')
  abort_with('release provenance must contain a JSON object') unless record.is_a?(Hash)
  abort_with('unsupported release provenance schema') unless record['schema_version'] == SCHEMA_VERSION
  abort_with('release provenance platform does not match the requested platform') unless record['platform'] == options[:platform]
  abort_with('release provenance version does not match the requested release') unless record['release_version'] == options[:release_version]
  abort_with('target release is not patchable because verified release configuration is unavailable') unless record['patchable'] == true

  current_key_id = required_env('SHOREBIRD_PROVENANCE_HMAC_KEY_ID')
  abort_with('release provenance uses a different configuration fingerprint key') unless record['config_fingerprint_key_id'] == current_key_id
  expected_record_hmac = record['record_hmac']
  calculated_record_hmac = record_hmac(record, fingerprint_key)
  unless secure_compare(expected_record_hmac, calculated_record_hmac)
    abort_with('release provenance authentication failed')
  end

  abort_with('release provenance config_fingerprints is invalid') unless record['config_fingerprints'].is_a?(Hash)
  record
end

command = ARGV.shift
options = parse_options(ARGV)

case command
when 'emit'
  require_options(
    options,
    :platform,
    :release_version,
    :source_commit,
    :patch_baseline_commit,
    :flutter_version,
    :shorebird_cli_version,
    :shorebird_cli_revision,
    :defines,
    :output,
  )
  abort_with('platform must be android or ios') unless %w[android ios].include?(options[:platform])

  %i[source_commit patch_baseline_commit shorebird_cli_revision].each do |name|
    abort_with("#{name} must be a full lowercase commit SHA") unless options[name].match?(HEX_SHA)
  end

  source_tree_sha = git('rev-parse', "#{options[:source_commit]}^{tree}")
  baseline_tree_sha = git('rev-parse', "#{options[:patch_baseline_commit]}^{tree}")
  abort_with('patch baseline tree does not match the release source tree') unless source_tree_sha == baseline_tree_sha

  defines = read_json(options[:defines], 'dart-defines file')
  abort_with('dart-defines file must contain a JSON object') unless defines.is_a?(Hash)

  record = {
    'schema_version' => SCHEMA_VERSION,
    'platform' => options[:platform],
    'release_version' => options[:release_version],
    'build_source_commit' => options[:source_commit],
    'source_tree_sha' => source_tree_sha,
    'patch_baseline_commit' => options[:patch_baseline_commit],
    'flutter_version' => options[:flutter_version],
    'shorebird_cli_version' => options[:shorebird_cli_version],
    'shorebird_cli_revision' => options[:shorebird_cli_revision],
    'config_fingerprint_key_id' => required_env('SHOREBIRD_PROVENANCE_HMAC_KEY_ID'),
    'config_fingerprints' => fingerprints(defines, fingerprint_key),
    'patch_public_key_sha256' => patch_public_key_digest,
    'patchable' => true,
  }
  record['record_hmac'] = record_hmac(record, fingerprint_key)

  File.write(options[:output], JSON.pretty_generate(record) + "\n", mode: 'w', perm: 0o600)
when 'policy-required'
  require_options(options, :platform, :release_version, :record)
  # Preserve a legacy release's actual define shape, rather than forgiving an
  # extra key during verification. No unsigned record may select that shape.
  record = authenticated_record(options)
  puts record['config_fingerprints'].key?(PUBLIC_PEOPLE_LIST_POLICY)
when 'verify'
  require_options(
    options,
    :platform,
    :release_version,
    :flutter_version,
    :shorebird_cli_version,
    :shorebird_cli_revision,
    :defines,
    :record,
    :env_output,
  )
  record = authenticated_record(options)

  required_shas = %w[build_source_commit source_tree_sha patch_baseline_commit shorebird_cli_revision]
  required_shas.each do |name|
    abort_with("release provenance #{name} is invalid") unless record[name].is_a?(String) && record[name].match?(HEX_SHA)
  end
  abort_with('patch Flutter version does not match release provenance') unless record['flutter_version'] == options[:flutter_version]
  abort_with('patch Shorebird CLI version does not match release provenance') unless record['shorebird_cli_version'] == options[:shorebird_cli_version]
  abort_with('patch Shorebird CLI revision does not match release provenance') unless record['shorebird_cli_revision'] == options[:shorebird_cli_revision]

  recorded_key_digest = record['patch_public_key_sha256']
  if recorded_key_digest.nil?
    warn('NOTE: this release predates patch-signing-key binding; the signing key cannot be checked')
  else
    abort_with('release provenance patch_public_key_sha256 is invalid') unless recorded_key_digest.is_a?(String) && recorded_key_digest.match?(SHA256_HEX)
    unless secure_compare(recorded_key_digest, patch_public_key_digest)
      abort_with('patch signing key does not match the key this release was built with')
    end
  end

  recorded_fingerprints = record['config_fingerprints']

  defines = read_json(options[:defines], 'dart-defines file')
  abort_with('dart-defines file must contain a JSON object') unless defines.is_a?(Hash)
  current_fingerprints = fingerprints(defines, fingerprint_key)
  drifted_keys = (recorded_fingerprints.keys | current_fingerprints.keys).select do |name|
    recorded_fingerprints[name] != current_fingerprints[name]
  end.sort
  abort_with("release configuration drifted for: #{drifted_keys.join(', ')}") unless drifted_keys.empty?

  baseline = record['patch_baseline_commit']
  baseline_tree = git('rev-parse', "#{baseline}^{tree}")
  abort_with('recorded patch baseline tree does not match release provenance') unless baseline_tree == record['source_tree_sha']
  system('git', 'merge-base', '--is-ancestor', baseline, 'HEAD') || abort_with('recorded patch baseline is not an ancestor of the current checkout')

  override = options.fetch(:release_commit, '')
  unless override.empty?
    abort_with('RELEASE_COMMIT must be a full lowercase commit SHA') unless override.match?(HEX_SHA)
    override_tree = git('rev-parse', "#{override}^{tree}")
    allowed = [record['build_source_commit'], baseline].include?(override) || override_tree == record['source_tree_sha']
    abort_with('RELEASE_COMMIT does not match the recorded release source') unless allowed
  end

  File.write(options[:env_output], "SHOREBIRD_PATCH_BASELINE_COMMIT=#{baseline}\n", mode: 'w', perm: 0o600)
else
  abort_with('usage: shorebird_provenance.rb emit|policy-required|verify [options]')
end
