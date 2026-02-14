local M = {}

M.fold = function()
  local lnum = vim.v.lnum
  local foldlevel = vim.fn.foldlevel(lnum)
  if foldlevel == 0 then return " " end

  local foldclosed = vim.fn.foldclosed(lnum)
  local foldlevel_before = vim.fn.foldlevel(lnum - 1)
  local foldlevel_after = vim.fn.foldlevel(lnum + 1)

  -- case 1: 折疊為關閉狀態，且是開始行
  if foldclosed ~= -1 and foldclosed == lnum then
    if foldlevel == 1 then return "▶"
    elseif foldlevel == 2 then return "●"
    -- elseif foldlevel == 3 then return "◆"
    -- else return "■" 
    end
  end

  -- case 2: 開啟的 fold 起點
  if foldlevel > foldlevel_before and foldlevel <= foldlevel_after then
    if foldlevel == 1 then return "▽"
    elseif foldlevel == 2 then return "╰○"
    -- elseif foldlevel == 3 then return "◇"
    -- else return "□" 
    end
  end

  -- case 3: fold 結尾
  if foldlevel > foldlevel_after and foldlevel <= foldlevel_before then
    if foldlevel == 1 then return "╰"
    elseif foldlevel == 2 then return "╭○"
    end
  end
  if foldlevel > foldlevel_after and foldlevel <= foldlevel_before then
    return "╰"
  end

  -- case 4: fold 中間（表示還在區塊中）
  if foldlevel == 1 then return "│"
  elseif foldlevel == 2 then return " ⦙"
  -- elseif foldlevel == 3 then
  --   return "⦙"
  -- else
  --   return "|"
  end
end


-- 顯示行號（右邊對齊，支援相對號/實際號）
M.number = function()
  if vim.o.relativenumber and vim.v.relnum ~= 0 then
    return string.format("%9d", vim.v.relnum)
  else
    return string.format("%4d", vim.v.lnum)
  end
end

-- 結合成一行
M.statuscolumn = function()
  -- return table.concat({ M.number()," ", M.fold()})
  return table.concat({ M.number()})
end

return M
