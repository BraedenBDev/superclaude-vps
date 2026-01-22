#!/bin/bash

# GitHub repository creation and push script
# Using GitHub CLI for easy setup

echo "========================================="
echo "SuperClaude VPS - GitHub Setup"
echo "========================================="

# Check if gh is authenticated
if ! gh auth status &>/dev/null; then
    echo "GitHub CLI not authenticated. Running login..."
    gh auth login
fi

# Get GitHub username
GITHUB_USER=$(gh api user --jq .login)
echo "GitHub user: $GITHUB_USER"

# Repository name
REPO_NAME="superclaude-vps"

# Check if repo already exists
if gh repo view "$GITHUB_USER/$REPO_NAME" &>/dev/null; then
    echo "Repository $REPO_NAME already exists"
    echo "Do you want to use the existing repository? (y/n)"
    read -r use_existing
    if [[ $use_existing != "y" && $use_existing != "Y" ]]; then
        echo "Please delete the existing repository or choose a different name"
        exit 1
    fi
else
    # Create new repository
    echo "Creating new repository: $REPO_NAME"
    gh repo create "$REPO_NAME" \
        --public \
        --description "Self-hosted Claude Code with Telegram control and faster-whisper transcription" \
        --clone=false
fi

# Add remote if not exists
if ! git remote | grep -q origin; then
    git remote add origin "https://github.com/$GITHUB_USER/$REPO_NAME.git"
else
    echo "Remote 'origin' already exists"
fi

# Commit latest changes
git add -A
git commit -m "Remove empty core directory, add GitHub push script" || echo "No changes to commit"

# Push to GitHub
echo "Pushing to GitHub..."
git branch -M main
git push -u origin main

echo "========================================="
echo "✅ Successfully pushed to GitHub!"
echo "========================================="
echo ""
echo "Repository URL: https://github.com/$GITHUB_USER/$REPO_NAME"
echo ""
echo "To clone on your VPS:"
echo "  git clone https://github.com/$GITHUB_USER/$REPO_NAME.git"
echo "  cd $REPO_NAME"
echo "  ./setup.sh"
echo ""