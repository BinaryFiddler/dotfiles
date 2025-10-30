#!/usr/bin/env bash
set -euo pipefail

echo "→ Key repeat"
defaults write -g KeyRepeat -int 2
defaults write -g InitialKeyRepeat -int 15

echo "→ Finder"
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# echo "→ Dock"
# defaults write com.apple.dock autohide -bool true
# defaults write com.apple.dock autohide-time-modifier -float 0.2
# defaults write com.apple.dock autohide-delay -float 0

# echo "→ Trackpad"
# defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
# defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

echo "→ Screenshots"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture location -string "$HOME/Desktop"

killall Finder 2>/dev/null || true
killall Dock   2>/dev/null || true
echo "Done."
