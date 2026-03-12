require 'xcodeproj'
require 'fileutils'

def main
  project_path = '/Users/admin/Documents/Re-Hers/Re-Hearse_v1.xcodeproj'
  project = Xcodeproj::Project.open(project_path)
  
  target = project.targets.first

  base_dir = '/Users/admin/Documents/Re-Hers'

  # 3. Rename MainUplaodScreen
  screens_group = project.main_group.groups.find { |g| g.name == 'Screens' } || project.main_group.groups.find { |g| g.path == 'Screens' }
  if screens_group
    upload_group = screens_group.groups.find { |g| g.name == 'MainUplaodScreen' || g.name == 'MainUploadScreen' || g.path == 'MainUplaodScreen' || g.path == 'MainUploadScreen' }
    if upload_group
      upload_group.name = 'MainUploadScreen'
      upload_group.path = 'MainUploadScreen'
      
      new_upload_dir = File.join(base_dir, 'Screens', 'MainUploadScreen')

      # Rename uploadScreen.swift to UploadScreen.swift (handle case-insensitive filesystem)
      old_file_path = File.join(new_upload_dir, 'uploadScreen.swift')
      temp_file_path = File.join(new_upload_dir, 'UploadScreen_temp.swift')
      new_file_path = File.join(new_upload_dir, 'UploadScreen.swift')
      
      if File.exist?(old_file_path) && old_file_path != new_file_path
        # only try to rename if the current case is not the desired case
        actual_name = Dir.entries(new_upload_dir).find { |f| f.downcase == 'uploadscreen.swift' }
        if actual_name == 'uploadScreen.swift'
          FileUtils.mv(old_file_path, temp_file_path)
          FileUtils.mv(temp_file_path, new_file_path)
          puts "Renamed uploadScreen.swift to UploadScreen.swift"
        end
      end

      # Update Xcode reference for UploadScreen.swift
      upload_file = upload_group.files.find { |f| f.path == 'uploadScreen.swift' || f.name == 'uploadScreen.swift' || f.path == 'UploadScreen.swift' }
      if upload_file
        upload_file.name = 'UploadScreen.swift'
        upload_file.path = 'UploadScreen.swift'
      end
    end
  end

  # 4. Add untracked files: waveframe.swift, ChordRecognition.swift
  common_group = project.main_group.groups.find { |g| g.name == 'Common' || g.path == 'Common' }
  if common_group
    music_components_group = common_group.groups.find { |g| g.name == 'Music_Components' || g.path == 'Music_Components' }
    if music_components_group
      # check if waveframe.swift exists
      unless music_components_group.files.any? { |f| f.path == 'waveframe.swift' || f.name == 'waveframe.swift' || f.path == 'Waveframe.swift' }
        music_dir = File.join(base_dir, 'Common', 'Music_Components')
        actual_name = Dir.entries(music_dir).find { |f| f.downcase == 'waveframe.swift' }
        if actual_name == 'waveframe.swift'
          old_wave = File.join(music_dir, 'waveframe.swift')
          temp_wave = File.join(music_dir, 'Waveframe_temp.swift')
          new_wave = File.join(music_dir, 'Waveframe.swift')
          FileUtils.mv(old_wave, temp_wave)
          FileUtils.mv(temp_wave, new_wave)
          puts "Renamed waveframe.swift to Waveframe.swift"
        end
        ref = music_components_group.new_reference('Waveframe.swift')
        target.add_file_references([ref])
        puts "Added Waveframe.swift to project"
      end
    end
  end

  # features group
  features_group = project.main_group.groups.find { |g| g.name == 'Features' || g.path == 'Features' }
  unless features_group
    features_group = project.main_group.new_group('Features', 'Features')
  end
  chord_group = features_group.groups.find { |g| g.name == 'ChordRecognition' || g.path == 'ChordRecognition' }
  unless chord_group
    chord_group = features_group.new_group('ChordRecognition', 'ChordRecognition')
  end
  
  unless chord_group.files.any? { |f| f.path == 'ChordRecognition.swift' || f.name == 'ChordRecognition.swift' }
    ref = chord_group.new_reference('ChordRecognition.swift')
    target.add_file_references([ref])
    puts "Added ChordRecognition.swift to project"
  end

  project.save
  puts "Xcode project saved successfully."
end

main
