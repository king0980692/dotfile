{ pkgs, ... }: {

  # 安裝的 packages（CLI 工具放這）
  environment.systemPackages = with pkgs; [
    bash
    git
    wget
    htop
    stats  # macOS menu bar system monitor
    timg   # terminal image viewer
    skhd   # hotkey daemon
  ];

  # macOS 系統設定
  system.defaults = {
    dock = {
      autohide = true;
      show-recents = false;
    };
    finder = {
      AppleShowAllExtensions = true;
      ShowPathbar = true;
    };
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
    };
  };

  # 指定主要使用者（新版 nix-darwin 必填）
  system.primaryUser = "lychang";

  # 確保 ~/.local/bin 在 PATH 裡（claude code 等 user-installed tools）
  environment.systemPath = [ "$HOME/.local/bin" ];

  # 建立 skhd.app wrapper，讓 macOS Input Monitoring 可以識別
  # darwin-rebuild 時自動同步 binary
  system.activationScripts.skhdApp.text = ''
    SKHD_BIN="${pkgs.skhd}/bin/skhd"
    APP_DIR="/Applications/skhd.app/Contents"
    mkdir -p "$APP_DIR/MacOS"
    cp -f "$SKHD_BIN" "$APP_DIR/MacOS/skhd"
    chmod +x "$APP_DIR/MacOS/skhd"
    cat > "$APP_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>skhd</string>
  <key>CFBundleIdentifier</key><string>com.lychang.skhd</string>
  <key>CFBundleName</key><string>skhd</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>LSUIElement</key><true/>
  <key>LSBackgroundOnly</key><true/>
</dict>
</plist>
PLIST
  '';

  # skhd LaunchAgent，執行 .app 裡的 binary，加 sleep 5 等 Accessibility 就緒
  launchd.user.agents.skhd = {
    serviceConfig = {
      ProgramArguments = [ "/bin/sh" "-c" "sleep 5 && exec /Applications/skhd.app/Contents/MacOS/skhd" ];
      KeepAlive = true;
      RunAtLoad = true;
      ProcessType = "Interactive";
    };
  };

  # Determinate Nix 自己管理 daemon，不讓 nix-darwin 接管
  nix.enable = false;

  system.stateVersion = 6;
}
