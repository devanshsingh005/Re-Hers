require 'xcodeproj'

project_path = '/Users/admin/Documents/Re-Hers/Re-Hearse_v1.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "Targets:"
project.targets.each do |target|
  puts " - #{target.name}"
end

puts "\nGroups and Files:"
def print_group(group, prefix)
  group.groups.each do |subgroup|
    puts "#{prefix}📁 #{subgroup.name || subgroup.path}"
    print_group(subgroup, prefix + "  ")
  end
  group.files.each do |file|
    puts "#{prefix}📄 #{file.name || file.path}"
  end
end

print_group(project.main_group, "")
