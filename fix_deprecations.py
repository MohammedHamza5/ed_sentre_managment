
import os
import re

def process_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content

    # Replace .withOpacity(x) with .withValues(alpha: x)
    # Regex: \.withOpacity\s*\(([^)]+)\)
    content = re.sub(r'\.withOpacity\s*\(([^)]+)\)', r'.withValues(alpha: \1)', content)

    # Replace print(x) with debugPrint(x)
    # Caution: Avoid replacing Printing.layoutPdf(onLayout: ...) or similar if "print" is in the name.
    # We target specifically `print(` function calls.
    # Also need to make sure debugPrint is imported if used.
    # For now, let's just do the replacement. We might introduce imports later or let VS Code autofix.
    # Regex: (?<!\w)print\s*\(
    # Lookbehind to ensure it's a standalone "print", not "sprint" or "blueprint".
    if 'avoid_print' in content or 'print(' in content:
        # Check if debugPrint is already imported or if we need it
        # Actually, let's be careful. `debugPrint` is in `flutter/foundation.dart`.
        # Simplest approach: Replace `print(` with `debugPrint(` and rely on linter to tell us if import is missing (which we can fix later) 
        # OR add the import if missing.
        
        # Replace
        new_content = re.sub(r'(?<!\w)print\s*\(', 'debugPrint(', content)
        
        if new_content != content:
            content = new_content
            # Check import
            if "import 'package:flutter/foundation.dart';" not in content and "import 'package:flutter/material.dart';" not in content:
                # debugPrint is exported by material too usually, but foundation is the source.
                # Many files have material.dart.
                pass 

    if content != original_content:
        try:
            print(f"Modifying {file_path}")
        except:
            pass
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)

def main():
    root_dir = os.getcwd()
    for root, dirs, files in os.walk(root_dir):
        if '.dart_tool' in root or '.git' in root or 'build' in root:
            continue
            
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                try:
                    process_file(file_path)
                except Exception as e:
                    try:
                        print(f"Error processing {file_path}: {e}")
                    except:
                        pass

if __name__ == '__main__':
    main()
