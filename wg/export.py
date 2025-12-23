import os

def export_configs(wg_path: str) -> dict:
    configs = {}
    for fname in os.listdir(wg_path):
        if fname.endswith(".conf"):
            with open(os.path.join(wg_path, fname)) as f:
                configs[fname] = f.read()
    return configs
