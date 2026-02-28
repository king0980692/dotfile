{ pkgs, ... }: {

  # 安裝的 packages（CLI 工具放這）
  environment.systemPackages = with pkgs; [
    bash
    git
    wget
    htop
    stats  # macOS menu bar system monitor
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

  # 啟用 skhd（hotkey daemon），設定檔在 ~/.config/skhd/skhdrc
  services.skhd.enable = true;

  # Determinate Nix 自己管理 daemon，不讓 nix-darwin 接管
  nix.enable = false;

  system.stateVersion = 6;
}
