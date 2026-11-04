-- full-border：完整圓角邊框，還原 kanagawa 預覽圖外觀
-- require("full-border"):setup {
-- 	type = ui.Border.PLAIN,
-- }

-- zoxide：yazi 內每次切換目錄（Enter/h/l/cd/跳轉）都 zoxide add，讓 shell 的 z 也能跳到
require("zoxide"):setup { update_db = true }

require("no-status"):setup()
