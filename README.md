# MetricsSwifted v1.1.6

## You can follow the steps below in order to learn your line of code and unused code (swift only).

- Check ruby version first with ```ruby --version```, install if you do not have.
- Inside metrics_swifted.rb directory, write ```ruby metrics_swifted.rb folder_name``` in terminal
- Do not forget to change  ```folder_name``` above :)


# Swift LOC Counter — Decision Log

## 🔵 Overview

Scans all `.swift` files in a given directory recursively and reports lines of code, blank lines, and comment lines per run. Third-party paths are skipped (shared exclusion logic with the unused type scanner).

---

## 📋 Decision Items

**1.** A line is stripped of leading and trailing whitespace before classification.

**2.** A blank line is any line that is empty after stripping.

**3.** A line starting with `//` is classified as a comment line.

**4.** A line starting with `/*` opens a block comment. That line is counted as a comment line and `in_block_comment` is set to `true`.

**5.** A line ending with `*/` closes a block comment. That line is counted as a comment line and `in_block_comment` is set to `false`.

**6.** Any line while `in_block_comment` is `true` (and not the closing `*/` line) is counted as a comment line.

**7.** All remaining lines are counted as lines of code.

**8.** Total lines = lines of code + blank lines + comment lines.

**9.** Third-party directories (`.build/checkouts`, `SourcePackages/checkouts`, `Pods`, and manually listed folder names) are skipped entirely and do not contribute to any count.

---

## ⚠️ Known Limitations

- A line that contains both code and an inline comment (e.g. `let x = 1 // note`) is counted as a line of code, not a comment line.
- Block comment detection is line-based; a `/*` and `*/` on the same line is not handled as a special case.
- Preprocessor branches (`#if`/`#endif`) are counted as lines of code.


# Swift Unused Code Scanner — Decision Log

## 🔵 Overview

We scan all `.swift` files across the full codebase (iOS app + all SPM SDKs) as a single unified corpus. For every `.swift` file, we extract every `class`, `struct`, `enum`, and `protocol` declaration. Each type is then checked individually for any reference anywhere in the codebase. A type is marked **unused** if it has zero references anywhere, considering all rules below. A file is considered fully unused only if every type declared inside it is unused.

---

## 📋 Decision Items

**1.** We scan inside `.swift` files and extract every `class`, `struct`, `enum`, and `protocol` declaration. Each type is checked independently — we search for any mention of that type name across the entire codebase. A type with zero mentions is marked unused.

**2.** Any class containing `@NSManaged` properties is marked as used (Core Data entity class).

**3.** Extensions are excluded from analysis because they add behavior to existing types implicitly and have no direct callers.

**4.** Any declaration annotated with `@objc` is marked as used and excluded from analysis.

**5.** Any class conforming to `UIApplicationDelegate` is marked as used.

**6.** We perform a unified scan across the iOS app and all SPM SDKs together as one codebase. A type is only unused if it has no references anywhere across all of them.

**7.** Any file containing `NSClassFromString` references is excluded from analysis at this stage, documented as a known limitation.

**8.** A protocol is marked as used if its name appears anywhere in the codebase. Protocols referenced broadly (e.g., as generic constraints or conformance declarations) will be detected correctly under item 1.

**9.** `@main` marks a class as used. `@MainActor` is a concurrency annotation, not an entry point — since both start with `@main`, the regex must match `@main` as a whole word (i.e., `@main` not followed by `Actor` or any other characters) to avoid false matches.

**10.** `Codable`/`CodingKeys` conformances are excluded from property-level analysis as Swift synthesizes invisible `encode`/`decode` code for them. Type-level (class/struct) detection is unaffected.

**11.** Any enum where `EnumName(rawValue:)` appears anywhere in the codebase is marked as used.

**12.** Assign-only properties are excluded from analysis at this stage, documented as a known limitation.

**13.** `public` declarations with no references outside their module are counted as unused.

**14.** Preprocessor macro branches (`#if`/`#else`/`#endif`) are excluded from analysis at this stage, documented as a known limitation.

**15.** The full codebase — iOS app and all SPM SDKs — is scanned together as a single unified corpus. See item 6.

**16.** Indirect `XCTestCase` inheritance is excluded from analysis at this stage, documented as a known limitation.

**17.** SwiftUI preview structs (e.g. `struct Foo_Previews: PreviewProvider`) are excluded from analysis as they exist solely for Xcode Canvas and are never referenced in production code.

**18.** Type name mentions inside `//` single-line comments or `/* */` block comments are not counted as real references. The corpus is stripped of all comments before reference scanning.

---

## ⚠️ Known Limitations (Excluded at This Stage)

- `@objc` dynamic dispatch and Objective-C interop (item 4)
- `NSClassFromString` string-based instantiation (item 7)
- Assign-only property detection (item 12)
- Preprocessor macro conditional branches (item 14)
- Indirect `XCTestCase` inheritance (item 16)
- XIB and Storyboard references (planned for a future iteration)

