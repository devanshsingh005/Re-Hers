require 'xcodeproj'
require 'fileutils'

def main
  project_path = '/Users/admin/Documents/Re-Hers/Re-Hearse_v1.xcodeproj'
  project = Xcodeproj::Project.open(project_path)
  
  target = project.targets.first

  base_dir = '/Users/admin/Documents/Re-Hers'

  # 1. ColorViewController.swift
  # Move from project root to Models folder.
  old_color_path = File.join(base_dir, 'ColorViewController.swift')
  new_color_dir = File.join(base_dir, 'Models')
  new_color_path = File.join(new_color_dir, 'ColorViewController.swift')

  FileUtils.mkdir_p(new_color_dir)
  if File.exist?(old_color_path)
    FileUtils.mv(old_color_path, new_color_path)
    puts "Moved ColorViewController.swift to Models/"
  end

  # Fix Xcode reference for ColorViewController.swift
  models_group = project.main_group.groups.find { |g| g.name == 'Models' }
  unless models_group
    models_group = project.main_group.new_group('Models', 'Models')
  end
  # Remove old ref
  models_group.files.each do |f|
    if f.path == 'ColorViewController.swift' || f.name == 'ColorViewController.swift'
      f.remove_from_project
    end
  end
  # Add new ref
  file_ref = models_group.new_reference('ColorViewController.swift')
  target.add_file_references([file_ref])

  # 2. SoundFonts
  soundfonts_dir = File.join(base_dir, 'Resources', 'SoundFonts')
  FileUtils.mkdir_p(soundfonts_dir)

  ['Wurlitzer210.sf2', 'SteinGrandPiano.sf2'].each do |sf|
    old_sf_path = File.join(base_dir, sf)
    new_sf_path = File.join(soundfonts_dir, sf)
    if File.exist?(old_sf_path)
      FileUtils.mv(old_sf_path, new_sf_path)
      puts "Moved #{sf} to Resources/SoundFonts/"
    end
  end

  # Fix Xcode reference for SoundFonts
  resources_group = project.main_group.groups.find { |g| g.name == 'Resources' } || project.main_group.new_group('Resources', 'Resources')
  sf_group = resources_group.groups.find { |g| g.name == 'SoundFonts' } || resources_group.new_group('SoundFonts', 'SoundFonts')
  
  # Remove old Wurlitzer210.sf2 from root group
  project.main_group.files.each do |f|
    if f.path == 'Wurlitzer210.sf2' || f.name == 'Wurlitzer210.sf2'
      f.remove_from_project
    end
  end

  # Add SoundFonts to Xcode
  ['Wurlitzer210.sf2', 'SteinGrandPiano.sf2'].each do |sf|
    # Check if already in group
    unless sf_group.files.any? { |f| f.path == sf || f.name == sf }
      ref = sf_group.new_reference(sf)
      target.add_resources([ref])
    end
  end

  # 3. Rename MainUplaodScreen
  screens_group = project.main_group.groups.find { |g| g.name == 'Screens' } || project.main_group.groups.find { |g| g.path == 'Screens' }
  if screens_group
    upload_group = screens_group.groups.find { |g| g.name == 'MainUplaodScreen' || g.path == 'MainUplaodScreen' }
    if upload_group
      upload_group.name = 'MainUploadScreen'
      upload_group.path = 'MainUploadScreen'
      puts "Renamed MainUplaodScreen group to MainUploadScreen"
      
      # Now rename on disk
      old_upload_dir = File.join(base_dir, 'Screens', 'MainUplaodScreen')
      new_upload_dir = File.join(base_dir, 'Screens', 'MainUploadScreen')
      if File.exist?(old_upload_dir)
        FileUtils.mv(old_upload_dir, new_upload_dir)
        puts "Moved Screens/MainUplaodScreen to Screens/MainUploadScreen on disk"
      end

      # Rename uploadScreen.swift to UploadScreen.swift
      old_file_path = File.join(new_upload_dir, 'uploadScreen.swift')
      new_file_path = File.join(new_upload_dir, 'UploadScreen.swift')
      if File.exist?(old_file_path)
        FileUtils.mv(old_file_path, new_file_path)
        puts "Renamed uploadScreen.swift to UploadScreen.swift"
      end

      # Update Xcode reference for UploadScreen.swift
      upload_file = upload_group.files.find { |f| f.path == 'uploadScreen.swift' || f.name == 'uploadScreen.swift' }
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
        # Let's capitalize it on disk
        old_wave = File.join(base_dir, 'Common', 'Music_Components', 'waveframe.swift')
        new_wave = File.join(base_dir, 'Common', 'Music_Components', 'Waveframe.swift')
        if File.exist?(old_wave)
          FileUtils.mv(old_wave, new_wave)
          puts "Renamed waveframe.swift to Waveframe.swift"
        end
        ref = music_components_group.new_reference('Waveframe.swift')
        target.add_file_references([ref])
        puts "Added Waveframe.swift to project"
      end
    end
  end

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
