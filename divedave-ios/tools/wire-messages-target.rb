#!/usr/bin/env ruby
require "xcodeproj"

PROJECT_PATH = File.expand_path("../divedave.xcodeproj", __dir__)
SHARED_GROUP = "divedave Shared"
MESSAGES_GROUP = "divedave Messages"

project = Xcodeproj::Project.open(PROJECT_PATH)

ios = project.targets.find { |t| t.name == "divedave iOS" } or abort("missing iOS target")
msg = project.targets.find { |t| t.name == "divedave Messages" } or abort("missing Messages target")

def find_group(parent, name)
  parent.groups.find { |g| g.display_name == name || g.path == name || g.name == name }
end

def descend(root, *names)
  names.reduce(root) { |g, n| find_group(g, n) or abort("missing group: #{n}") }
end

shared = descend(project.main_group, SHARED_GROUP)
msg_group = find_group(project.main_group, MESSAGES_GROUP) || project.main_group.new_group(MESSAGES_GROUP, MESSAGES_GROUP)

# 1) ChallengeState.swift -> Shared/Util, both targets
util = descend(shared, "Util")
unless util.files.any? { |f| f.path == "ChallengeState.swift" }
  ref = util.new_file("ChallengeState.swift")
  ios.add_file_references([ref])
  msg.add_file_references([ref])
  puts "added ChallengeState.swift to Util/ on both targets"
end

# 2) MessagesViewController.swift -> divedave Messages, Messages target only
unless msg_group.files.any? { |f| f.path == "MessagesViewController.swift" }
  ref = msg_group.new_file("MessagesViewController.swift")
  msg.add_file_references([ref])
  puts "added MessagesViewController.swift to divedave Messages group on Messages target"
end

# 3) Every file under Shared -> add Messages target membership if missing
msg_source_refs = msg.source_build_phase.files.map(&:file_ref)
msg_resource_refs = msg.resources_build_phase.files.map(&:file_ref)

added_sources = 0
added_resources = 0

shared.recursive_children.each do |child|
  next unless child.is_a?(Xcodeproj::Project::Object::PBXFileReference)
  path = child.path.to_s
  if path.end_with?(".swift")
    next if msg_source_refs.include?(child)
    msg.add_file_references([child])
    added_sources += 1
    puts "  + source: #{path}"
  elsif path.end_with?(".xcassets")
    next if msg_resource_refs.include?(child)
    msg.add_resources([child])
    added_resources += 1
    puts "  + resource: #{path}"
  end
end

project.save
puts "done — #{added_sources} sources, #{added_resources} resources added to Messages target"
