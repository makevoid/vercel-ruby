require 'json'

desc "Bump patch version in package.json"
task :bump do
  package_file = 'package.json'
  
  # Read package.json
  package_data = JSON.parse(File.read(package_file))
  current_version = package_data['version']
  
  # Parse version components
  major, minor, patch = current_version.split('.').map(&:to_i)
  
  # Increment patch version
  new_version = "#{major}.#{minor}.#{patch + 1}"
  
  # Update package.json
  package_data['version'] = new_version
  
  # Write back to file with proper formatting
  File.write(package_file, JSON.pretty_generate(package_data) + "\n")
  
  puts "Version bumped from #{current_version} to #{new_version}"
end

# Set bump as the default task
task default: :bump