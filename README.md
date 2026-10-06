# Bash Antivirus & Quarantine Restore Tool

A lightweight antivirus daemon written in Bash. It watches a directory, flags files by **extension** or by **suspicious keywords inside the file**, and moves them into a quarantine directory. A second interactive tool lets you review quarantined files, restore them (which whitelists them), or delete them permanently.

---

## Table of Contents

1. [Overview and Folder Hierarchy](#1-overview-and-folder-hierarchy)
2. [Prerequisites (Ubuntu)](#2-prerequisites-ubuntu)
3. [Running the Tools](#3-running-the-tools)
4. [Flagged Extensions and Keywords: Where They Are Defined](#4-flagged-extensions-and-keywords-where-they-are-defined)
5. [Configuring the Cron Job](#5-configuring-the-cron-job)
6. [The Whitelist: How Files Get Added and How the Daemon Checks It](#6-the-whitelist-how-files-get-added-and-how-the-daemon-checks-it)

---

## 1. Overview and Folder Hierarchy

```
.
├── antivirusd.sh         # Scanner daemon: detects and quarantines malicious files
├── restore.sh            # Interactive tool: restore or permanently delete quarantined files
├── Makefile              # Shortcuts: make run / make restore (creates malicious_dir first)
├── whitelist.txt         # (generated) filenames that the scanner must ignore
├── directory-info.last   # (generated) snapshot of the source directory after the last scan
├── directory-info.new    # (generated) snapshot of the source directory taken each cycle
└── README.md
```

> `whitelist.txt`, `directory-info.last` and `directory-info.new` are created automatically at runtime. They are created in the **current working directory** of whoever launches the scripts (see the note in [Section 6](#6-the-whitelist-how-files-get-added-and-how-the-daemon-checks-it)).

### `antivirusd.sh`

Usage:

```
./antivirusd.sh <source_directory> <quarantine_directory> <interval-seconds>
```

What it does:

1. Validates that exactly 3 arguments were given and that the source directory exists.
2. Creates the quarantine directory if it does not exist.
3. Runs in an infinite loop. Each cycle it saves `ls -l` of the source directory to `directory-info.new` and compares it with `directory-info.last` using `cmp`.
4. The **first cycle always scans**. After that, a scan only runs when the listing changed (file added, removed, resized, or modified). Otherwise it prints `No changes detected`.
5. During a scan, every file in the source directory is checked against the flagged extensions and flagged keywords. A matching file that is **not whitelisted** is moved to the quarantine directory.
6. It prints how many files were quarantined, updates the snapshot, then sleeps for `<interval-seconds>` before the next cycle.

### `Makefile`

Convenience wrapper around the two scripts. It does not compile anything. It provides:

| Target | What it does |
|---|---|
| `make pre-build` | Creates `malicious_dir` if it does not already exist |
| `make run` | Runs `antivirusd.sh` with its three required arguments (runs `pre-build` first) |
| `make restore` | Runs `restore.sh` with its two required arguments (runs `pre-build` first) |

Variables (defaults shown, override on the command line):

| Variable | Default | Used as |
|---|---|---|
| `ORIGINAL_DIR` | `original_dir` | Source directory to scan / directory files are restored to |
| `MALICIOUS_DIR` | `malicious_dir` | Quarantine directory |
| `INTERVAL` | `10` | Seconds between scans |

### `restore.sh`

Usage:

```
./restore.sh <original_dir> <malicious_dir>
```

What it does:

1. Lists every file in the quarantine directory with an index number.
2. Lets you pick a file by number (or `q` to quit).
3. Offers three actions for the selected file:
   - **1)** Restore it to the original directory **and add it to the whitelist**
   - **2)** Permanently delete it
   - **3)** Go back to the list
4. Repeats until you quit.

---

## 2. Prerequisites (Ubuntu)

| Requirement | Used for | Installed by default? |
|---|---|---|
| `bash` | Running both scripts (they use `[[ ]]`, arrays, `=~`) | Yes |
| `coreutils` (`ls`, `mv`, `rm`, `mkdir`, `basename`, `sleep`) | File handling | Yes |
| `grep` | Keyword scanning and whitelist lookup | Yes |
| `diffutils` (`cmp`) | Detecting changes in the directory snapshot | Usually yes |
| `cron` | Scheduling the scan | Not always (missing on minimal installs and WSL) |
| `make` | Running the Makefile targets (optional, the scripts also run directly) | Not always |

Install everything that might be missing:

```bash
sudo apt update
sudo apt install -y bash grep diffutils cron make
```

Make sure the cron service is enabled and running:

```bash
sudo systemctl enable --now cron
systemctl status cron
```

You should see `active (running)`.

## 3. Running the Tools

### Step 0: Get the scripts and make them executable

```bash
git clone <your-repo-url>
cd <your-repo-folder>
chmod +x antivirusd.sh restore.sh
```

### Step 1: Create a test source directory

```bash
mkdir -p ~/test_source
```

> **Shortcut:** steps 2 and 4 below can also be done with the Makefile. See [Running with the Makefile](#running-with-the-makefile).

### Step 2: Start the antivirus

```bash
./antivirusd.sh ~/test_source ~/quarantine 10
```

This scans `~/test_source` every 10 seconds and quarantines flagged files into `~/quarantine` (created automatically). Expected first output:

```
Scanning '/home/you/test_source' for malicous files
Running initial directory scan...
Scan complete. Quarantined 0 file(s).
```

Leave it running. Press `Ctrl+C` to stop it.

### Step 3: Trigger a detection (in a second terminal)

Create one file flagged by extension and one flagged by content:

```bash
touch ~/test_source/virus.exe
echo "this file contains a trojan" > ~/test_source/notes.txt
```

On the next cycle (within 10 seconds) the antivirus reports both files as malicious and moves them to `~/quarantine`.

### Step 4: Review and restore files

Run the restore tool **from the same directory** you started the antivirus from (see [Section 6](#6-the-whitelist-how-files-get-added-and-how-the-daemon-checks-it) for why):

```bash
./restore.sh ~/test_source ~/quarantine
```

Example session:

```
Files currently in /home/you/quarantine:
  [0] notes.txt
  [1] virus.exe

Enter the number of the file you want to review (or 'q' to quit): 0

Selected File: notes.txt
  1) Restore this file back into /home/you/test_source
  2) Permanently delete this file from /home/you/quarantine
  3) Go back to the list
Choose an option (1-3): 1
Restored notes.txt to /home/you/test_source.
```

After choosing option 1, the file is moved back **and** whitelisted, so the antivirus will leave it alone from now on.

### Running with the Makefile

The Makefile uses `original_dir` and `malicious_dir` in the project folder by default. Create the source directory once (the Makefile only creates the quarantine directory):

```bash
mkdir -p original_dir
```

Start the antivirus (creates `malicious_dir` automatically if needed):

```bash
make run
```

Review and restore quarantined files (in a second terminal, same folder):

```bash
make restore
```

Use different directories or a different interval:

```bash
make run ORIGINAL_DIR=/home/you/test_source MALICIOUS_DIR=/home/you/quarantine INTERVAL=5
make restore ORIGINAL_DIR=/home/you/test_source MALICIOUS_DIR=/home/you/quarantine
```

Both targets run from the Makefile's folder, so the antivirus and the restore tool automatically share the same `whitelist.txt`.

---

---

## 4. Flagged Extensions and Keywords: Where They Are Defined

Both lists live in **`antivirusd.sh`**.

### Flagged extensions

Defined in the configuration block at the top of the script, in the `REGEX` variable:

```bash
REGEX="\.(exe|vbs|bat|ps1|scr)$"
```

Flagged extensions: `.exe`, `.vbs`, `.bat`, `.ps1`, `.scr`

To add an extension, add it inside the parentheses separated by `|`, for example `\.(exe|vbs|bat|ps1|scr|js)$`.

> The match is **case-sensitive**: `virus.exe` is flagged but `virus.EXE` is not.

### Flagged keywords

Defined inline in the scan loop, in the `grep` command inside the `if` condition:

```bash
grep -qiE "trojan|malware|virus|worm|ransomware" "$file"
```

Flagged keywords: `trojan`, `malware`, `virus`, `worm`, `ransomware`

To add a keyword, append it with `|` inside the quotes. The match is **case-insensitive** (`-i`) and searches the file's **contents**, not its name.

### How they are combined

A file is flagged if **either** condition is true:

```bash
if [[ "$file" =~ $REGEX ]] || grep -qiE "trojan|malware|virus|worm|ransomware" "$file"; then
```

---

## 5. Configuring the Cron Job

### Goal

Run the antivirus on the **3rd Friday of every month at 12:31 AM**.

### Before you start (prerequisites)

Complete all of these first:

- [ ] `cron` is installed and running (see [Section 2](#2-prerequisites-ubuntu))
- [ ] The source directory already exists (the script exits with an error if it does not)
- [ ] You tested the script manually at least once (see [Section 3](#3-running-the-tools))
- [ ] You know the **absolute paths** of the project folder, source directory and quarantine directory. Cron does not run from your project folder and does not understand `~` reliably, so relative paths will fail. Get the project path with:

  ```bash
  cd <your-repo-folder> && pwd
  ```

### The cron expression

```
31 0 15-21 * * [ "$(date +\%u)" = "5" ] && cd /home/you/antivirus && ./antivirus-cron.sh /home/you/test_source /home/you/quarantine 60
```

Field breakdown:

| Field | Value | Meaning |
|---|---|---|
| Minute | `31` | At minute 31 |
| Hour | `0` | At hour 0 (12 AM) |
| Day of month | `15-21` | The 3rd Friday of any month always falls between the 15th and 21st |
| Month | `*` | Every month |
| Day of week | `*` | Left as `*` on purpose (see below) |
| Command | `[ "$(date +\%u)" = "5" ] && ...` | Only run if today is Friday (`date +%u` returns `5`) |

### Step-by-step setup

1. **Open your crontab:**

   ```bash
   crontab -e
   ```

   Pick an editor if asked (`nano` is the easiest).

2. **Paste the cron line** from above at the bottom of the file, replacing `/home/you/...` with your real absolute paths.

3. **Save and exit** (in `nano`: `Ctrl+O`, `Enter`, `Ctrl+X`).

4. **Confirm it was installed:**

   ```bash
   crontab -l
   ```

## 6. The Whitelist: How Files Get Added and How the Daemon Checks It

### File format

`whitelist.txt` is a plain text file with **one filename per line** (the file's name only, not its path). Example:

```
notes.txt
report.bat
```

### How a file gets added

Files are added **only by `restore.sh`, when you choose option 1 (Restore)**. This is the exact code:

```bash
1)
    mkdir -p "$ORIGINAL_DIR"
    mv "$selected_file" "$ORIGINAL_DIR/"
    echo "$filename" >> "whitelist.txt"
    echo "Restored $filename to $ORIGINAL_DIR."
    ;;
```

Step by step:

1. You select a quarantined file and choose `1`.
2. The file is moved from the quarantine directory back into the original directory.
3. Its filename is appended to `whitelist.txt` (the file is created if it does not exist).

Options 2 (delete) and 3 (go back) never touch the whitelist. You can also add or remove entries manually with any text editor, as long as there is one exact filename per line.

### How the daemon checks it

The check happens in `antivirusd.sh`, inside the scan loop, **after** a file has already been flagged as malicious:

```bash
if [[ "$file" =~ $REGEX ]] || grep -qiE "trojan|malware|virus|worm|ransomware" "$file"; then
    if [ -f "whitelist.txt" ]; then
        if grep -Fxq "$filename" "whitelist.txt"; then
                continue
        fi
    fi
    echo ""$file" is malicious and it is DELETED"
    mv "$file" "$QUARANTINE_DIR/"
    ((infected_count++))
fi
```

Step by step:

1. The file matches a flagged extension or keyword.
2. The script checks that `whitelist.txt` exists.
3. It runs `grep -Fxq "$filename" whitelist.txt`:
   - `-F`: treat the filename as a fixed string (no regex, so characters like `.` are literal)
   - `-x`: the **entire line** must match, so `a.exe` does not match `data.exe` or `a.exe.bak`
   - `-q`: quiet, only the exit status is used
4. If the filename is found, `continue` skips the file: it is **not quarantined** and **not counted**.
5. If it is not found (or `whitelist.txt` does not exist), the file is moved to quarantine.

Because restoring a file changes the source directory listing, the next cycle triggers a rescan. The restored file is flagged again, found in the whitelist, and skipped, so it stays in place.

### Things to be aware of

- **Run both scripts from the same directory.** `whitelist.txt` is referenced by a relative path, so it is created and read in the current working directory. If `restore.sh` is run from one folder and the antivirus from another, the whitelist will not be shared. This is also why the cron line starts with `cd`.
- **Matching is by filename only, and is case-sensitive.** The whitelist does not store a path or content hash, so any future file with the same name in the source directory is also skipped, even if its contents changed.
