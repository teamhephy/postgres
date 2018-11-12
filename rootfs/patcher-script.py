import sys

patch_script_tmp = """

def run_patch_scripts(patch_script_path):
    with open(patch_script_path, 'r') as f:
        try:
            exec(f.read())
        except:
            pass
run_patch_scripts("%s")

"""


def main(patch_file, patch_script_file):
    result_list = []
    patch_script = patch_script_tmp % patch_script_file
    with open(patch_file, "r") as f:
        has_patched = False
        for line in f:
            if (line.startswith('import') or line.startswith('from')) \
                    and not has_patched:
                result_list.append(patch_script)
                has_patched = True
            result_list.append(line)
        if not has_patched: result_list.append(patch_script)
    with open(patch_file, "w") as f:
        for line in result_list:
            f.write(line)

if __name__ == '__main__':
    patch_type = sys.argv[1]
    if patch_type == 'file':
        patch_file = sys.argv[2]
    elif patch_type == 'module':
        module = __import__(sys.argv[2], fromlist=True)
        patch_file = module.__file__
    patch_script_file = sys.argv[3]
    main(patch_file, patch_script_file)

