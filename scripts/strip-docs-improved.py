
import os
import re
import ast
import argparse
from pathlib import Path
from typing import List, Set

def strip_python_docstrings_and_comments(content: str) -> str:
    lines = content.split('\n')
    result_lines = []
    in_docstring = False
    docstring_delimiter = None
    
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        
        if not stripped:
            result_lines.append(line)
            i += 1
            continue
        
        if stripped.startswith('#'):
            i += 1
            continue
        
        if not in_docstring:
            if (stripped.startswith('"""') or stripped.startswith("'''")):
                delimiter = '"""' if stripped.startswith('"""') else "'''"
                
                if line.count(delimiter) >= 2:
                    i += 1
                    continue
                else:
                    in_docstring = True
                    docstring_delimiter = delimiter
                    i += 1
                    continue
        else:
            if docstring_delimiter in line:
                in_docstring = False
                docstring_delimiter = None
                i += 1
                continue
            else:
                i += 1
                continue
        
        if '#' in line:
            comment_pos = line.find('#')
            before_comment = line[:comment_pos]
            single_quotes = before_comment.count("'") - before_comment.count("\\'")
            double_quotes = before_comment.count('"') - before_comment.count('\\"')
            
            if single_quotes % 2 == 0 and double_quotes % 2 == 0:
                line = line[:comment_pos].rstrip()
        
        result_lines.append(line)
        i += 1
    
    return '\n'.join(result_lines)

def strip_javascript_comments(content: str) -> str:
    lines = content.split('\n')
    result_lines = []
    in_block_comment = False
    
    for line in lines:
        original_line = line
        
        while '/*' in line and not in_block_comment:
            start = line.find('/*')
            if '*/' in line[start:]:
                end = line.find('*/', start) + 2
                line = line[:start] + line[end:]
            else:
                in_block_comment = True
                line = line[:start]
                break
                
        if in_block_comment:
            if '*/' in line:
                end_pos = line.find('*/') + 2
                line = line[end_pos:]
                in_block_comment = False
            else:
                continue
                
        if '//' in line:
            line = line[:line.find('//')].rstrip()
            
        result_lines.append(line)
    
    return '\n'.join(result_lines)

def strip_shell_comments(content: str) -> str:
    lines = content.split('\n')
    result_lines = []
    
    for line in lines:
        if line.startswith('#!'):
            result_lines.append(line)
            continue
            
        if line.strip().startswith('#'):
            continue
            
        if '#' in line:
            line = line[:line.find('#')].rstrip()
            
        result_lines.append(line)
    
    return '\n'.join(result_lines)

def strip_yaml_comments(content: str) -> str:
    lines = content.split('\n')
    result_lines = []
    
    for line in lines:
        if line.strip().startswith('#'):
            continue
            
        if '#' in line:
            line = line[:line.find('#')].rstrip()
            
        result_lines.append(line)
    
    return '\n'.join(result_lines)

def should_skip_file(file_path: Path) -> bool:
    skip_patterns = [
        '/.git/',
        '/node_modules/',
        '/__pycache__/',
        '/.pytest_cache/',
        '/htmlcov/',
        '/dist/',
        '/build/',
        '.egg-info/',
        '/venv/',
        '/.venv/',
    ]
    
    file_str = str(file_path)
    return any(pattern in file_str for pattern in skip_patterns)

def process_file(file_path: Path, dry_run: bool = False) -> bool:
    if should_skip_file(file_path):
        return False
        
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            original_content = f.read()
    except (UnicodeDecodeError, PermissionError):
        print(f"Skipping {file_path} (cannot read)")
        return False
    
    suffix = file_path.suffix.lower()
    new_content = original_content
    
    if suffix == '.py':
        new_content = strip_python_docstrings_and_comments(original_content)
    elif suffix in ['.js', '.jsx', '.ts', '.tsx']:
        new_content = strip_javascript_comments(original_content)
    elif suffix in ['.sh', '.bash']:
        new_content = strip_shell_comments(original_content)
    elif suffix in ['.yml', '.yaml']:
        new_content = strip_yaml_comments(original_content)
    else:
        return False
    
    if new_content != original_content:
        if not dry_run:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
        print(f"Processed: {file_path}")
        return True
    
    return False

def find_files_to_process(root_paths: List[Path]) -> List[Path]:
    extensions = {'.py', '.js', '.jsx', '.ts', '.tsx', '.sh', '.bash', '.yml', '.yaml'}
    files = []
    
    for root_path in root_paths:
        if root_path.is_file():
            if root_path.suffix.lower() in extensions:
                files.append(root_path)
        else:
            for file_path in root_path.rglob('*'):
                if (file_path.is_file() and 
                    file_path.suffix.lower() in extensions and 
                    not should_skip_file(file_path)):
                    files.append(file_path)
    
    return sorted(files)

def main():
    parser = argparse.ArgumentParser(description='Strip inline documentation from BookVerse project')
    parser.add_argument('paths', nargs='*', default=['.'], 
                       help='Paths to process (default: current directory)')
    parser.add_argument('--dry-run', action='store_true',
                       help='Show what would be processed without making changes')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Verbose output')
    
    args = parser.parse_args()
    
    root_paths = [Path(p).resolve() for p in args.paths]
    files_to_process = find_files_to_process(root_paths)
    
    if not files_to_process:
        print("No files found to process")
        return
    
    print(f"Found {len(files_to_process)} files to process")
    
    if args.dry_run:
        print("\nDRY RUN - No files will be modified")
    
    processed_count = 0
    for file_path in files_to_process:
        if process_file(file_path, args.dry_run):
            processed_count += 1
        elif args.verbose:
            print(f"No changes: {file_path}")
    
    print(f"\nProcessed {processed_count} files")
    if args.dry_run:
        print("Run without --dry-run to apply changes")

if __name__ == '__main__':
    main()
