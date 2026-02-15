{ pkgs, ... }: {

  home.username = "lychang"; # 記得改這裡

  home.homeDirectory = "/home/lychang"; # Mac 則是 /Users/名稱

  home.stateVersion = "23.11"; 



  # --- 你的軟體清單就在這裡 ---

  home.packages = with pkgs; [

    htop

    git

    curl

    # 之後想加什麼，就直接補在這裡

  ];



  # 讓 Home Manager 自動管理自己

  programs.home-manager.enable = true;

}
