def count_lines(file_path)
  lines_of_code = 0
  blank_lines = 0
  comment_lines = 0

  in_block_comment = false

  File.open(file_path, "r") do |file|
    file.each_line do |line|
      
      line = line.strip # Remove leading and trailing whitespace

      if line.empty?
        blank_lines += 1
      elsif line.start_with?("//")
        comment_lines += 1
      elsif line.start_with?("/*")
        in_block_comment = true
        comment_lines += 1
      elsif line.end_with?("*/")
        in_block_comment = false
        comment_lines += 1
      elsif in_block_comment
        comment_lines += 1
      else
        lines_of_code += 1
      end
    end
  end

  { lines_of_code: lines_of_code, blank_lines: blank_lines, comment_lines: comment_lines }
end

def search_swift_files(directory)
  total_lines_of_code = 0
  total_blank_lines = 0
  total_comment_lines = 0
   total_files = 0

  Dir.glob(File.join(directory, "**", "*.swift")).each do |file_path|
    counts = count_lines(file_path)
    total_lines_of_code += counts[:lines_of_code]
    total_blank_lines += counts[:blank_lines]
    total_comment_lines += counts[:comment_lines]
    total_files += 1
  end

  total_lines = total_lines_of_code + total_blank_lines + total_comment_lines

  { lines_of_code: total_lines_of_code, blank_lines: total_blank_lines, comment_lines: total_comment_lines, total_files: total_files, total_lines: total_lines }
end

folder_path = ARGV[0] || "."

if Dir.exist?(folder_path)
  counts = search_swift_files(folder_path)
  puts "|||||||||||||||| metrics_swifted ||||||||||||||||"
  puts "Number of files: #{counts[:total_files]}"
  puts "Lines of code: #{counts[:lines_of_code]}"
  puts "Blank lines: #{counts[:blank_lines]}"
  puts "Commented lines: #{counts[:comment_lines]}"
  puts "Total lines of code: #{counts[:total_lines]}"
  puts "|||||||||||||||||||||||||||||||||||||||||||||||||"
else
  puts "Error: Directory '#{folder_path}' does not exist."
end