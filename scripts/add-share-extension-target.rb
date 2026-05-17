#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Adds a "ShareExtension" Xcode target to ios/App/App.xcodeproj.
#
# Run via the Ruby that ships inside Homebrew CocoaPods, which bundles the
# `xcodeproj` gem we depend on:
#
#   /opt/homebrew/Cellar/cocoapods/*/libexec/bin/ruby \
#     scripts/add-share-extension-target.rb
#
# Idempotent — safe to re-run; if the target already exists the script
# exits without modifying the project.

require "xcodeproj"

PROJECT_PATH = File.expand_path("../ios/App/App.xcodeproj", __dir__)
EXT_NAME      = "ShareExtension"
EXT_DIR_REL   = "Extensions/Share"
SRC_FILE      = "ShareViewController.swift"
INFO_PLIST    = "Info.plist"
ENTITLEMENTS  = "App/Entitlements/ShareExtension.entitlements"
BUNDLE_ID     = "com.gemscan.app.ShareExtension"
DEPLOY_TARGET = "17.0"
SWIFT_VERSION = "5.0"
DEV_TEAM      = "46572WJX33"

project = Xcodeproj::Project.open(PROJECT_PATH)

if project.targets.find { |t| t.name == EXT_NAME }
  puts "Target '#{EXT_NAME}' already exists — nothing to do."
  exit 0
end

app_target = project.targets.find { |t| t.name == "App" } \
  or abort "Could not find 'App' target in project"

# --- Target ----------------------------------------------------------------
ext_target = project.new_target(
  :app_extension,
  EXT_NAME,
  :ios,
  DEPLOY_TARGET
)

# Strip the empty Sources phase the helper adds and rebuild it explicitly
# so we control which files go in.
ext_target.source_build_phase.clear
ext_target.resources_build_phase.clear

# --- File references -------------------------------------------------------
# Group under the main project group, mirroring the on-disk layout
# (ios/App/Extensions/Share/).
extensions_group = project.main_group.find_subpath("Extensions", true)
extensions_group.set_source_tree("<group>")
share_group = extensions_group.find_subpath("Share", true)
share_group.set_source_tree("<group>")
share_group.set_path("Extensions/Share")

source_ref = share_group.find_file_by_path(SRC_FILE) \
  || share_group.new_reference(SRC_FILE)
info_ref = share_group.find_file_by_path(INFO_PLIST) \
  || share_group.new_reference(INFO_PLIST)

# Compile the Swift source.
ext_target.add_file_references([source_ref])

# Embed the extension product (.appex) into the app's PlugIns folder.
embed_phase = app_target.copy_files_build_phases.find { |p| p.name == "Embed Foundation Extensions" }
unless embed_phase
  embed_phase = app_target.new_copy_files_build_phase("Embed Foundation Extensions")
  embed_phase.symbol_dst_subfolder_spec = :plug_ins
  embed_phase.run_only_for_deployment_postprocessing = "0"
end
ext_product_ref = ext_target.product_reference
build_file = embed_phase.add_file_reference(ext_product_ref)
build_file.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }

# Make the app depend on the extension so it builds first.
app_target.add_dependency(ext_target)

# --- Build settings --------------------------------------------------------
ext_target.build_configurations.each do |config|
  s = config.build_settings
  s["PRODUCT_BUNDLE_IDENTIFIER"]      = BUNDLE_ID
  s["PRODUCT_NAME"]                   = "$(TARGET_NAME)"
  s["INFOPLIST_FILE"]                 = "#{EXT_DIR_REL}/#{INFO_PLIST}"
  s["CODE_SIGN_ENTITLEMENTS"]         = ENTITLEMENTS
  s["CODE_SIGN_STYLE"]                = "Automatic"
  s["DEVELOPMENT_TEAM"]               = DEV_TEAM
  s["IPHONEOS_DEPLOYMENT_TARGET"]     = DEPLOY_TARGET
  s["SWIFT_VERSION"]                  = SWIFT_VERSION
  s["TARGETED_DEVICE_FAMILY"]         = "1,2"
  s["SKIP_INSTALL"]                   = "YES"
  s["LD_RUNPATH_SEARCH_PATHS"]        = "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks"
  s["CURRENT_PROJECT_VERSION"]        = "1"
  s["MARKETING_VERSION"]              = "1.0"
  # Match the main app's Swift / generation defaults so the extension
  # doesn't inherit Pods config that assumes app-level capabilities.
  s["SWIFT_OPTIMIZATION_LEVEL"]       = config.name == "Debug" ? "-Onone" : "-O"
  s["GCC_PREPROCESSOR_DEFINITIONS"]   = config.name == "Debug" ? ["DEBUG=1", "$(inherited)"] : ["$(inherited)"]
  s["GENERATE_INFOPLIST_FILE"]        = "NO"
end

project.save
puts "Added target '#{EXT_NAME}' (#{BUNDLE_ID}) with #{SRC_FILE}."
