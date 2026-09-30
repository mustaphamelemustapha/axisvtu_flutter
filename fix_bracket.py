file_path = "/Users/mustaphamelemustapha/Code/VTU/axisvtu_flutter/lib/screens/home_screen.dart"
with open(file_path, "r", encoding='utf-8') as f:
    lines = f.readlines()

# delete lines 1680 to 1817 (which is 1681 to 1818 in 1-based index)
del lines[1680:1818]

with open(file_path, "w", encoding='utf-8') as f:
    f.writelines(lines)
