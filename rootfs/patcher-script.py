import sys

patch_script = """

def run_patch_scripts(patch_script_path):
    import os
    for patch in os.listdir(patch_script_path):
        full_patch_file = os.path.join(patch_script_path, patch)
        if full_patch_file.endswith('.py') and os.path.isfile(full_patch_file):
            with open(full_patch_file, 'r') as f:
                try:
                    exec(f.read())
                except:
                    pass
run_patch_scripts('/patcher-script.d')

"""


def main(patch_file):
    result_list = []
    with open(patch_file, "r") as f:
        has_patched = False
        for line in f:
            if not has_patched and line.startswith('import'):
                result_list.append(patch_script)
                has_patched = True
            result_list.append(line)
    with open(patch_file, "w") as f:
        for line in result_list:
            f.write(line)

if __name__ == '__main__':
    main(sys.argv[1])
