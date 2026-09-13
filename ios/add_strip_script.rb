require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

script_name = "Strip x86_64 from objective_c"
existing_phase = target.shell_script_build_phases.find { |p| p.name == script_name }

if existing_phase.nil?
  phase = project.new(Xcodeproj::Project::Object::PBXShellScriptBuildPhase)
  phase.name = script_name
  phase.shell_script = <<~SCRIPT
    FRAMEWORK_EXECUTABLE_PATH="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/objective_c.framework/objective_c"
    if [ -f "$FRAMEWORK_EXECUTABLE_PATH" ]; then
        echo "Stripping x86_64 from $FRAMEWORK_EXECUTABLE_PATH"
        lipo -remove x86_64 "$FRAMEWORK_EXECUTABLE_PATH" -o "$FRAMEWORK_EXECUTABLE_PATH" || true
    fi
  SCRIPT
  target.build_phases << phase
  project.save
  puts "Added script to project"
else
  puts "Script already exists"
end
