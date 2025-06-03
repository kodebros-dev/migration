#!/bin/bash

# Script to update Git remote origins from GitLab to GitHub
# This script handles both main repositories and their submodules

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Repository mapping: GitLab URL -> GitHub URL
declare -A REPO_MAPPING=(
    ["https://gitlab.kodebros.com/promiseq/ai-ninjas/backend_core.git"]="https://github.com/kodebros-dev/backend_core.git"
    ["https://gitlab.kodebros.com/promiseq/ai-ninjas/cloud/cloud-backend-poc.git"]="https://github.com/kodebros-dev/cloud-backend.git"
    ["https://gitlab.kodebros.com/promiseq/ai-ninjas/qube-core/qube-fastapi-poc.git"]="https://github.com/kodebros-dev/qube-backend.git"
    ["https://gitlab.kodebros.com/promiseq/ai-ninjas/cloud/stream-listener.git"]="https://github.com/kodebros-dev/cloud-stream-manager.git"
    ["https://gitlab.kodebros.com/promiseq/ai-ninjas/frontend_core.git"]="https://github.com/kodebros-dev/frontend_core.git"
    ["https://gitlab.kodebros.com/promiseq/ai-ninjas/qube-core/qube-ui.git"]="https://github.com/kodebros-dev/qube-ui.git"
    ["https://gitlab.kodebros.com/promiseq/ai-ninjas/cloud/cloud-ui-poc.git"]="https://github.com/kodebros-dev/cloud-ui.git"
    ["https://gitlab.kodebros.com/promiseq/ai-ninjas/qube-core/qube-healthcheck.git"]="https://github.com/kodebros-dev/qube-healthcheck.git"
    ["https://gitlab.kodebros.com/promiseq/ai-ninjas/qube-core/qube-scripts.git"]="https://github.com/kodebros-dev/qube-scripts.git"
    ["https://gitlab.kodebros.com/promiseq/ai-ninjas/qube-core/qube-deployments.git"]="https://github.com/kodebros-dev/qube-deployments.git"
    ["https://gitlab.kodebros.com/promiseq/ai-ninjas/qube-core/camera-manager.git"]="https://github.com/kodebros-dev/qube-camera-manager.git"
)

# Function to update remote origin for a repository
update_remote_origin() {
    local repo_path="$1"
    local current_dir=$(pwd)
    
    if [[ ! -d "$repo_path" ]]; then
        print_warning "Directory $repo_path does not exist, skipping..."
        return
    fi
    
    cd "$repo_path"
    
    if [[ ! -d ".git" ]]; then
        print_warning "Not a git repository: $repo_path, skipping..."
        cd "$current_dir"
        return
    fi
    
    print_status "Processing repository: $repo_path"
    
    # Get current origin URL
    local current_origin=""
    if git remote get-url origin >/dev/null 2>&1; then
        current_origin=$(git remote get-url origin)
        print_status "Current origin: $current_origin"
    else
        print_warning "No origin remote found in $repo_path"
        cd "$current_dir"
        return
    fi
    
    # Find matching GitHub URL
    local new_origin=""
    for gitlab_url in "${!REPO_MAPPING[@]}"; do
        if [[ "$current_origin" == "$gitlab_url" ]]; then
            new_origin="${REPO_MAPPING[$gitlab_url]}"
            break
        fi
    done
    
    if [[ -z "$new_origin" ]]; then
        print_warning "No mapping found for origin: $current_origin"
        cd "$current_dir"
        return
    fi
    
    # Remove old origin and add new one
    print_status "Removing old origin..."
    git remote remove origin
    
    print_status "Adding new origin: $new_origin"
    git remote add origin "$new_origin"
    
    # Verify the change
    local updated_origin=$(git remote get-url origin)
    if [[ "$updated_origin" == "$new_origin" ]]; then
        print_success "Successfully updated origin to: $updated_origin"
    else
        print_error "Failed to update origin for $repo_path"
    fi
    
    # Handle submodules
    if [[ -f ".gitmodules" ]]; then
        print_status "Found submodules, updating..."
        update_submodules
    fi
    
    cd "$current_dir"
}

# Function to update submodules
update_submodules() {
    if [[ ! -f ".gitmodules" ]]; then
        return
    fi
    
    print_status "Updating submodules..."
    
    # Initialize and update submodules
    git submodule update --init --recursive
    
    # Get list of submodules
    local submodules=$(git submodule status | awk '{print $2}')
    
    for submodule in $submodules; do
        if [[ -d "$submodule" ]]; then
            print_status "Processing submodule: $submodule"
            
            # Enter submodule directory
            cd "$submodule"
            
            # Get current origin URL
            local current_origin=""
            if git remote get-url origin >/dev/null 2>&1; then
                current_origin=$(git remote get-url origin)
                print_status "Submodule current origin: $current_origin"
                
                # Find matching GitHub URL
                local new_origin=""
                for gitlab_url in "${!REPO_MAPPING[@]}"; do
                    if [[ "$current_origin" == "$gitlab_url" ]]; then
                        new_origin="${REPO_MAPPING[$gitlab_url]}"
                        break
                    fi
                done
                
                if [[ -n "$new_origin" ]]; then
                    print_status "Updating submodule origin to: $new_origin"
                    git remote remove origin
                    git remote add origin "$new_origin"
                    print_success "Submodule origin updated successfully"
                else
                    print_warning "No mapping found for submodule origin: $current_origin"
                fi
            else
                print_warning "No origin remote found in submodule: $submodule"
            fi
            
            # Go back to parent directory
            cd ..
        fi
    done
    
    # Update .gitmodules file if needed
    print_status "Checking .gitmodules file..."
    for gitlab_url in "${!REPO_MAPPING[@]}"; do
        local github_url="${REPO_MAPPING[$gitlab_url]}"
        if grep -q "$gitlab_url" .gitmodules 2>/dev/null; then
            print_status "Updating .gitmodules file..."
            sed -i.bak "s|$gitlab_url|$github_url|g" .gitmodules
            rm -f .gitmodules.bak
            print_success "Updated .gitmodules file"
        fi
    done
}

# Main function
main() {
    print_status "Starting Git origin update process..."
    
    # Get list of directories to process
    local directories=()
    
    # If no arguments provided, process current directory
    if [[ $# -eq 0 ]]; then
        directories=(.)
    else
        directories=("$@")
    fi
    
    # Process each directory
    for dir in "${directories[@]}"; do
        update_remote_origin "$dir"
    done
    
    print_success "Git origin update process completed!"
    print_status "Remember to verify your changes and test connectivity to the new remotes."
    print_status "You may want to run 'git fetch origin' in each repository to verify connectivity."
}

# Help function
show_help() {
    cat << EOF
Usage: $0 [directory1] [directory2] ...

This script updates Git remote origins from GitLab to GitHub for the specified repositories.
If no directories are specified, it processes the current directory.

The script will:
1. Update the remote origin URL
2. Process any submodules found
3. Update .gitmodules file if necessary

EOF
}

# Check for help flag
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Run main function
main "$@"
