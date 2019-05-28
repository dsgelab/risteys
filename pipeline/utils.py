def file_exists(path):
    try:
        f = open(path)
    except FileNotFoundError:
        return False
    else:
        f.close()
        return True
