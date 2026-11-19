#!/usr/bin/env bash
set -euo pipefail

PROJECT_FILE="${1:-ios/Runner.xcodeproj/project.pbxproj}"
EXPECTED_BUNDLE_IDS="${IOS_EXTENSION_BUNDLE_IDS:-}"

if [ -z "$EXPECTED_BUNDLE_IDS" ]; then
  echo "ERROR: IOS_EXTENSION_BUNDLE_IDS must list every signed iOS app-extension and Watch app bundle ID."
  exit 1
fi

ruby - "$PROJECT_FILE" "$EXPECTED_BUNDLE_IDS" <<'RUBY'
project_file, expected_raw = ARGV
project = File.read(project_file)

expected = expected_raw.split(/[,\s]+/).reject(&:empty?).sort
shipping_configurations = %w[Profile Release]

objects = project
  .scan(/^\t\t([A-Z0-9]+) \/\* ([^*]+) \*\/ = \{\n(.*?)^\t\t\};/m)
  .each_with_object({}) do |(id, name, body), result|
    result[id] = { name: name, body: body }
  end

# Runner embeds its app extensions and the Watch app, and each of them is
# signed with its own App Store profile. Runner is an application too, so an
# application counts only in configurations that build it for watchOS.
app_extension = 'com.apple.product-type.app-extension'
application = 'com.apple.product-type.application'

target_blocks = objects.each_with_object([]) do |(target_id, object), targets|
  body = object[:body]
  next unless body.include?('isa = PBXNativeTarget;')

  product_type = body.match(/productType = "([^"]+)";/)&.[](1)
  next unless [app_extension, application].include?(product_type)

  config_list_id = body.match(/buildConfigurationList = ([A-Z0-9]+) /)&.[](1)
  next unless config_list_id

  targets << [target_id, object[:name], config_list_id, product_type]
end

actual = target_blocks.flat_map do |_target_id, _target_name, config_list_id, product_type|
  config_list_body = objects[config_list_id]&.fetch(:body, nil)
  next [] unless config_list_body

  config_list_body
    .scan(/^\s*([A-Z0-9]+) \/\* ([^*]+) \*\//)
    .flat_map do |config_id, configuration|
      next [] unless shipping_configurations.include?(configuration.strip)

      config_body = objects[config_id]&.fetch(:body, nil)
      next [] unless config_body
      next [] if product_type == application && !config_body.include?('SDKROOT = watchos;')

      bundle_id = config_body.match(/PRODUCT_BUNDLE_IDENTIFIER = ([^;\n]+);/)&.[](1)
      next [] unless bundle_id

      bundle_id.delete('"')
    end
end.uniq.sort

if actual.empty?
  puts "ERROR: no iOS app-extension bundle IDs were found in #{project_file}."
  exit 1
end

missing = actual - expected
stale = expected - actual

unless missing.empty? && stale.empty?
  puts "ERROR: iOS extension signing bundle IDs are out of sync."
  puts "Expected from IOS_EXTENSION_BUNDLE_IDS: #{expected.join(', ')}"
  puts "Actual shipping app-extension and Watch app targets: #{actual.join(', ')}"
  puts "Missing from IOS_EXTENSION_BUNDLE_IDS: #{missing.join(', ')}" unless missing.empty?
  puts "No matching app-extension or Watch app target: #{stale.join(', ')}" unless stale.empty?
  puts "Every app extension and the Watch app also need a matching App Store provisioning profile in Codemagic Code signing identities."
  exit 1
end

puts "iOS shipping extension and Watch app bundle IDs are in sync: #{actual.join(', ')}"
RUBY
