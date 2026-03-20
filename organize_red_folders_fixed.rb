require 'xcodeproj'
require 'fileutils'

def find_group(parent_group, name_or_path, depth = 0)
  return nil if parent_group.nil?
  parent_group.groups.each do |g|
    return g if g.name == name_or_path || g.path == name_or_path
    found = find_group(g, name_or_path, depth + 1)
    return found if found
  end
  nil
end

def main
  project_path = '/Users/admin/Documents/Re-Hers/Re-Hearse_v1.xcodeproj'
  project = Xcodeproj::Project.open(project_path)
  
  target = project.targets.first
  base_dir = '/Users/admin/Documents/Re-Hers'
  screens_dir = File.join(base_dir, 'Screens')

  # 1. MainPlaylistScreen
  playlist_group = find_group(project.main_group, 'MainPlaylistScreen')
  if playlist_group
    playlist_dir = File.join(screens_dir, 'MainPlaylistScreen')
    FileUtils.mkdir_p(playlist_dir)
    ['MainPlayListScreen.swift', 'PlayListInside.swift'].each do |file|
      old_path = File.join(screens_dir, file)
      new_path = File.join(playlist_dir, file)
      if File.exist?(old_path)
        FileUtils.mv(old_path, new_path)
        puts "Moved #{file} to MainPlaylistScreen/"
        ref = playlist_group.files.find { |f| f.path == file || f.name == file }
        if ref
          ref.path = file
          ref.source_tree = '<group>'
        end
      end
    end
  end

  # 2. MainDiscoverScreen
  explore_group = find_group(project.main_group, 'MainDiscoverScreen')
  if explore_group
    explore_dir = File.join(screens_dir, 'MainDiscoverScreen')
    FileUtils.mkdir_p(explore_dir)
    ['DiscoverViewController.swift', 'SearchButtonDiscoverViewController.swift', 'SearchDiscoverPageViewController.swift'].each do |file|
      old_path = File.join(screens_dir, file)
      new_path = File.join(explore_dir, file)
      if File.exist?(old_path)
        FileUtils.mv(old_path, new_path)
        puts "Moved #{file} to MainDiscoverScreen/"
        ref = explore_group.files.find { |f| f.path == file || f.name == file }
        if ref
          ref.path = file
          ref.source_tree = '<group>'
        end
      end
    end
  end

  # 3. MainPlayAlongScreen
  playalong_group = find_group(project.main_group, 'MainPlayAlongScreen')
  if playalong_group
    playalong_dir = File.join(screens_dir, 'MainPlayAlongScreen')
    FileUtils.mkdir_p(playalong_dir)
    ['PlayAlongViewController.swift', 'SongDetailsPage.swift'].each do |file|
      old_path = File.join(screens_dir, file)
      new_path = File.join(playalong_dir, file)
      if File.exist?(old_path)
        FileUtils.mv(old_path, new_path)
        puts "Moved #{file} to MainPlayAlongScreen/"
        ref = playalong_group.files.find { |f| f.path == file || f.name == file }
        if ref
          ref.path = file
          ref.source_tree = '<group>'
        end
      end
    end
  end

  # 4. BottomNavbar
  bottom_group = find_group(project.main_group, 'BottomNavbar')
  if bottom_group
    bottom_dir = File.join(base_dir, 'Common', 'UIComponents', 'BottomNavbar')
    FileUtils.mkdir_p(bottom_dir)
    old_path = File.join(base_dir, 'Common', 'BottomNavbar.swift')
    new_path = File.join(bottom_dir, 'BottomNavbar.swift')
    if File.exist?(old_path)
      FileUtils.mv(old_path, new_path)
      puts "Moved BottomNavbar.swift to UIComponents/BottomNavbar/"
      ref = bottom_group.files.find { |f| f.path == 'BottomNavbar.swift' || f.name == 'BottomNavbar.swift' || f.path == 'Common/BottomNavbar.swift' || f.path.include?('BottomNavbar.swift') }
      if ref
        ref.name = 'BottomNavbar.swift'
        ref.path = 'BottomNavbar.swift'
        ref.source_tree = '<group>'
      end
    end
  end

  project.save
  puts "Xcode project saved successfully."
end

main
