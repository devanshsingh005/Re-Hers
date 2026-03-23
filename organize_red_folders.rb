require 'xcodeproj'
require 'fileutils'

def main
  project_path = '/Users/admin/Documents/Re-Hers/Re-Hearse_v1.xcodeproj'
  project = Xcodeproj::Project.open(project_path)
  
  target = project.targets.first
  base_dir = '/Users/admin/Documents/Re-Hers'
  screens_dir = File.join(base_dir, 'Screens')

  # 1. MainPlaylistScreen
  playlist_group = project.main_group.groups.find { |g| g.name == 'Screens' }.groups.find { |g| g.name == 'MainPlaylistScreen' || g.path == 'MainPlaylistScreen' }
  playlist_dir = File.join(screens_dir, 'MainPlaylistScreen')
  FileUtils.mkdir_p(playlist_dir)
  ['MainPlayListScreen.swift', 'PlayListInside.swift'].each do |file|
    old_path = File.join(screens_dir, file)
    new_path = File.join(playlist_dir, file)
    if File.exist?(old_path)
      FileUtils.mv(old_path, new_path)
      puts "Moved #{file} to MainPlaylistScreen/"
      
      # Update Xcode Reference
      ref = playlist_group.files.find { |f| f.path == file || f.name == file }
      if ref
        ref.path = file
        ref.source_tree = '<group>'
      else
        playlist_group.new_reference(file)
      end
    end
  end

  # 2. MainDiscoverScreen
  explore_group = project.main_group.groups.find { |g| g.name == 'Screens' }.groups.find { |g| g.name == 'MainDiscoverScreen' || g.path == 'MainDiscoverScreen' }
  explore_dir = File.join(screens_dir, 'MainDiscoverScreen')
  FileUtils.mkdir_p(explore_dir)
  ['DiscoverViewController.swift', 'SearchButtonDiscoverViewController.swift', 'SearchDiscoverPageViewController.swift'].each do |file|
    old_path = File.join(screens_dir, file)
    new_path = File.join(explore_dir, file)
    if File.exist?(old_path)
      FileUtils.mv(old_path, new_path)
      puts "Moved #{file} to MainDiscoverScreen/"
      
      # Update Xcode Reference
      ref = explore_group.files.find { |f| f.path == file || f.name == file }
      if ref
        ref.path = file
        ref.source_tree = '<group>'
      else
        explore_group.new_reference(file)
      end
    end
  end

  # 3. MainPlayAlongScreen
  playalong_group = project.main_group.groups.find { |g| g.name == 'Screens' }.groups.find { |g| g.name == 'MainPlayAlongScreen' || g.path == 'MainPlayAlongScreen' }
  playalong_dir = File.join(screens_dir, 'MainPlayAlongScreen')
  FileUtils.mkdir_p(playalong_dir)
  ['PlayAlongViewController.swift', 'SongDetailsPage.swift'].each do |file|
    old_path = File.join(screens_dir, file)
    new_path = File.join(playalong_dir, file)
    if File.exist?(old_path)
      FileUtils.mv(old_path, new_path)
      puts "Moved #{file} to MainPlayAlongScreen/"
      
      # Update Xcode Reference
      ref = playalong_group.files.find { |f| f.path == file || f.name == file }
      if ref
        ref.path = file
        ref.source_tree = '<group>'
      else
        playalong_group.new_reference(file)
      end
    end
  end

  # 4. BottomNavbar
  bottom_group = project.main_group.groups.find { |g| g.name == 'Common' }.groups.find { |g| g.name == 'UIComponents' }.groups.find { |g| g.name == 'BottomNavbar' || g.path == 'BottomNavbar' }
  bottom_dir = File.join(base_dir, 'Common', 'UIComponents', 'BottomNavbar')
  FileUtils.mkdir_p(bottom_dir)
  
  # The file might be in Common/ or root
  old_path = File.join(base_dir, 'Common', 'BottomNavbar.swift')
  new_path = File.join(bottom_dir, 'BottomNavbar.swift')
  if File.exist?(old_path)
    FileUtils.mv(old_path, new_path)
    puts "Moved BottomNavbar.swift to UIComponents/BottomNavbar/"
    
    # Update Xcode Reference
    ref = bottom_group.files.find { |f| f.path == 'BottomNavbar.swift' || f.name == 'BottomNavbar.swift' || f.path == 'Common/BottomNavbar.swift' }
    if ref
      ref.name = 'BottomNavbar.swift'
      ref.path = 'BottomNavbar.swift'
      ref.source_tree = '<group>'
    else
      bottom_group.new_reference('BottomNavbar.swift')
    end
  end

  project.save
  puts "Xcode project saved successfully."
end

main
