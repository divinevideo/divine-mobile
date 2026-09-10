#!/usr/bin/env ruby
# ABOUTME: Raises generated Flutter Swift packages to Divine's iOS 16 floor.
# ABOUTME: Used by Xcode and Codemagic so Flutter-version changes cannot drift.

require 'rubygems'

MINIMUM_IOS_VERSION = Gem::Version.new('16.0')

abort('usage: ensure_ios_swift_package_floor.rb <Package.swift> [...]') if ARGV.empty?

ARGV.each do |path|
  contents = File.read(path)
  matched_platform = false
  updated = contents.gsub(/\.iOS\((?:"(\d+(?:\.\d+)*)"|\.v(\d+))\)/) do |declaration|
    matched_platform = true
    version = Gem::Version.new(Regexp.last_match(1) || Regexp.last_match(2))
    version < MINIMUM_IOS_VERSION ? '.iOS("16.0")' : declaration
  end

  unless matched_platform
    if updated.match?(/^\s*platforms:\s*\[/)
      abort("expected #{path} platforms block to declare an iOS target")
    end

    updated = updated.sub(
      /(let package = Package\(\n\s*name: "[^"]+",\n)/,
      "\\1    platforms: [\n        .iOS(\"16.0\")\n    ],\n",
    )
  end

  ios_match = updated.match(/\.iOS\((?:"(\d+(?:\.\d+)*)"|\.v(\d+))\)/)
  ios_version = ios_match && (ios_match[1] || ios_match[2])
  if ios_version.nil? || Gem::Version.new(ios_version) < MINIMUM_IOS_VERSION
    abort("expected #{path} to target iOS 16.0 or newer")
  end

  if updated == contents
    puts "#{path} already targets iOS #{ios_version}"
    next
  end

  File.write(path, updated)
  puts "raised #{path} to iOS 16.0"
end
