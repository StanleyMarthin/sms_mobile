import sys

def main():
    file_path = '/home/sahrulr/StudioProjects/sm_workshop/lib/features/countdown/presentation/pages/countdown_page.dart'
    with open(file_path, 'r') as f:
        lines = f.readlines()
    
    new_lines = []
    for i, line in enumerate(lines):
        line_num = i + 1
        if 911 <= line_num <= 1290:
            continue
        if 1311 <= line_num <= 1924:
            continue
        new_lines.append(line)
        
    with open(file_path, 'w') as f:
        f.writelines(new_lines)

if __name__ == '__main__':
    main()
