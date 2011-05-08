def data_exporter
	# Set up the directory paths
	$INPUT_DIR  = $PROJECT_DIR + '/' + $RXDATA_DIR + '/'
	$OUTPUT_DIR = $PROJECT_DIR + '/' + $YAML_DIR + '/'

	print_separator(true)
	puts "  RMXP Data Export"
	print_separator(true)

	#$STARTUP_TIME = load_startup_time || Time.now
	$TIMESTAMP = load_startup_time || {}

	#$CHECKSUM = load_checksum || {}

	# Check if the input directory exists
	if not (File.exists? $INPUT_DIR and File.directory? $INPUT_DIR)
	  puts "Error: Input directory #{$INPUT_DIR} does not exist."
	  puts "Hint: Check that the $RXDATA_DIR variable in paths.rb is set to the correct path."
	  exit
	end

	# Create the output directory if it doesn't exist
	if not (File.exists? $OUTPUT_DIR and File.directory? $OUTPUT_DIR)
	  recursive_mkdir( $OUTPUT_DIR )
	end

	# Create the list of rxdata files to export
	files = Dir.entries( $INPUT_DIR )
	files -= $RXDATA_IGNORE_LIST
	files = files.select { |e| File.extname(e) == '.rxdata' }
	files = files.select { |e| file_modified_since?($INPUT_DIR + e, $TIMESTAMP) or not rxdata_file_exported?($INPUT_DIR + e) }
	#files = files.select { |e| file_modified_from?($INPUT_DIR + e, $CHECKSUM) or not rxdata_file_exported?($INPUT_DIR + e) }

	files.sort!

	if files.empty?
	  puts_verbose "No data files need to be exported."
	  puts_verbose
	  exit
	end

	total_start_time = Time.now
	total_load_time = 0.0
	total_dump_time = 0.0

	# For each rxdata file, load it and dump the objects to YAML
	files.each_index do |i|
  	data = nil
	  start_time = Time.now
	 
  	# Load the data from rmxp's data file
    begin
		  File.open( $INPUT_DIR + files[i], "r+" ) do |datafile| 
		    data = Marshal.load( datafile )
  		end
		rescue
			puts_verbose "Error! Unable to open %s. Skipping!" % files[i] 
			#$CHECKSUM.delete(files[i])
			$TIMESTAMP.delete(files[i])
			next 
		end
  
	  # Calculate the time to load the .rxdata file
	  load_time = Time.now - start_time
  	total_load_time += load_time

	  start_time = Time.now
  
  	# Prevent the 'magic_number' field of System from always conflicting
	  if files[i] == "System.rxdata"
	    data.magic_number = $MAGIC_NUMBER unless $MAGIC_NUMBER == -1
	  end
  
		target_file = File.basename(files[i], ".rxdata") + ".yaml"

  	# Dump the data to a YAML file
	  File.open($OUTPUT_DIR + target_file, File::WRONLY|File::CREAT|File::TRUNC|File::BINARY) do |outfile|
	    YAML::dump({'root' => data}, outfile )
	  end

		#$CHECKSUM[target_file] = get_file_hash($OUTPUT_DIR + target_file)
		$TIMESTAMP[target_file] = File.mtime( $OUTPUT_DIR + target_file )

  	# Calculate the time to dump the .yaml file
	  dump_time = Time.now - start_time
  	total_dump_time += dump_time
  
	  # Update the user on the export status
	  str =  "Exported "
  	str += "#{files[i]}".ljust(30)
	  str += "(" + "#{i+1}".rjust(3, '0')
  	str += "/"
	  str += "#{files.size}".rjust(3, '0') + ")"
	  str += "    #{load_time + dump_time} seconds"
	  puts_verbose str
	end

	# Calculate the total elapsed time
	total_elapsed_time = Time.now - total_start_time

	#dump_checksum($CHECKSUM)
	dump_startup_time($TIMESTAMP)

	# Report the times
	print_separator
	puts_verbose "RXDATA load time: #{total_load_time} seconds."
	puts_verbose "YAML dump time:   #{total_dump_time} seconds."
	puts_verbose "Total export time:  #{total_elapsed_time} seconds."
	print_separator
	puts_verbose
end

def data_importer
	#===============================================================================
	# Filename:    data_importer.rb
	#
	# Developer:   Raku (rakudayo@gmail.com)
	#
	# Description: This script imports the previously-exported plain text files back
	#    into RMXP's .rxdata files.  This script requires the text files previously
	#    exported by data_exporter.rb to generate the .rxdata files.
	#
	# Usage:       ruby data_importer.rb <project_directory>
	#===============================================================================

	# Make sure RMXP isn't running
	# exit if check_for_rmxp

	# Set up the directory paths
	$INPUT_DIR  = $PROJECT_DIR + "/" + $YAML_DIR + '/'
	$OUTPUT_DIR = $PROJECT_DIR + "/" + $RXDATA_DIR + '/'

	print_separator(true)
	puts "  RMXP Data Import"
	print_separator(true)

	#$STARTUP_TIME = load_startup_time || Time.now
	$TIMESTAMP = load_startup_time || {}
	#$CHECKSUM = load_checksum || {}

	# Check if the input directory exists
	if not (File.exists? $INPUT_DIR and File.directory? $INPUT_DIR)
  	puts "Input directory #{$INPUT_DIR} does not exist."
	  puts "Nothing to import...skipping import."
	  puts
	  exit
	end

	# Create the output directory if it doesn't exist
	if not (File.exists? $OUTPUT_DIR and File.directory? $OUTPUT_DIR)
	  #puts "Error: Output directory #{$OUTPUT_DIR} does not exist."
	  #puts "Hint: Check that the $RXDATA_DIR variable in paths.rb is set to the correct path."
	  #puts
	  #exit
          recursive_mkdir( $OUTPUT_DIR )
	end

	# Create the list of rxdata files to export
	files = Dir.entries( $INPUT_DIR )
	files = files.select { |e| File.extname(e) == '.yaml' }
	files = files.select { |e| file_modified_since?($INPUT_DIR + e, $TIMESTAMP) or not rxdata_file_imported?($OUTPUT_DIR + e) }
	#files = files.select { |e| file_modified_from?($INPUT_DIR + e, $CHECKSUM) or not rxdata_file_imported?($INPUT_DIR + e) }
	files.sort!

	if files.empty?
	  puts_verbose "No data files to import."
	  puts_verbose
	  exit
	end

	total_start_time = Time.now
	total_load_time  = 0.0
	total_dump_time  = 0.0

	# For each yaml file, load it and dump the objects to rxdata file
	files.each_index do |i|
	  data = nil 
  
	  # Load the data from yaml file
	  start_time = Time.now
	  File.open( $INPUT_DIR + files[i], "r+" ) do |yamlfile|
	    data = YAML::load( yamlfile )
	  end

	  # Calculate the time to load the .yaml file
	  load_time = Time.now - start_time
	  total_load_time += load_time
 
	  target_file = File.basename(files[i], ".yaml") + ".rxdata"

	  # Dump the data to .rxdata file
	  start_time = Time.now
	  File.open( $OUTPUT_DIR + target_file, "w+" ) do |rxdatafile|
	    Marshal.dump( data['root'], rxdatafile ) 
	  end

	  #$CHECKSUM[target_file] = get_file_hash($OUTPUT_DIR + target_file)
	  $TIMESTAMP[target_file] = File.mtime($OUTPUT_DIR + target_file)

	  # Calculate the time to dump the .rxdata file
	  dump_time = Time.now - start_time
	  total_dump_time += dump_time
  
	  # Update the user on the status
	  str =  "Imported "
  	str += "#{files[i]}".ljust(30)
	  str += "(" + "#{i+1}".rjust(3, '0')
	  str += "/"
	  str += "#{files.size}".rjust(3, '0') + ")"
	  str += "    #{load_time + dump_time} seconds"
	  puts_verbose str
	end

	# Calculate the total elapsed time
	total_elapsed_time = Time.now - total_start_time


	#dump_checksum($CHECKSUM)
	dump_startup_time($TIMESTAMP)

	# Report the times
	print_separator
	puts_verbose "YAML load time:   #{total_load_time} seconds."
	puts_verbose "RXDATA dump time: #{total_dump_time} seconds."
	puts_verbose "Total import time:  #{total_elapsed_time} seconds."
	print_separator
	puts_verbose
end

def script_importer
	#===============================================================================
	# Filename:    script_importer.rb
	#
	# Developer:   Raku (rakudayo@gmail.com)
	#
	# Description: This script import scripts into RMXP's Scripts.rxdata file.  This
	#    script should only be used to import text files that have previously been
	#    exported with the script_exporter.rb script.
	#
	# Usage:       ruby script_importer.rb <project_directory>
	#===============================================================================

	#--------------------------------
	#      RGSS EXPORT SCRIPT
	#--------------------------------

	# Make sure RMXP isn't running
	# exit if check_for_rmxp

	# Set up the directory paths
	$INPUT_DIR  = $PROJECT_DIR + "/" + $SCRIPTS_DIR + "/"
	$OUTPUT_DIR = $PROJECT_DIR + "/" + $RXDATA_DIR + "/"
	
	print_separator(true)
	puts "  RGSS Script Import"
	print_separator(true)

	# Check if the input directory exists
	if not (File.exists? $INPUT_DIR and File.directory? $INPUT_DIR)
	  puts_verbose "Input directory #{$INPUT_DIR} does not exist."
	  puts_verbose "Nothing to import...skipping import."
	  puts_verbose
	  exit
	end

	# Create the output directory if it doesn't exist
	if not (File.exists? $OUTPUT_DIR and File.directory? $OUTPUT_DIR)
	  #puts "Error: Output directory #{$OUTPUT_DIR} does not exist."
	  #puts "Hint: Check that the rxdata_dir config option in config.yaml is set correctly."
	  #puts
	  #exit
          recursive_mkdir( $OUTPUT_DIR )
	end

	start_time = Time.now

	# Import the RGSS scripts from Ruby files
	if File.exists?($INPUT_DIR + $EXPORT_DIGEST_FILE)
	  # Load the export digest
	  digest = []
	  i = 0
	  File.open($INPUT_DIR + $EXPORT_DIGEST_FILE, File::RDONLY) do |digestfile|
  	  digestfile.each do |line|
	      line.chomp!
	      digest[i] = []
	      digest[i][0] = line[0..$COLUMN1_WIDTH-1].rstrip.to_i
	      digest[i][1] = line[$COLUMN1_WIDTH..($COLUMN1_WIDTH+$COLUMN2_WIDTH-1)].rstrip
	      digest[i][2] = line[($COLUMN1_WIDTH+$COLUMN2_WIDTH)..-1].rstrip
	      i += 1
	    end
  	end

	  # Find out how many non-empty scripts we have
	  num_scripts  = digest.select { |e| e[2].upcase != "EMPTY" }.size
	  num_exported = 0

	  # Create the scripts data structure
	  scripts = []
	  #for i in (0..digest.length-1)
	  digest.each_index do |i|
	    scripts[i] = []
  	  scripts[i][0] = digest[i][0]
	    scripts[i][1] = digest[i][1]
	    scripts[i][2] = ""

	    # Get the time starting import for this file
	    deflate_start_time = Time.now
	    if digest[i][2].upcase != "EMPTY"
	      begin
	        scriptname = $INPUT_DIR + "/" + digest[i][2]
	        File.open(scriptname, File::RDONLY) do |infile|
	          scripts[i][2] = infile.read
	        end
	      rescue Errno::ENOENT
	        puts "ERROR:      No such file or directory - #{scriptname.gsub!('//','/')}.\n" +
	             "Suggestion: If you are using a versioning system, check if this is a new\n" + 
	             "RGSS script that was not commited to the repository."
	      end
	      num_exported += 1
	    end
	      # Perform the deflate on the compressed script
	      scripts[i][2] = Zlib::Deflate.deflate(scripts[i][2])
	      # Calculate the elapsed time for the deflate
	      deflate_elapsed_time = Time.now - deflate_start_time
	      # Build a log string
	      str =  "Imported #{digest[i][2].ljust($FILENAME_WIDTH)}(#{num_exported.to_s.rjust(3, '0')}/#{num_scripts.to_s.rjust(3, '0')})"
	      str += "         #{deflate_elapsed_time} seconds" if deflate_elapsed_time > 0.0
	      puts_verbose str if digest[i][2].upcase != "EMPTY"
	  end

	  # Dump the scripts data structure to the RMXP's Scripts.rxdata file
	  File.open($OUTPUT_DIR + "Scripts.rxdata", File::WRONLY|File::TRUNC|File::CREAT|File::BINARY) do |outfile|
	    Marshal.dump(scripts, outfile)
	  end
		#$CHECKSUM = load_checksum || {}
		#$CHECKSUM["Scripts.rxdata"] = get_file_hash($OUTPUT_DIR + "Scripts.rxdata")
		#dump_checksum($CHECKSUM)
		$TIMESTAMP = load_startup_time || {}
		$TIMESTAMP["Scripts.rxdata"] = File.mtime($OUTPUT_DIR + "Scripts.rxdata")
		dump_startup_time($TIMESTAMP)

	  elapsed_time = Time.now - start_time

	  print_separator
	  puts_verbose "The total import time:  #{elapsed_time} seconds."
	  print_separator
	elsif
	  puts_verbose "No scripts to import."
	end

	puts_verbose
end

def script_exporter
	#===============================================================================
	# Filename:    script_exporter.rb
	#
	# Developer:   Raku (rakudayo@gmail.com)
	#
	# Description: This file provides the functionality which allows the user to
	#    export scripts from RMXP's Scripts.rxdata file to separate text files so
	#    that they may be versioned with a versioning system such as Subversion or 
	#    Mercurial.
	#
	# Usage:       ruby script_exporter.rb <project_directory>
	#===============================================================================

	# Make sure RMXP isn't running
	# exit if check_for_rmxp

	# Set up the directory paths
	$INPUT_DIR  = $PROJECT_DIR + '/' + $RXDATA_DIR + '/'
	$OUTPUT_DIR = $PROJECT_DIR + '/' + $SCRIPTS_DIR + '/'

	print_separator(true)
	puts "  RGSS Script Export"
	print_separator(true)

	#$STARTUP_TIME = load_startup_time(true) || Time.now
	$TIMESTAMP = load_startup_time || {}

	# Check if the input directory exists
	if not (File.exists? $INPUT_DIR and File.directory? $INPUT_DIR)
	  puts "Error: Input directory #{$INPUT_DIR} does not exist."
	  puts "Hint: Check that the rxdata_dir path in config.yaml is set to the correct path."
	  exit
	end

	# Create the output directory if it doesn't exist
	if not (File.exists? $OUTPUT_DIR and File.directory? $OUTPUT_DIR)
	  recursive_mkdir( $OUTPUT_DIR )
	end

	if (not file_modified_since?($INPUT_DIR + "Scripts.rxdata", $TIMESTAMP)) and (File.exists?($SCRIPTS_DIR + "/" + $EXPORT_DIGEST_FILE))
	  puts_verbose "No RGSS scripts need to be exported."
	  puts_verbose
 	 exit
	end

	start_time = Time.now

	# Read in the scripts from script file
	scripts = nil
	File.open($INPUT_DIR + "Scripts.rxdata", File::RDONLY|File::BINARY) do |infile|
	  scripts = Marshal.load(infile)
	end

	# Create the export digest
	digest = []
	File.open($OUTPUT_DIR + $EXPORT_DIGEST_FILE, File::WRONLY|File::CREAT|File::TRUNC) do |digestfile|
	  scripts.each_index do |i|
	    digest[i] = []
	    digest[i] << scripts[i][0]
	    digest[i] << scripts[i][1]
	    digest[i] << generate_filename(scripts[i])
	    line = "#{digest[i][0].to_s.ljust($COLUMN1_WIDTH)}#{digest[i][1].ljust($COLUMN2_WIDTH)}#{digest[i][2]}\n"
	    #puts line
	    digestfile << line
	  end
	end

	# Find out how many non-empty scripts we have
	num_scripts  = digest.select { |e| e[2].upcase != "EMPTY" }.size
	num_exported = 0

	# Save each script to a separate file
	scripts.each_index do |i|
	  if digest[i][2].upcase != "EMPTY"
	    inflate_start_time = Time.now
	    File.open($OUTPUT_DIR + digest[i][2], File::WRONLY|File::CREAT|File::TRUNC|File::BINARY) do |outfile|
	      outfile << Zlib::Inflate.inflate(scripts[i][2])
	    end
	    num_exported += 1
	    inflate_elapsed_time = Time.now - inflate_start_time
	    str  = "Exported #{digest[i][2].ljust($FILENAME_WIDTH)}(#{num_exported.to_s.rjust(3, '0')}/#{num_scripts.to_s.rjust(3, '0')})"
	    str += "         #{inflate_elapsed_time} seconds" if inflate_elapsed_time > 0.0
	    puts_verbose str
                 
	  end
	end

	puts "\n"

  	dump_startup_time($TIMESTAMP)

	elapsed_time = Time.now - start_time

	print_separator
	puts_verbose "The total export time:  #{elapsed_time} seconds."
	print_separator
	puts_verbose
end

def logtime

	# Make sure RMXP isn't running
	exit if check_for_rmxp

	# Get the project directory from command-line argument
	$PROJECT_DIR = ARGV[1]

	# Uhh...is a comment really necessary here?
	# dump_startup_time
	
end

require 'rmxp/rgss'
require 'yaml'
require 'common'
$COMMAND = ARGV[0]
case $COMMAND
  when 'data_exporter'
    data_exporter
  when 'script_exporter'
    script_exporter
  when 'data_importer'
    data_importer
  when 'script_importer'
    script_importer
  when 'logtime'
    logtime
  else
    puts 'rxdatav.exe [data_exporter|data_importer|script_exporter|script_importer|logtime] PATH'
end
