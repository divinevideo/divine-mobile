#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'

json_path, candidate_version = ARGV
unless json_path && candidate_version
  abort('usage: ios_store_version_preflight.rb <app-store-versions-json> <candidate-version>')
end

# App Store states in which a version has been released, is approved and
# awaiting release, or was previously released. A version in any of these has
# been taken by App Store Connect, so a new build cannot be attached to it and
# a Shorebird release for it would be rejected after the build.
#
# ACCEPTED means App Review passed this version while a sibling item in the
# same submission is still outstanding, so the version string is already taken
# even though it is not yet distributing.
#
# Deliberately excluded: PREPARE_FOR_SUBMISSION, READY_FOR_REVIEW,
# WAITING_FOR_REVIEW, IN_REVIEW, REJECTED, DEVELOPER_REJECTED,
# METADATA_REJECTED, INVALID_BINARY and WAITING_FOR_EXPORT_COMPLIANCE. A
# version in one of those states has never been released, so reusing it is
# valid and must not block a release.
# NOT_APPLICABLE is also deliberately excluded from the legacy appStoreState
# fallback because it does not represent a version that has claimed a release
# train.
#
# appVersionState is the current App Store Connect field; appStoreState is the
# deprecated spelling that older API responses still carry.
TAKEN_STATES = %w[
  ACCEPTED
  READY_FOR_DISTRIBUTION
  PROCESSING_FOR_DISTRIBUTION
  PENDING_APPLE_RELEASE
  PENDING_DEVELOPER_RELEASE
  REPLACED_WITH_NEW_VERSION
  READY_FOR_SALE
  PROCESSING_FOR_APP_STORE
  REMOVED_FROM_SALE
  DEVELOPER_REMOVED_FROM_SALE
  PREORDER_READY_FOR_SALE
  PENDING_CONTRACT
].freeze

def numeric_version(value, label)
  unless value.is_a?(String) && value.match?(/\A\d+(?:\.\d+){0,2}\z/)
    abort("ERROR: invalid #{label} #{value.inspect}; expected one to three numeric components.")
  end

  value.split('.').map(&:to_i).fill(0, value.count('.') + 1...3)
end

payload = JSON.parse(File.read(json_path))
unless payload.is_a?(Array)
  abort('ERROR: expected a JSON array of App Store versions from App Store Connect.')
end

if payload.empty?
  abort(
    'ERROR: App Store Connect returned no App Store versions for this app. ' \
    'Refusing to treat an empty lookup as a first release.',
  )
end

taken_versions = payload.filter_map do |resource|
  next unless resource.is_a?(Hash)

  attributes = resource['attributes']
  next unless attributes.is_a?(Hash)

  state = attributes['appVersionState'] || attributes['appStoreState']
  next unless TAKEN_STATES.include?(state)

  attributes['versionString']
end

if taken_versions.empty?
  puts "No taken App Store version found; #{candidate_version} is the first release on this train."
  exit 0
end

taken_version = taken_versions.max_by { |version| numeric_version(version, 'App Store version') }

candidate_parts = numeric_version(candidate_version, 'candidate version')
taken_parts = numeric_version(taken_version, 'taken App Store version')

unless (candidate_parts <=> taken_parts) == 1
  abort(
    "ERROR: candidate version #{candidate_version} must be newer than taken App Store version " \
    "#{taken_version}. Bump mobile/pubspec.yaml before cutting a Shorebird release.",
  )
end

puts "Candidate version #{candidate_version} is newer than taken App Store version #{taken_version}."
