import os

files_to_delete = [
    r"c:\Users\chrom\Videos\blueprint  stable\blueprint  stable complete back up\pubspec.yaml",
    r"c:\Users\chrom\Videos\blueprint  stable\blueprint  stable complete back up\analysis_options.yaml",
    r"c:\Users\chrom\Videos\blueprint  stable\blueprint  stable complete back up\README.md"
]

print("Files marked for deletion:")
for f in files_to_delete:
    print(f)

confirm = input("Type DELETE to confirm deletion: ")
if confirm.strip() != "DELETE":
    print("Aborted by user.")
    exit(1)

for f in files_to_delete:
    try:
        if os.path.exists(f):
            os.remove(f)
            print(f"Deleted: {f}")
        else:
            print(f"Skipped (not found): {f}")
    except Exception as e:
        print(f"Failed to delete {f}: {e}")
