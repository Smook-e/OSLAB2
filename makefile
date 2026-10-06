
ORIGINAL_DIR  ?= original_dir
MALICIOUS_DIR ?= malicious_dir
INTERVAL      ?= 10

.PHONY: pre-build run restore

pre-build:
	@mkdir -p $(MALICIOUS_DIR)
	@echo "Quarantine directory '$(MALICIOUS_DIR)' is ready."

# Run the antivirus daemon: <source_directory> <quarantine_directory> <interval-seconds>
run: pre-build
	bash ./antivirusd.sh $(ORIGINAL_DIR) $(MALICIOUS_DIR) $(INTERVAL)

# Run the restore tool: <original_dir> <malicious_dir>
restore: pre-build
	bash ./restore.sh $(ORIGINAL_DIR) $(MALICIOUS_DIR)