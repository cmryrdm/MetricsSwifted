# Third-party directories to skip (item 6 / SPM checkouts + manual exclusions)
THIRD_PARTY_DIRS = %w[
  .build/checkouts
  SourcePackages/checkouts
  Pods
].freeze

# Additional folder names to exclude (user can extend this list)
EXCLUDED_FOLDER_NAMES = %w[
].freeze

# Known test base classes (indirect XCTestCase subclasses) — item 16
# Add your custom test base class names here
TEST_BASE_CLASSES = %w[
  XCTestCase
].freeze

def third_party_path?(file_path)
  THIRD_PARTY_DIRS.any? { |dir| file_path.include?(dir) } ||
    EXCLUDED_FOLDER_NAMES.any? { |name| file_path.split(File::SEPARATOR).include?(name) }
end

# ─── Lines-of-code ───────────────────────────────────────────────

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
    next if third_party_path?(file_path)
    counts = count_lines(file_path)
    total_lines_of_code += counts[:lines_of_code]
    total_blank_lines += counts[:blank_lines]
    total_comment_lines += counts[:comment_lines]
    total_files += 1
  end
  total_lines = total_lines_of_code + total_blank_lines + total_comment_lines
  { lines_of_code: total_lines_of_code, blank_lines: total_blank_lines, comment_lines: total_comment_lines, total_files: total_files, total_lines: total_lines }
end

# ─── Unused type detection ────────────────────────────────────────────────────

# Extract every class/struct/enum/protocol declared in a file.
# Returns array of { name:, kind:, file: } hashes.
# Respects decision items 2–5, 9.
def extract_declarations(file_path)
  declarations = []
  content = File.read(file_path, encoding: "utf-8")

  # item 7 — skip files that use NSClassFromString entirely
  return declarations if content.include?("NSClassFromString")

  lines = content.lines
  in_debug_block = false

  lines.each_with_index do |line, idx|
    stripped = line.strip

    # item 14 — skip declarations inside any #if block
    if stripped.match?(/^#if\b/)
      in_debug_block = true
      next
    end
    if in_debug_block
      in_debug_block = false if stripped == "#endif"
      next
    end

    # skip /// doc comments
    next if stripped.start_with?("///")

    # item 3 — skip extensions
    next if stripped.match?(/\bextension\b/)

    # item 4 — skip @objc declarations (check current and previous line)
    prev_line = idx > 0 ? lines[idx - 1].strip : ""
    next if stripped.start_with?("@objc") || prev_line == "@objc" || stripped.include?("@objc ")

    # Match class / struct / enum / protocol declaration
    match = stripped.match(/\b(class|struct|enum|protocol)\s+([A-Z][A-Za-z0-9_]*)/)
    next unless match

    kind = match[1]
    name = match[2]

    # item 2 — if file contains @NSManaged, mark whole file's classes as used (skip them)
    next if kind == "class" && content.include?("@NSManaged")

    # item 5 — class conforming to UIApplicationDelegate is used
    next if kind == "class" && line.include?("UIApplicationDelegate")

    # item 19 — class conforming to UNNotificationServiceExtension is used
    next if kind == "class" && line.include?("UNNotificationServiceExtension")

    # item 16 — class inheriting from a known test base class is used
    next if kind == "class" && TEST_BASE_CLASSES.any? { |base| line.include?(base) }

    # item 17 — SwiftUI preview structs are excluded (e.g. struct Foo_Previews: PreviewProvider)
    next if kind == "struct" && line.include?("PreviewProvider")

    # item 9 — @main marks the class as used (but NOT @MainActor)
    # Look backwards up to 3 lines for @main annotation
    lookahead = lines[[0, idx - 3].max...idx].map(&:strip)
    next if lookahead.any? { |l| l.match?(/^@main(?!Actor)\b/) }

    declarations << { name: name, kind: kind, file: file_path }
  end

  declarations
end

# Strip all comments from source content so type name mentions inside
# // single-line or /* block */ comments are not counted as real references.
def strip_comments(source)
  result = []
  in_block_comment = false
  source.each_line do |line|
    stripped = line.strip
    if in_block_comment
      in_block_comment = false if stripped.end_with?("*/")
      next
    elsif stripped.start_with?("/*")
      in_block_comment = true
      next
    elsif stripped.start_with?("///")
      next
    elsif stripped.start_with?("//")
      next
    else
      # Remove inline trailing comment (e.g. let x = Foo() // Foo is used)
      result << line.gsub(/\/\/.*$/, "")
    end
  end
  result.join
end

# Build the full text corpus from all first-party swift files (for reference searching)
def build_corpus(all_files)
  all_files.map { |f| begin; strip_comments(File.read(f, encoding: "utf-8")); rescue; ""; end }.join("\n")
end

def find_unused_types(directory)
  all_files = Dir.glob(File.join(directory, "**", "*.swift")).reject { |f| third_party_path?(f) }

  # Collect all declarations across the codebase
  all_declarations = all_files.flat_map { |f| extract_declarations(f) }

  # Build full corpus once
  corpus = build_corpus(all_files)

  unused = []

  all_declarations.each do |decl|
    name = decl[:name]
    kind = decl[:kind]

    # item 11 — enum used via rawValue initializer counts as used
    if kind == "enum"
      next if corpus.include?("#{name}(rawValue:")
    end

    # Count how many times the type name appears in the corpus.
    # A declaration itself contributes at least 1 occurrence (its own definition line),
    # so anything with count <= 1 has no external references.
    occurrences = corpus.scan(/\b#{Regexp.escape(name)}\b/).length

    unused << decl if occurrences <= 1
  end

  unused
end

# ─── Main ─────────────────────────────────────────────────────────────────────

folder_path = ARGV[0] || "."

unless Dir.exist?(folder_path)
  puts "Error: Directory '#{folder_path}' does not exist."
  exit 1
end

# Lines of code report
counts = search_swift_files(folder_path)
puts "|||||||||||||||| metrics_swifted ||||||||||||||||"
puts "Number of files: #{counts[:total_files]}"
puts "Lines of code: #{counts[:lines_of_code]}"
puts "Blank lines: #{counts[:blank_lines]}"
puts "Commented lines: #{counts[:comment_lines]}"
puts "Total lines of code: #{counts[:total_lines]}"
puts "|||||||||||||||||||||||||||||||||||||||||||||||||"

# Unused types report
puts ""
puts "|||||||||||||||| unused types |||||||||||||||||||"
unused = find_unused_types(folder_path)
if unused.empty?
  puts "No unused types found."
else
  unused.each do |decl|
    puts "[#{decl[:kind].upcase}] #{decl[:name]}"
    puts "  → #{decl[:file]}"
  end
  puts ""
  puts "Total unused types: #{unused.size}"
end
puts "|||||||||||||||||||||||||||||||||||||||||||||||||"