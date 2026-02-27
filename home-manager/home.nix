{ pkgs, ... }: {

  home.username = "lychang";
  home.homeDirectory = "/Users/lychang";
  home.stateVersion = "23.11";

  # 軟體清單
  home.packages = with pkgs; [
    htop
    git
    curl
    # 之後想加什麼，就直接補在這裡
  ];

  programs.home-manager.enable = true;

}
