require 'xcodeproj'

project_path = '/Users/admin/Documents/Re-Hers/Re-Hearse_v1.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group = project.main_group.find_subpath('Models', true)
file_path = '/Users/admin/Documents/Re-Hers/Models/Song.swift'

file_ref = group.new_file(file_path)
target.add_file_references([file_ref])

project.save
puts "Successfully added Song.swift to target #{target.name}"
