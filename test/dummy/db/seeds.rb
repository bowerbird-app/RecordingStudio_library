# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

find_or_record_child = lambda do |recordable, root_recording, parent_recording|
  RecordingStudio::Recording.find_by(
    root_recording: root_recording,
    parent_recording: parent_recording,
    recordable: recordable,
    trashed_at: nil
  ) || RecordingStudio.record!(
    action: "created",
    recordable: recordable,
    root_recording: root_recording,
    parent_recording: parent_recording
  ).recording
end

# Create the admin user
user = User.find_or_create_by!(email: "admin@admin.com") do |u|
  u.password = "Password"
  u.password_confirmation = "Password"
end

# Create the workspace recordables
workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
accessible_workspace = Workspace.find_or_create_by!(name: "Client Workspace")
private_workspace = Workspace.find_or_create_by!(name: "Private Workspace")
folder = Folder.find_or_create_by!(name: "Product Docs")
page = Page.find_or_create_by!(title: "Getting Started")
outside_page = Page.find_or_create_by!(title: "Stage notes")
showcase = Showcase.find_or_create_by!(title: "Homepage gallery")

previous_actor = Current.actor
Current.actor = user

begin
  root_recording = RecordingStudio.root_recording_for(workspace)
  accessible_root_recording = RecordingStudio.root_recording_for(accessible_workspace)
  private_root_recording = RecordingStudio.root_recording_for(private_workspace)

  [root_recording, accessible_root_recording, private_root_recording].each do |root|
    RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: user)
  end

  folder_recording = find_or_record_child.call(folder, root_recording, root_recording)
  find_or_record_child.call(page, root_recording, folder_recording)
  find_or_record_child.call(outside_page, root_recording, root_recording)
  showcase_recording = find_or_record_child.call(showcase, root_recording, root_recording)

  library = RecordingStudioLibrary.library_for(root_recording, actor: user)

  samples = [
    { title: "Coral poster", summary: "Warm campaign still for the foyer.", accent: "coral" },
    { title: "Sage still", summary: "Quiet green field used in the programme.", accent: "sage" },
    { title: "Ink title card", summary: "Dark card for chapter opens.", accent: "ink" },
    { title: "Sand wide", summary: "Wide sand frame for the landing strip.", accent: "sand" },
    { title: "Sky crop", summary: "Bright crop for the newsletter header.", accent: "sky" }
  ]

  sample_recordings = samples.map do |attrs|
    existing = RecordingStudioLibrary::SampleItem.find_by(title: attrs[:title])
    if existing
      RecordingStudio::Recording.find_by!(recordable: existing)
    else
      RecordingStudio.record!(
        action: "created",
        recordable: RecordingStudioLibrary::SampleItem.new(attrs),
        root_recording: root_recording,
        parent_recording: library,
        actor: user
      ).recording
    end
  end

  placed = RecordingStudioLibrary.resolve(showcase_recording, actor: user)
  if placed.empty?
    sample_recordings.first(3).each do |item|
      RecordingStudioLibrary.place!(showcase_recording, item, actor: user)
    end
  end
ensure
  Current.actor = previous_actor
end

puts "Seeded: admin@admin.com / Password"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Workspace '#{accessible_workspace.name}' with root recording ##{accessible_root_recording.id}"
puts "Seeded: Workspace '#{private_workspace.name}' with root recording ##{private_root_recording.id}"
puts "Seeded: Folder '#{folder.name}' and page '#{page.title}'"
puts "Seeded: Library with #{sample_recordings.size} samples and showcase '#{showcase.title}'"
