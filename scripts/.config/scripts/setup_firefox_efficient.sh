#!/usr/bin/env bash
set -euo pipefail

echo "[1/7] Installing packages (needs sudo)…"
sudo pacman -S --needed --noconfirm \
  firefox libva libva-utils intel-media-driver ffmpeg \
  libvpl vpl-gpu-rt intel-gpu-tools

echo "[2/7] Verifying VA-API driver…"
if LIBVA_DRIVER_NAME=iHD vainfo >/dev/null 2>&1; then
  echo "VA-API iHD driver detected."
else
  echo "Warning: 'vainfo' failed or iHD not detected. Continue, then check with: LIBVA_DRIVER_NAME=iHD vainfo"
fi

echo "[3/7] Forcing Wayland for Firefox (user scope)…"
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/moz-wayland.conf << 'EOF'
MOZ_ENABLE_WAYLAND=1
EOF
systemctl --user daemon-reload || true
echo "Wayland env written to ~/.config/environment.d/moz-wayland.conf"

echo "[4/7] Locating default Firefox profile…"
INI="$HOME/.mozilla/firefox/profiles.ini"
if [[ ! -f "$INI" ]]; then
  echo "Launching Firefox once to create a profile…"
  MOZ_ENABLE_WAYLAND=1 firefox --headless --createprofile default || true
fi

# Re-evaluate after profile creation
INI="$HOME/.mozilla/firefox/profiles.ini"
if [[ ! -f "$INI" ]]; then
  echo "Error: profiles.ini not found. Start Firefox once, then re-run this script."
  exit 1
fi

profile_path=""
while IFS= read -r line; do
  case "$line" in
    Path=*.default-release)
      profile_path="${line#Path=}"
      ;;
  esac
done < <(grep -E '^\[Profile[0-9]+\]|^Path=|^Default=' -n "$INI" | sed 's/^[0-9]*://')

if [[ -z "$profile_path" ]]; then
  # Fallback: first Default=1 profile or first profile path
  profile_path="$(awk -F= '/^\[Profile/{p=0} /^Default=1/{p=1} p && /^Path=/{print $2; exit} /^Path=/{print $2; exit}' "$INI")"
fi

ff_profile="$HOME/.mozilla/firefox/$profile_path"
if [[ ! -d "$ff_profile" ]]; then
  echo "Error: profile dir not found: $ff_profile"
  exit 1
fi
echo "Profile: $ff_profile"

echo "[5/7] Writing optimized user.js (backup any existing)…"
if [[ -f "$ff_profile/user.js" ]]; then
  cp -f "$ff_profile/user.js" "$ff_profile/user.js.bak.$(date +%s)"
fi

cat > "$ff_profile/user.js" << 'EOF'
// --- Hardware accel + compositor ---
user_pref("media.hardware-video-decoding.enabled", true);
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("gfx.webrender.all", true);

// --- Cut background CPU wakeups ---
user_pref("browser.sessionstore.interval", 60000);        // default ~15s -> 60s
user_pref("dom.ipc.processCount", 4);                     // fewer content procs on 155H
user_pref("browser.tabs.animate", false);
user_pref("toolkit.cosmeticAnimations.enabled", false);

// --- Kill sponsored content / Pocket / telemetry ---
user_pref("toolkit.telemetry.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);

// --- Fewer speculative connections ---
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.http.speculative-parallel-limit", 0);

// --- Optional privacy hardening ---
// user_pref("media.peerconnection.enabled", false);        // disable WebRTC (breaks video calls)
// user_pref("geo.enabled", false);                         // disable geolocation API
EOF

echo "[6/7] Optional system tools for measurement…"
read -rp "Install powertop and powerstat (y/N)? " ans
if [[ "${ans,,}" == "y" ]]; then
  sudo pacman -S --needed --noconfirm powertop powerstat || true
fi

echo "[7/7] Finish: helper notes"
cat << 'EONOTES'

Done.

Next steps:
1) Restart your session (to load ~/.config/environment.d) or run:
     systemctl --user import-environment MOZ_ENABLE_WAYLAND
2) Launch Firefox and verify:
   - about:support → Compositing: WebRender
   - about:support → Video Decoding: "Hardware accelerated"
3) Install extensions (minimal set):
   - uBlock Origin
   - ClearURLs (optional)
   In uBlock → Dashboard → Filter lists: enable Annoyances + Peter Lowe’s + AdGuard Annoyances.
4) Measure:
   - powertop while idling and playing a 1080p/4K YouTube video.
   - intel_gpu_top → “Video” engine should be active during playback.

Revert:
- Delete ~/.config/environment.d/moz-wayland.conf
- Remove ~/.mozilla/firefox/<yourprofile>/user.js or restore user.js.bak.<timestamp>

EONOTES
