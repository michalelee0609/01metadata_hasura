#!/bin/bash
set -e
set -o pipefail

# =============================================================================
# Enhanced Metadata Management Engine v3.5
# =============================================================================

# =============================================================================
# Configuration Center
# =============================================================================
DEBUG=${DEBUG:-false}  # Debug mode: DEBUG=true for detailed diagnostics
LOG_FILE="/hasura-project/05-logs/hasura/metadata-manager-$(date +%Y%m%d).log"
OPERATION_ID=$(date +%s)-$RANDOM  # Unique operation ID

# Logging system initialization
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "[META][$OPERATION_ID][START] Process started at $(date +'%Y-%m-%d %T.%3N')"

# =============================================================================
# Directory Architecture (Finalized)
# =============================================================================
SOURCE_DIR="/hasura-project/06-data/hasura/metadata"   # User data area (persistent)
USER_META="/hasura-project/user_metadata"              # Processing area (temporary)
ACTIVE_META="/hasura-project/metadata"                 # Runtime root directory
ACTIVE_META_DIR="$ACTIVE_META/metadata"                # CLI workspace (created by CLI)
TEMPLATE_DIR="/hasura-project/01-config/hasura/metadata" # Template area (read-only reference)

# =============================================================================
# Engineering Core Modules
# =============================================================================

# Directory Management Engine (with resource auditing)
prepare_directory() {
    local dir=$1
    local context=$2
    
    # Debug
    if [ "$DEBUG" = "true" ]; then
        echo "[DEBUG][PRE] Directory state: $dir"
        [ -d "$dir" ] && ls -ld "$dir" || echo "Directory not exists"
    fi
    
    echo "[DIR][$context] Preparing: $dir"
    
    # Mountpoint check
    if mountpoint -q "$dir"; then
        echo "[MOUNT] Directory is a mount point - using safe cleanup"
        # Mountpoint Mgmt. rule setting
        if [ -d "$dir" ]; then
            echo "[CLEAN] Safely purging mount point content"
            find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} + || {
                echo "[ERROR][SYS002A][DIR] Failed to purge mount point" >&2
                return 104
            }
        else
            mkdir -p "$dir" || {
                echo "[ERROR][SYS003][DIR] Critical: Failed to create $dir" >&2
                return 102
            }
        fi
    else
        # Other Dir mgmt. rule setting
        if [ -d "$dir" ]; then
            echo "[CLEAN] Removing existing directory"
            rm -rf "$dir" || { 
                echo "[ERROR][SYS002][DIR] Critical: Failed to remove $dir" >&2
                return 101
            }
        fi
        
        mkdir -p "$dir" || {
            echo "[ERROR][SYS003][DIR] Critical: Failed to create $dir" >&2
            return 102
        }
    fi
    
    # DIR Creation
    [ -d "$dir" ] || {
        echo "[ERROR][SYS004][DIR] Critical: Creation validation failed" >&2
        return 103
    }
    
    echo "[STATUS][DIR] OK: Prepared for $context"
    
    # DIR Recheck 
    if [ "$DEBUG" = "true" ]; then
        echo "[DEBUG][POST] Directory state: $dir"
        ls -ld "$dir"
        [ -d "$dir" ] && find "$dir" -maxdepth 2
    fi
}

# Dependency Assurance System
ensure_dependencies() {
    echo "[DEPS] Verifying runtime dependencies..."
    
    # YQ runtime assurance
    if ! command -v yq &> /dev/null; then
        echo "[ACTION] Installing yq..."
        apt-get update -qq && apt-get install -y yq > /dev/null || {
            echo "[ERROR][SYS011][DEPS] Failed: yq installation" >&2
            return 201
        }
        echo "[STATUS][DEPS] OK: yq installed"
    else
        echo "[CHECK] yq $(yq --version | awk 'NR==1{print $3}') already installed"
    fi
    
    # Yamllint runtime assurance
    if ! command -v yamllint &> /dev/null; then
        echo "[ACTION] Installing yamllint..."
        apt-get update -qq && apt-get install -y yamllint > /dev/null || {
            echo "[ERROR][SYS012][DEPS] Failed: yamllint installation" >&2
            return 202
        }
        echo "[STATUS][DEPS] OK: yamllint installed"
    else
        echo "[CHECK] yamllint $(yamllint --version | head -1) already installed"
    fi
    
    # Hasura CLI health check
    if ! command -v hasura &> /dev/null; then
        echo "[ERROR][SYS013][DEPS] Critical: hasura CLI not found" >&2
        return 203
    else
        echo "[CHECK] hasura $(hasura version | awk '/CLI/{print $NF}') verified"
    fi
    
    echo "[STATUS][DEPS] OK: All dependencies operational"
}

# Template Initialization System (Secure Isolation)
initialize_template() {
    echo "[SCENARIO] Initializing new metadata template..."
    
    # Secure zone preparation - ensure directory doesn't exist
    echo "[DIR][INIT] Preparing active metadata area: $ACTIVE_META"
    if [ -d "$ACTIVE_META" ]; then
        echo "[CLEAN] Removing existing active metadata"
        rm -rf "$ACTIVE_META" || {
            echo "[ERROR][SYS002][DIR] Failed to remove $ACTIVE_META" >&2
            return 301
        }
    fi

    # Template generation process
    hasura init "$ACTIVE_META" --version 3 --skip-update-check || {
        echo "[ERROR][OPR001][INIT] Failed: hasura init" >&2
        return 302
    }
    
    # Template integrity verification
    [ -f "$ACTIVE_META_DIR/version.yaml" ] || {
        echo "[ERROR][SYS021][INIT] Critical: Template incomplete" >&2
        return 303
    }
    
    echo "[STATUS][INIT] OK: Template generated: v$(yq e '.version' "$ACTIVE_META_DIR/version.yaml")"
    
    # Template archiving (read-only storage)
    prepare_directory "$TEMPLATE_DIR" "template_repository" || return 304
    
    # Copy actual metadata content
    cp -r "$ACTIVE_META_DIR"/* "$TEMPLATE_DIR/" || {
        echo "[ERROR][OPR002][INIT] Failed: Template archiving" >&2
        return 305
    }
    
    # Archive validation
    [ -f "$TEMPLATE_DIR/version.yaml" ] || {
        echo "[ERROR][SYS022][INIT] Critical: Archive validation failed" >&2
        return 306
    }
    
    echo "[STATUS][ARCHIVE] OK: Template archived to reference repository"
    
    # User guidance system
    cat <<EOF
[USER-GUIDANCE]
=================================================================
OK: Initialization Complete! Next steps:
1. Access template at: $TEMPLATE_DIR
2. Prepare YOUR metadata in: $SOURCE_DIR
3. Restart container to apply your configuration
=================================================================
EOF
    
    echo "[HEALTH][SCENARIO] Initialization workflow completed"
}

# Metadata Validation Engine (Multi-stage Verification)
validate_metadata() {
    local meta_dir=$1
    
    # Ensure metadata directory exists
    [ -d "$meta_dir" ] || {
        echo "[ERROR][VAL001] Metadata directory not found: $meta_dir" >&2
        return 400
    }
    
    echo "[VALIDATION] Starting multi-stage verification..."
    
    # ==================== Core Validation ====================
    
    # Stage 1: Version Protocol Validation
    local version_file="$meta_dir/version.yaml"
    if [ ! -f "$version_file" ]; then
        echo "[ERROR][VAL101][VERSION] Missing version.yaml" >&2
        return 401
    fi
    
    local version=$(yq e '.version' "$version_file")
    if [ "$version" != "3" ]; then
        echo "[ERROR][VAL102][VERSION] Invalid version: $version (required: v3)" >&2
        return 402
    fi
    echo "[STAGE-PASS] OK: Version: v$version"
    
    # Stage 2: YAML Syntax Validation
    echo "[VALIDATION] Scanning YAML syntax..."
    local yaml_errors=0
    local temp_errors_file=$(mktemp /tmp/yamllint_errors_XXXXXX)
    
    find "$meta_dir" -name "*.yaml" -print0 | while IFS= read -r -d '' file; do
        echo "[PROCESSING] Validating: ${file##*/}"
        if ! yamllint -c /etc/yamllint/config.yaml "$file"; then
            echo "[ERROR][VAL201][YAML] Syntax error detected in: ${file##*/}" >&2
            echo "1" >> "$temp_errors_file"
        fi
    done
    
    yaml_errors=$(wc -l < "$temp_errors_file" 2>/dev/null || echo 0)
    rm -f "$temp_errors_file"

    if [ $yaml_errors -ne 0 ]; then
        echo "[ERROR][VAL202][YAML] Total YAML syntax errors found: $yaml_errors" >&2
        return 410
    fi
    echo "[STAGE-PASS] OK: YAML syntax"
    
    # Stage 3: Metadata Structure Check
    if ! hasura metadata lint --metadata-dir "$meta_dir"; then
        echo "[ERROR][VAL301][STRUCTURE] Invalid metadata relationships or structure detected." >&2
        return 420
    fi
    echo "[STAGE-PASS] OK: Structure integrity"
    
    # Stage 4: Change Detection
    local diff_output=$(hasura metadata diff --metadata-dir "$meta_dir" 2>&1)
    if echo "$diff_output" | grep -q "No changes found"; then
        echo "[CHANGE-DETECTION] OK: No changes detected."
        return 2
    else
        echo "[CHANGE-DETECTION] WARNING: Changes identified."
        if [ "$DEBUG" = "true" ]; then
            echo "[DIFF-ANALYSIS] Change details:"
            echo "$diff_output"
        fi
        return 0
    fi
    
    # Stage 5: Consistency Verification
    local consistency=$(hasura metadata inconsistency status --metadata-dir "$meta_dir" --output json)
    if [ "$(echo "$consistency" | jq -r '.is_consistent')" != "true" ]; then
        echo "[ERROR][VAL401][CONSISTENCY] Inconsistency detected:" >&2
        echo "$consistency" | jq . >&2
        return 430
    fi
    echo "[STAGE-PASS] OK: Database consistency"
    
    echo "[HEALTH][VALIDATION] OK: All validation stages passed."
    return 0
}

# Metadata Deployment System (Atomic Operations)
apply_metadata() {
    local source_dir=$1
    local deploy_id="deploy-$(date +%Y%m%d%H%M%S)"
    
    echo "[DEPLOY] Starting atomic deployment..."
    
    # Ensure runtime root exists
    mkdir -p "$ACTIVE_META" || {
        echo "[ERROR][SYS005][DIR] Failed to create $ACTIVE_META" >&2
        return 501
    }
    
    # CLI workspace detection with timeout
    echo "[CLI-WORKSPACE] Verifying CLI workspace: $ACTIVE_META_DIR"
    local wait_count=0
    while [ ! -d "$ACTIVE_META_DIR" ] && [ $wait_count -lt 3 ]; do
        echo "[WAIT] CLI workspace not ready, waiting 1s..."
        sleep 1
        ((wait_count++))
    done
    
    # Create if still missing (first deployment scenario)
    if [ ! -d "$ACTIVE_META_DIR" ]; then
        echo "[ACTION] Creating CLI workspace: $ACTIVE_META_DIR"
        mkdir -p "$ACTIVE_META_DIR" || {
            echo "[ERROR][SYS006][DIR] Failed to create CLI workspace" >&2
            return 502
        }
    fi
    
    # Purge existing metadata (preserve directory structure)
    echo "[CLEAN] Purging existing metadata in $ACTIVE_META_DIR"
    find "$ACTIVE_META_DIR" -mindepth 1 -delete || {
        echo "[ERROR][SYS007][DIR] Failed to clean workspace" >&2
        return 503
    }
    
    # Metadata synchronization
    echo "[ACTION] Synchronizing metadata: $source_dir -> $ACTIVE_META_DIR"
    cp -r "$source_dir"/* "$ACTIVE_META_DIR/" || {
        echo "[ERROR][OPR301][DEPLOY] Copy failed" >&2
        return 504
    }
    
    # Deployment execution
    echo "[ACTION] Applying metadata with Hasura CLI..."
    hasura metadata apply --project "$ACTIVE_META" || {
        echo "[ERROR][OPR302][DEPLOY] Hasura metadata apply failed." >&2
        return 505
    }
    echo "[STATUS][DEPLOY] OK: Metadata applied successfully."
    
    # Persistent storage (with version snapshot)
    echo "[ARCHIVE] Creating persistent storage snapshot in $SOURCE_DIR."
    prepare_directory "$SOURCE_DIR" "persistent_storage" || return 506
    
    # Create deployment marker
    mkdir -p "$SOURCE_DIR/.revisions"
    echo "$deploy_id" > "$SOURCE_DIR/.revisions/$deploy_id.log"
    
    cp -r "$source_dir"/* "$SOURCE_DIR/" || {
        echo "[ERROR][OPR303][ARCHIVE] Snapshot failed" >&2
        return 507
    }
    
    # Post-deployment validation
    [ -f "$SOURCE_DIR/version.yaml" ] || {
        echo "[ERROR][SYS031][ARCHIVE] Persistent snapshot validation failed" >&2
        return 508
    }
    
    echo "[REVISION] Deployment ID: $deploy_id"
    echo "[STATUS][ARCHIVE] OK: Persistent snapshot created."
    
    return 0
}

# =============================================================================
# Master Control
# =============================================================================

echo "[META][MAIN] Initiating metadata management workflow."

# Scenario Routing: Empty Directory Initialization
if [ -z "$(ls -A "$SOURCE_DIR" 2>/dev/null)" ]; then
    echo "[SCENARIO][ROUTE] 01 - Empty metadata directory detected. Proceeding with template initialization."
    
    # Ensure dependencies
    ensure_dependencies || { 
        echo "[ERROR][MAIN] Dependency check failed for scenario 01." >&2
        exit 1
    }
    
    # Initialize template
    initialize_template || { 
        echo "[ERROR][MAIN] Template initialization failed for scenario 01." >&2
        exit 2
    }
    
    echo "[HEALTH][SYSTEM] Scenario 01 (initialization) completed successfully."
    exit 0
fi

# Scenario Routing: Existing Metadata Processing
echo "[SCENARIO][ROUTE] 02 - Existing metadata detected. Proceeding with validation and application."

# Ensure dependencies
ensure_dependencies || { 
    echo "[ERROR][MAIN] Dependency check failed for scenario 02." >&2
    exit 3
}

# Prepare temporary workspace
prepare_directory "$USER_META" "staging_area" || { 
    echo "[ERROR][MAIN] Staging area preparation failed." >&2
    exit 4
}

echo "[ACTION] Transferring metadata to staging area: $SOURCE_DIR -> $USER_META"
cp -r "$SOURCE_DIR"/* "$USER_META/" || {
    echo "[ERROR][OPR401][COPY] Transfer failed." >&2
    exit 5
}

# Validation workflow
echo "[ACTION] Validating metadata in staging area: $USER_META"
validate_metadata "$USER_META"
validation_result=$?

# Sub-scenario routing
case $validation_result in
    0) # Validation passed with changes
        echo "[SCENARIO][ROUTE] 02.1 - Valid changes detected. Applying changes."
        apply_metadata "$USER_META" || { 
            echo "[ERROR][MAIN] Metadata application failed." >&2
            exit 6
        }
        ;;
    2) # Validation passed without changes
        echo "[SCENARIO][ROUTE] 02.2 - No changes required. Skipping application."
        echo "[HEALTH][SYSTEM] System state optimal."
        exit 0
        ;;
    *) # Validation failed
        echo "[ERROR][SCENARIO][ROUTE] 02.3 - Metadata validation failed (Code: $validation_result)." >&2
        exit 7
        ;;
esac

echo "[HEALTH][SYSTEM] All metadata management workflows completed successfully."
exit 0